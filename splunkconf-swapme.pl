#!/usr/bin/perl -w

# splunkconf-swapme.pl
# Matthieu Araman, Splunk
# This script will try to increase swap to 
# - allow the os to move unused thing to swap
# - give flexibility to the os memory management to avoid killing processes too early , especially when there are temporary burs
# System should not be swapping permanently of course, use Splunk monitoring Console or OS tools to monitor usaget 
# This should be part of global strategy on ressource management that is multiple things working together  :
# - correctly sized instance
# - WLM
# - user profiles
# - Splunk memory management 
# - Scheduling tuning
# - Search slots tuning

# 202010 initial version 
# 20201103 add total disk space percent limit  
# 20201116 add getlong options support, add help , when no arg, run in dry mode with / partition , add dry-mode, improve logging
# 20201117 improve logging


use strict;
use Getopt::Long;
use List::Util qw[min max];

my $VERSION;
$VERSION="20201116";

my $help;
my $dry_run="";

GetOptions (
     'help|h'=> \$help,
     'dry_run|dry-run' => \$dry_run,
  );


if ($help) {
  print "splunkconf-swapme.pl directoryforswapfile [--help|--dry-run] 
This script will try to create additional swap space on the partition it was given as argument
See https://serverfault.com/questions/25653/swap-partition-vs-file-for-performance
and https://itsfoss.com/create-swap-file-linux/

Algorithm for deciding whether to create or not a swap file and which size is :
- Total RAM available
- Total existing swap (swap partition(s) + swap file(s))
- Absolute swap size 
- Relative size of swap versus RAM
- Available space on partition

In case there is not enough space for ideal swap, size is automatically reduced 
If that is not enough, please add more disk 

To remove swapfile in use :
make sure you understand what you do and NEVER remove swapfile in use !
- use swapoff command (man swapoff) to remove the file from being used
- comment out or remove the entry in /etc/fstab (warning any mistake here could make the system unbootable)
- remove the file after checking swap space was reduced

Options are :

  --help : print this help
  --dry-run : Tell you what would be done but dont do it

";
  exit 0;
}


my $MEM=`free | grep ^Mem: | perl -pe 's/Mem:\\s*\\t*(\\d+).*\$/\$1/' `;
my $SWAP=`free | grep ^Swap: | perl -pe 's/Swap:\\s*\\t*(\\d+).*\$/\$1/'`;
my $TOTALMEM=`free -t | grep ^Total: | perl -pe 's/Total:\\s*\\t*(\\d+).*\$/\$1/'`;


my $PARTITIONFAST="/";

if (@ARGV>=1) {
  $PARTITIONFAST=$ARGV[0];
  print "using partition from arg partitionfast=$PARTITIONFAST \n";
  if ( -e $PARTITIONFAST ) {
    print "partitioncheck ok \n";
  } else {
    print "Exiting ! wrong partition name !!!!\n";
    exit 1;
  }
} else {
  print "no arg, defaulting partition to / and forcing ---dry-run , please specify partition if you really want to do it, run with --help for full help\n";
  $dry_run=1;
}

if ($dry_run) {
  print "*** running in dry run mode, will not change anything \n";
}

my $TAILLE=`df -k ${PARTITIONFAST}| tail -1| perl -pe 's/^[^\\s]+\\s+(\\d+).*\$/\$1/'`;
my $AVAIL=`df -k ${PARTITIONFAST}| tail -1| perl -pe 's/^[^\\s]+\\s+(\\d+)\\s+(\\d+)\\s+(\\d+).*\$/\$3/'`;

chomp($MEM);
chomp($SWAP);
chomp($TOTALMEM);
chomp($TAILLE);
chomp($AVAIL);

my $WANTED=100000000-$SWAP;
my $WANTED2=4*$MEM-$SWAP;
my $MINFREE=10000000;
my $AVAIL2=$AVAIL-$MINFREE;
# percentage max of disk space to allocate
my $TAILLEPERC=int(0.4*$TAILLE);
my $WANTED3=min($WANTED,$WANTED2);
my $WANTED4=min($WANTED3,$AVAIL2);
my $WANTED14=min($WANTED4,$TAILLEPERC);
print("MEM=$MEM, SWAP=$SWAP, TOTAL=$TOTALMEM, SIZE(k)=$TAILLE, maximum size that we want to use versus whole size SIZEPERC=$TAILLEPERC, AVAIL(k)=$AVAIL, MINFREE=$MINFREE, remaining available after minfree AVAIL2(k)=$AVAIL2 , absolute ideal swap space needed WANTED=$WANTED, swap space wanted versus the current real mem  WANTED2=$WANTED2,which result (min wanted , wanted2) in WANTED3=$WANTED3, corrected wanted3 after taking into account AVAIL2 WANTED4=$WANTED4, corrected value to not be over SIZEPERC  WANTED14=$WANTED14\n");
# logic is to be able to burst with a reduced oom risk 
# max size for prod env
if ($WANTED<=0){
   print ("swap space looks fine (check on size)! all good (WANTED=$WANTED)\n");
   exit 0;
}
# max size relative to allocated mem (will de facto reduce for test env or management component while still having enough size
if ($WANTED2<=0){
   print ("swap space looks fine (check on relative mem size)! all good (WANTED2=$WANTED2)\n");
   exit 0;
}
if ($WANTED4<=10000) {
  print (" about enough swap space, doing nothing (WANTED4=$WANTED4 <=10000)\n");
  exit 0;
}
# try not to fill disk , inform admin that we are blocked
if ($AVAIL2<=0) {
  print (" not enough free space to add swap (AVAIL2=$AVAIL2), please consider adding more disk space to reduce oom risk \n");
  exit 1;
}

print "trying to create a swapfile at $PARTITIONFAST/swapfile with size $WANTED14\n";
if (-e "$PARTITIONFAST/swapfile") {
  print "swapfile $PARTITIONFAST/swapfile already exist , doing nothing\n";
} else {
  my $WANTED5=1024*$WANTED14;
  print "Going to create swapfile at $PARTITIONFAST/swapfile with size $WANTED5, adding \"$PARTITIONFAST/swapfile none swap sw 0 0\" to /etc/fstab and activating with swapon -a";
  if ($dry_run) {
    print "dry run, not really doing it\n";
  } else {
    `fallocate -l $WANTED5 $PARTITIONFAST/swapfile`;
    `chmod 600 $PARTITIONFAST/swapfile`;
    `mkswap $PARTITIONFAST/swapfile`;
    my $RES=`grep $PARTITIONFAST/swapfile /etc/fstab `;
    if ($RES) {
      print "swapfile already present in /etc/fstab, doing nothing\n";
    } elsif (-e "$PARTITIONFAST/swapfile") {
      print "swapfile exist but not present in /etc/fstab, adding the line \"$PARTITIONFAST/swapfile none swap sw 0 0\"\n";
      `echo "$PARTITIONFAST/swapfile none swap sw 0 0">>/etc/fstab `;
    } else {
      print "swapfile not present and not existing in /etc/fstab, that is unexpected, doing nothing !\n";
    }
    #i dont do that, better use the fstab entry `swapon $PARTITIONFAST/swapfile`;
    `swapon -a`;
    $SWAP=`free | grep ^Swap: | perl -pe 's/Swap:\\s*\\t*(\\d+).*\$/\$1/'`;
    $TOTALMEM=`free -t | grep ^Total: | perl -pe 's/Total:\\s*\\t*(\\d+).*\$/\$1/'`;
    print("after swapfile creation MEM=$MEM, SWAP=$SWAP, TOTAL=$TOTALMEM");
  }
}

