#!/usr/bin/perl -w

# Matthieu Araman
# Splunk


# why in perl ? 
# safer than shell (strict mode, avoid lots of typo, but also easy to call shell commands)
# because I like and knew it..
#
# why a (so long) script when I could type the commands in 2 lines ....
# because it makes automated install and testing easier (example : the script wait between commands to that Splunk can initialize correctly in all kind of setup (you dont want to kill splunk in the midlle of cluster initialization, dont you ?)
# it is also lots of checks to make sure we are handling erros conditions, know issues with permissions and order of command to type to not break Splunk
#
# why not move this to ansible ?
# you can prepare all the files and call this script from ansible (already done it sucessfully) but I prefer to have the script not ansible dependent as it ease unit testing and works in more environments  
#
# run as root
# This script initialize Splunk 
# 20160909 1051 new version
# 20160920 make su path variable as different on different linux, add case for handling migration prompt, fix typos, add error check for chown to splunk , add splunk indexes creation 
# 20160922 add check for managedsecret
# 20161005 change the default SPLUNKPWD and check for password change
# 20161007 fix check for managedsecret and add more var for when user is not splunk
# 20161017 small typos and remerge
# 20161114 add comments
# 20171005 add comment to use user-seed.conf in order to remove password in script
# 20180413 correct path and uncomment .ui_login to avoid change password prompt
# 20181011 change for user-seed and custom init
# 20181030 add splunk_subsys var + correction path for copying init script and use this variable
# 20181120 add initial app deployment option (needed to splunkforwarder to push directly uf_base that disable the splunk management port)
# 20190205 formatting
# 20190303 add option for 7.2.2+ and init d script to avoid the splunk restart as splunk issue 
# 20190329 add fallback for pre 7.2 version for enable boot start, change subindex to be indexes not index
# 20190407 add arguments as inputs to ease calling the script via ansible and support multi splunk instances
# 20190517 fix splunk hone path detection with arg when usual splunk not present
# 20190904 fix managed secret detection with arg 
# 20190904 move more content after arg detection, add systemctl daemon-reload to ensure systemd has taken into account changes for splunk services
# 20190910 move args to use getopt for more robustness and clarity
# 20190918 more args and logic for systemd support
# 20190918 fix --help case
# 20190918 fix splunk stop icase issue before service configured or when moving to systemd
# 20190919 var for splunk home in service file + other fixes
# 20190923 fix path for servicename executable bit removal (systemd)
# 20191009 add inline mode for classic init to speed up usage
# 20191017 increase ram max for systend unit file, integrate polkit install and restart to make sure rules are read and use inline
# 20191021 add extra status for license with systemd + fix boot-start systemd option
# 20200107 change systemd unit file for improved v8 compatibility
# 20200526 add user seed creation and no-prompt option for scripts, add systemd default mode
# 20200608 fix missing stanza for user seed creation
# 20200713 match memorylimit from splunk systemd file for v8+ as it is now dynamic 
# 20200925 add default systemd backup (easier debugging purpose)
# 20200925 integrate os detection to only enable systemd when matching requirements
# 20200925 fix/improve help usage
# 20200928 add group forcing to systemd service and use name instead of id to reflect product change

# warning : if /opt/splunk is a link, tell the script the real path or the chown will not work correctly
# you should have installed splunk before running this script (for example with rpm -Uvh splunk.... which will also create the splunk user if needed)
# the script also work for upgrades

use strict;
use Getopt::Long;


# this part moved to user seed
# YOU NEED TO SET THE TARGET PASSWORD !
# it is used on every instance even when you disable web interface
#my $SPLUNKPWD="changed";
#die ("You really want to set a GOOD password for splunk admin (ie generate it for example) \nPlease edit the script and read the comments\n") unless ($SPLUNKPWD ne "changed");


my $DEBUG=1;

my $MANAGEDSECRET=1; # if true , we have already deployed splunk.secret and dont want to install splunk in case we forgot to copy splunk.secret

# you can now specify command line args to disable it for initial splunk.secret generation (to generate the first splunk.secret file)
# $MANAGEDSECRET=0;     # we dont care but we wont be able to push obfuscated password easily

print "managed secret $MANAGEDSECRET \n" if ($DEBUG);

# user for splunk
my $USERSPLUNK='splunk';

# setup directories for splunk :

my $SPLUNK_SUBSYS="splunk";
my $SPLUNK_HOME="/opt/splunk";

#$SPLUNK_SUBSYS="splunkforwarder";
#$SPLUNK_HOME="/opt/splunkforwarder";


# set to 1 if use of separate index partition, set to 0 otherwise
# note : on sh , hf, .... you need the directory like on idx to be able to deploy thge indexes app correctly (used for autocompletion, configurations in add )
my $USESPLINDEX= 0;
# note : this is the base directory , we will ask splunk to use a subdirectory, not directly the partition
my $SPLUNK_INDEXES="/opt/splunkindexes";



# declare the perl command line flags/options we want to allow
my %options=();
#getopts("hj:ln:s:", \%options);

my $help;
my $dry_run="";
my $enablesystemd="1";
my $servicename="splunk";
my $no_prompt="";
my $usedefaultunitfile="";

GetOptions (
     'help|h'=> \$help,
     'SPLUNK_HOME|s=s'=> \$SPLUNK_HOME,
     'user_splunk|u=s' => \$USERSPLUNK,
     'use_managed_secret|m=i'=> \$MANAGEDSECRET,
     'splunk_subsys|sub=s' => \$SPLUNK_SUBSYS,
     'dry_run|dry-run' => \$dry_run,
     'systemd-managed|systemd=s' => \$enablesystemd,
     'no-prompt' => \$no_prompt,
     'with-default-service-file' => \$usedefaultunitfile,
     'service-name=s' => \$servicename

  );

if ($help) {
	print "splunkconf-initsplunk.pl [options]
This script will initialize Splunk software after package installation or upgrade (tar or RPM)
This version works with Splunk 7.1,7.2,7.3 or 8.0 (it would only work for upgrade for previous versions as the admin user creation changed)
This version will work for full Splunk Enterprise or UF
The behavior will change depending on type
admin password creation (Full, required existing or via user-seed.conf, UF no account creation required (unless you provide user-seed.conf file)


       where options are 
	--help|-h this help
        --SPLUNK_HOME|-s=   SPLUNK_HOME custom path (default /opt/splunk)
        --user_splunk|u= splunk_user to use (must exist, default = splunk)
        --use_managed_secret=|-m= Managed Secret mode (0=each instance generate a custom splunk.secret (prevent centralized obfuscated passwords)(use this first time to generate one), 1=managed secret provided, refuse to install if not present)(defautl, recommended)
	--splunk_subsys=|sub= name of Splunk service (splunk or splunkforwarder or the instance name) ?(default=splunk)
        --systemd-managed|systemd=s  auto|systemd|init auto=let splunk decide, systemd ask for systemd
        --service-name=    specific service name for systemd 
        --with-default-service-file  use the default systemd file generated by splunk (without extra tuning)
        --dry-run  dont really do it (but run the checks)
        --no-prompt   disable prompting (for scripts) (will disable ask for user seed creation for example)
";
	exit 0;
} else {
  print "please run splunkconf-initsplunk.pl --help for script explanation and options\n";
}

if ($enablesystemd==0 || $enablesystemd eq "init") {
  $enablesystemd=0;
} else {
  $enablesystemd=1 ;
  if (check_exists_command('systemctl') && check_exists_command('rpm') ) {
    print "systemd present and rpm, may be systemd\n";
    my $systemdversion=`systemctl --version| head -1 | cut -d" " -f 2`;
    chomp($systemdversion);
    if ($systemdversion>218) {
       print " systemd version ($systemdversion) ok\n";
       my $polkitversion=`rpm -qi polkit| grep Version |cut -d":" -f 2`;
       chomp($polkitversion);
       print " polkit version ($polkitversion) \n";
       if ($polkitversion > 0) {
         $enablesystemd=1 ;
         print " check polkit ok\n";
       } else {
         $enablesystemd=0 ;
         print " check polkit ko\n";
      }
    } else {
     print "systemd test version ko, lets fallback to use initd\n";
     $enablesystemd=0;
    }
  } else {
    print "systemctl or rpm no detected, lets fallback to use initd\n";
    $enablesystemd=0;
  }
}

if ($servicename) {
  print "servicename is set to $servicename\n";
} else {
  $servicename="splunk";
  print "servicename set to $servicename\n";
}

# su location detection 
my $SUBIN="/bin/su";

if (-e "/bin/su") {
     print "OK su found in /bin \n" if ($DEBUG);
} elsif (-e "/usr/bin/su") {
    $SUBIN = "/usr/bin/su";
} else {
    die ("cant find su . FIXME it's needed to become splunk user");
}

# variables for splunk installation

#if (@ARGV ==0 ) {
#  print "no argument given to script , using settings inside script\n";
#} elsif (@ARGV==5 || @ARGV ==6 ) {
#   $SPLUNK_HOME=$ARGV[0];
## splunk or splunkforwarder or the instance name
#   $SPLUNK_SUBSYS=$ARGV[1];
#   $USERSPLUNK=$ARGV[2];
## managedsecret 0 or 1
#  $MANAGEDSECRET=$ARGV[3];
## usesplunkindex only for indexers usually
## 0 dont use, 1 use
#  $USESPLINDEX=$ARGV[4];
#  if ($USESPLINDEX == 1) {
#    $SPLUNK_INDEXES=$ARGV[5];
#  }
#} else {
#print "Syntax : initsplunk.pl SPLUNK_HOME SPLUNK_SUBSYS(splunk splunkforwarder) USERSPLUNK MANAGEDSECRET(0,1) USESPLUNKINDEX(0,1) [SPLUNK_INDEXES_PATH]\n";
#   die ("arg number is different that expected values , this is not correct. Please check and fix \n");
#}

# if we are installing first time, we expect that admin has created user-seed.conf
# see https://docs.splunk.com/Documentation/Splunk/latest/Admin/User-seedconf
# if this is not the first time, then we have a already existing passwd file
# if neither are there, we won't have a admin password set !
# for uf, that could be a good thing but for central component, we should probably ask for the admin to correct before running the installation

my $SPLUSERSEED=$SPLUNK_HOME."/etc/system/local/user-seed.conf";

my $SPLPASSWDFILE=$SPLUNK_HOME."/etc/passwd";

my $INITIALSPLAPPSDIR=$SPLUNK_HOME."/splunkapps/initialapps";

my $SPLAPPSDIR=$SPLUNK_HOME."/etc/apps";

my $SPLSPLUNKBIN=$SPLUNK_HOME."/bin/splunk";
unless (-e $SPLSPLUNKBIN) {
  die ("cant find splunk bin. Please check path ($SPLSPLUNKBIN) and make sure you installed splunk via rpm -Uvh splunkxxxxxxx.rpm (or yum) which also created user and splunk group");
}

if (-d $INITIALSPLAPPSDIR) {
   print "$INITIALSPLAPPSDIR directory is existing. Alls the apps in this directory will be copied initially to etc/apps directory. Please make sure you only copy the necessary apps and manage as needed via a central mechanism \n";
   `cp -rp $INITIALSPLAPPSDIR/* $SPLAPPSDIR/` unless ($dry_run); 
} else {
  print "$INITIALSPLAPPSDIR directory is not existing. No initial app will be copied\n";
}

# if splunkforwarder then it is normal to not create a admin account to reduce attack surface
unless (-e $SPLUSERSEED || -e $SPLPASSWDFILE || $SPLUNK_SUBSYS eq "splunkforwarder") {
  if ($no_prompt) {
    print "this is a new installation of splunk. Please provide a user-seed.conf with the initial admin password as described in https://docs.splunk.com/Documentation/Splunk/latest/Admin/User-seedconf you should probably use splunk hash-passwd commend to generate directly the hashed version  \n";
    die("") unless ($dry_run);
  } else {
    print "You havent provided a user-seed.conf file, that is used to initiate the admin account, let's create one\n";
    print "enter admin account name (enter to use admin)(do NOT change admin name for premium apps)\n";
    my $name=<STDIN>;
    chomp($name);
    # use admin is enter was pressed
    $name="admin" unless length($name)>2;
    #print "using $name for admin account\n";
    my $password="";
    while (length($password)<10) {
      print "enter $name password (10 character min, please set a secure one for example by using a password generator\n";
      $password=<STDIN>;
      chomp($password);
    }
    my $hash=`su - $USERSPLUNK -c "$SPLSPLUNKBIN hash-passwd $password"`;
    open(FF,'>',$SPLUSERSEED) or die $!;
    my $str = <<ENDING;
# this file generated by splunkconf-init
[user_info]
USERNAME = $name
HASHED_PASSWORD = $hash
ENDING
   print FF $str;
   close(FF);
   print "backuping user-seed.conf file to /tmp. You can reuse this file to prevent being prompted and for scripter installation\n";
   `cp $SPLUSERSEED /tmp/user-seed.conf;chmod 600 /tmp/user-seed.conf`;
  }
}

# to be able to reread password obfuscated with splunk.secret,
#  we need to save and restore this file before splunk restart (or a new one would be created and all the password saved would not be readable by Splunk

my $SPLSECRET=$SPLUNK_HOME."/etc/auth/splunk.secret";
unless (-e $SPLSECRET || $MANAGEDSECRET==0) {
 # copy here -> fixme, env specific
  print ("splunk.secret file hasn't been copied by you before starting splunk first time. Fix this BEFORE starting splunk or unset managedsecret \n");
  die("") unless ($dry_run);

}

# warning : the file should be the one for splunkforwarder if needed (especially for the case where one splunk enterprise and one uf are deployed on the same os 
my $SPLINITTEMPLATE=$SPLUNK_HOME."/scripts/init/".$SPLUNK_SUBSYS."init.template";
#my $SPLINITTEMPLATE=$SPLUNK_HOME."/scripts/init/splunkinit.template";

my $INITTEMPLATEMODE=0;
if ($enablesystemd==1) {
  print "systemd , no init template required\n";
} else {
  if (-e $SPLINITTEMPLATE )  {
    $INITTEMPLATEMODE=1;
    print "using $SPLINITTEMPLATE as template for init script\n";
  } else {
    #print ("please copy splunkinit.template file to $SPLINITTEMPLATE before running this installation script. this is to replace the default script with the su - version, which is improving security and also forcing logging as splunk which will set the ulimit correctly when started via system\n");
    #die("") unless ($dry_run);
    print "using inline template for init script\n";
    $INITTEMPLATEMODE=0;
  }
}


print "Installation parameters : \n SPLUNK_HOME ${SPLUNK_HOME}\n";
print "Splunk user $(USERSPLUNK} \n";
print "Managed Secret $(MANAGEDSECRET}\n";
print "SUBSYS ${SPLUNK_SUBSYS} \n";
print "servicename set to $servicename\n";
print "enable systemd is set to $enablesystemd (1=will enable)\n";
print "inittemplatemode=${INITTEMPLATEMODE} \n";
#print 

exit 0 if ($dry_run);

if ($USESPLINDEX) {
	# create splunk indexes path
	`mkdir -p $SPLUNK_INDEXES/indexes`  || die ("index directory creation failed !");
       #`/bin/chown -R $USERSPLUNK. $SPLUNK_INDEXES` || die ("chown to $USERSPLUNK failed for indexes directory $SPLUNK_INDEXES. Have you installed splunk via rpm ? if not , please make sure $USERSPLUNK user and group are created and splunk default group is splunk");
       `/bin/chown -R $USERSPLUNK. $SPLUNK_INDEXES`;
}

# give file back to splunk just in case  (see also releases notes SPL-89640, this is required during upgrade du to a rpm ressetting a dir as root))

#  chown sometimes fail and return non 0 code making the script die
# if you are sure that it works, uncomment the die part (add a ; at the end)
#`/bin/chown -R $USERSPLUNK. $SPLUNK_HOME` || die ("chown to $USERSPLUNK failed for splunk home $SPLUNK_HOME directory. Have you installed splunk via rpm ? if not , please make sure $USERSPLUNK user and group are created and splunk default group is splunk");
`/bin/chown -R $USERSPLUNK. $SPLUNK_HOME`;



# first start or upgrade start

# need to start first as splunk user to create keys as splunk (SPL-119418)
# restart as we may be upgrading
# --answer-yes in case we perform migration

if ($enablesystemd==1) {
  print "systemd -> restart for upgrade must be done via service unit\n";
}
else {
  print "first start as splunk user (Please wait a few seconds) \n" if ($DEBUG);
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk restart --accept-license --answer-yes --no-prompt" `;
}
# as root 
# don't remove this command, this is needed to correctly set splunk-launch.conf
print "configure boot start with splunk user\n";

sub check_exists_command { 
    my $check = `sh -c 'command -v $_[0]'`; 
    return $check;
}


# post 7.2.2 included, deploy in init mode if we are not on this version fallback to the command without the new option
if ($enablesystemd==1) {
  print "configuring with systemd\n";
  $servicename="splunk" unless ($servicename);
  # install and restart as may be needed
  print "installing polkit if necessary\n";
  `yum install -y polkit`;
  my $POLKITRULE="/etc/polkit-1/rules.d/99-splunk.rules";
  my $POLKITHELPER="/usr/local/bin/polkit_splunk";
  unless (-e ${POLKITRULE} && -e ${POLKITHELPER} ) {
    print ("polkit file file hasn't been copied by you before starting splunk first time. Trying to fix with inline version \n");
    open(FH, '>', ${POLKITRULE}) or die $!;
    my $strpol= <<EOF;
// this file should be readable by other or polkit would fail reading it (and also could not compile in that case)
// after deploying /changing this file, please run systemctl restart polkit (or reboot)
// and check /var/log/secure 
// in case of error, polkit will say 
// polkitd[pid]: Error compiling script /etc/polkit-1/rules.d/99-splunk.rules
// in case of succes, you would just see something like
// polkitd[pid]: Reloading rules
// polkitd[pid]: Collecting garbage unconditionally...
// polkitd[pid]: Loading rules from directory /etc/polkit-1/rules.d
// polkitd[pid]: Loading rules from directory /usr/share/polkit-1/rules.d
// polkitd[pid]: Finished loading, compiling and executing 3 rules
// im the case that user is splunk user or a member of splunk or wheel group then call the helper script 
// the helper script will only authorize is the service to start is splunk service
// user not splunk admin -> blocked here (we dont want any user to stop splunk to hide his track, dont you ?)
// user splunk or splunk group or wheel group and ask to stop/start a splunk service -> authorized by helper script
// user splunk or splunk group or wheel group and ask to stop/start another  service -> return AUTH_ADMIN

polkit.addRule(function(action, subject) { 
        if (action.id == "org.freedesktop.systemd1.manage-units"  && (subject.user == "splunk" || subject.isInGroup("splunk") || subject.isInGroup("wheel"))
                ) { 
                try { 
                        polkit.spawn(["/usr/local/bin/polkit_splunk", ""+subject.pid]);
                        return polkit.Result.YES; 
                } 
                catch (error) { 
                        return polkit.Result.AUTH_ADMIN; 
                } 
        }
});
EOF
    print FH $strpol;
    close(FH);
    `chown root. ${POLKITRULE}; chmod 444 ${POLKITRULE}`;
    open(FH, '>', ${POLKITHELPER}) or die $!;
    my $strpolhelp= <<EOF;
#!/bin/bash 

# polkit_splunk
# this file should be owned by root:root , read-executable by everybody (755)
# chown root.root /usr/local/bin/polkit_splunk;chmod 755 /usr/local/bib/polkit_splunk
# this file should be in /usr/local/bin which is controlled by root
# it is called by polkit rule in /etc/polkit-1/rules.d/99-splunk.rules
# DO NOT PUT this file under /opt/splunk for obvious security reasons
# this file is used for splunk 7.2.2+ but only when configured with the new systemd unit
# in that case, it is catching command launched by splunk user when doing splunk restart, splunk stop, splunk start ...
# underlying splunk call systemd via systemctl command arg

# 20190427 add vars and logging
# 20190429 change facility and move to internal bash regex for servicename detection
# 20190513 fix typos in comment + clarify some, switch off debug mode

# logs with authpriv.info can usually be found in /var/log/secure

COMM=(\$(ps --no-headers -o cmd -p \$1))

ACTION=\${COMM[1]}
SERVICENAME=\${COMM[2]}

# uncomment the following 2 lines only for testing purpose 
#ACTION=stop
#SERVICENAME=Splunkforwarder_01

/bin/logger -p authpriv.info  "polkit_splunk called pid=\$1. systemctlaction=\$ACTION, servicename=\$SERVICENAME"

# status action is not usually needed, it should be already autorized
if [[ "\$ACTION" == "start" ]] || 
   [[ "\$ACTION" == "stop"  ]] || 
   [[ "\$ACTION" == "status"  ]] || 
   [[ "\$ACTION" == "restart" ]]; then
    # splunk traditional service name
    # Splunkd default with 7.2.2+
    # also add versions for forwarder and specific names based on assumption that service should start with splunk or Splunk
    # can be called with .service at the end
    # bash inline regex only support subset of pcre (cant use \w for example) (this avoids calling a external command)
    regexp=^[sS]{1}plunk[a-zA-Z0-9_\-]*\$
    if [[ "\$SERVICENAME" =~ \${regexp} ]]; then
      /bin/logger -p authpriv.info  "polkit_splunk action=success pid=\$1. systemctlaction=\$ACTION, servicename=\$SERVICENAME"
      exit 0
    fi
fi

# failure(denied) by default
/bin/logger -p authpriv.info  "polkit_splunk action=failure pid=\$1. systemctlaction=\$ACTION, servicename=\$SERVICENAME"
exit 1  
EOF
    print FH $strpolhelp;
    close(FH);
    `chown root. ${POLKITHELPER}; chmod 755 ${POLKITHELPER}`;
  }
  # depending on polkit version, it is necessary to restart the service to have it reread config files so let's do it
  print "restarting polkit\n";
  `sleep 1;systemctl restart polkit`;
  # stopping splunk just in case for upgrade case as enable boot start will refuse to configure if service is running
  #print "stopping splunk via systemctl stop $servicename\n";
  #`systemctl stop $servicename`;
  # if we are migrating to systemd from init, it is mandatory to stop splunk here or there will be a splunk process not known and managed from systemd....
  # could also be the case where we changed servicename
  print "asking status to accept license if first time via $SUBIN - $USERSPLUNK -c \"$SPLUNK_HOME/bin/splunk status --accept-license --no-prompt\"\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk status --accept-license --no-prompt"`;
  print "stopping splunk via $SUBIN - $USERSPLUNK -c \"$SPLUNK_HOME/bin/splunk stop --accept-license --no-prompt\"\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk stop --accept-license --no-prompt"`;
  print "force stopping splunk via $SUBIN - $USERSPLUNK -c \"$SPLUNK_HOME/bin/splunk stop -f --accept-license --no-prompt\"\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk stop -f --accept-license --no-prompt"`;
  # removing all init file if needed
  print "disabling boot-start via $SPLUNK_HOME/bin/splunk disable boot-start\n";
  `$SPLUNK_HOME/bin/splunk disable boot-start`;
  print "enabling boot-start via $SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK -systemd-managed 1 -systemd-unit-file-name $servicename\n";
  `$SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK -systemd-managed 1 -systemd-unit-file-name $servicename`;
  unless ($usedefaultunitfile) {
    # customizing system unit file
    # default file used by splunk /etc/systemd/system/splunk.service
    # /etc/systemd/system/$servicename.service
    my $filenameservice = '/etc/systemd/system/'.$servicename.'.service';
    my $filenameservicebck = '/etc/systemd/system/'.$servicename.'.service.orig-bck';
    print "backup default service file  $filenameservice to $filenameservicebck \n";
    `cp $filenameservice $filenameservicebck`;
    print "creating custom systemd service in $filenameservice\n";
    my ($name, $passwd, $uid, $gid, $quota, $comment, $gcos, $dir, $shell) = getpwnam($USERSPLUNK);
    print "Name = $name\n";
    print "UID = $uid\n";
    print "GID = $gid\n";
    # old default before v8 #MemoryLimit=4073775104
    # assuming v8+ here as the old default was 4G which would not be dynamic
    my $systemdmemlimit=`grep ^MemoryLimit $filenameservice | cut -d"=" -f 2`;
    # checking ram so we can detect if we are exactly at 4G 
    my $ram = (`cat /proc/meminfo |  grep "MemTotal" | awk '{print \$2}'`);
    if ($systemdmemlimit <100 || ($systemdmemlimit==4073775104 && $ram!=4073775104)) {
      print "using 100G as mem limit for systemd service as either the value we got was too low or was matching the default pre v8\n";
      $systemdmemlimit="100G";
    } else {
      print "Reusing Systemd Memory limit we got from default service file MemoryLimit=$systemdmemlimit\n"
    }
    open(FH, '>', $filenameservice) or die $!; 
    my $str= <<EOF;
#This unit file replaces the traditional start-up script for systemd
#configurations, and is used when enabling boot-start for Splunk on
#systemd-based Linux distributions.
# customized version

[Unit]
Description=Systemd service file for Splunk, generated by 'splunk enable boot-start'
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=$SPLUNK_HOME/bin/splunk _internal_launch_under_systemd
# Send KillSignal only to main (splunkd) process, if any of the child processes is still alive after \$TimeoutStopSec, SIGKILL them.
KillMode=mixed
# Splunk doesn't shutdown gracefully on SIGTERM
KillSignal=SIGINT
# Give Splunk time to shutdown - especially busy indexers can take time (increased from 360s)
TimeoutStopSec=10min
# increased value
LimitNOFILE=262143
SuccessExitStatus=51 52
RestartPreventExitStatus=51
RestartForceExitStatus=52
User=$USERSPLUNK
Group=splunk
Delegate=true
CPUShares=1024
MemoryLimit=$systemdmemlimit
PermissionsStartOnly=true
# change needed for 8.0+ ExecStartPost to ExecStartPre to change the permissions before Splunk is started (see answers 781532 )
ExecStartPre=/bin/bash -c "chown -R $USERSPLUNK:splunk /sys/fs/cgroup/cpu/system.slice/%n"
#ExecStartPre=/bin/bash -c "chown -R $uid:$gid /sys/fs/cgroup/cpu/system.slice/%n"
ExecStartPre=/bin/bash -c "chown -R $USERSPLUNK:splunk /sys/fs/cgroup/memory/system.slice/%n"
#ExecStartPre=/bin/bash -c "chown -R $uid:$gid /sys/fs/cgroup/memory/system.slice/%n"
## Modifications to the base Splunkd.service that is created from the "enable boot-start" command ##
# set additional ulimits:
LimitNPROC=262143
LimitFSIZE=infinity
LimitCORE=infinity
# Have splunk if just starting after an upgrade or for the first time accept the license and answer yes to the migration
ExecStartPre=/bin/bash -c '/usr/bin/su - $USERSPLUNK -s /bin/bash -c \'$SPLUNK_HOME/bin/splunk status --accept-license --answer-yes --no-prompt\';true'
# wait to avoid restarting too fast
RestartSec=5s

[Install]
WantedBy=multi-user.target


EOF
    print FH $str;
    close(FH);
    # remove exec as not needed and may create warning by ststemd
    `chmod a-x $filenameservice`;
    print "telling systemd the unit files may have changed via systemctl daemon-reload\n";
    `systemctl daemon-reload`;
    print "telling systemd the service $servicename is enabled via systemctl enable $servicename\n";
    `systemctl enable $servicename`;
    print "telling systemd to start the $servicename service via systemctl start $servicename\n";
    `systemctl start $servicename`;
  } # usedefaultunitfile
  print "waiting 10s for initialization ....\n";
  # time to let splunk initialize correctly
  sleep(10);
} else 
{ #init mode
  $servicename="splunk" unless ($servicename);
  # stopping splunk just in case for upgrade case as enable boot start will refuse to configure if service is running
  #`systemctl stop $servicename`;
  print "stopping splunk via $SUBIN - $USERSPLUNK -c \"$SPLUNK_HOME/bin/splunk stop --accept-license --no-prompt\"\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk stop --accept-license --no-prompt"`;
  print "force stopping splunk via $SUBIN - $USERSPLUNK -c \"$SPLUNK_HOME/bin/splunk stop -f --accept-license --no-prompt\"\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk stop -f --accept-license --no-prompt"`;
  # removing all init file if needed
  `$SPLUNK_HOME/bin/splunk disable boot-start`;
  print "configuring with traditional init\n";
  `$SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK -systemd-managed 0 || $SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK `;
  if ($INITTEMPLATEMODE==1) {
     print "replacing init script with the template one using su - (security+ulimit)\n";
     `chown root. $SPLINITTEMPLATE;chmod 700 $SPLINITTEMPLATE;cp -p $SPLINITTEMPLATE /etc/init.d/$SPLUNK_SUBSYS`;
  } else {
     print "using inline template for init script (servicename=$servicename) \n";
     my $filenameinit = '/etc/init.d/'.$servicename;
     open(FH, '>', $filenameinit) or die $!;
     my $strinit= <<EOF;
#!/bin/sh
#
# /etc/init.d/$servicename
# init script for Splunk.
# initially generated  by 'splunk enable boot-start'.

# ******* MODIFIED FOR su - (ref https://docs.splunk.com/Documentation/Splunk/latest/Admin/ConfigureSplunktostartatboottime)  , please dont rerun enable boot-start as that would loose the tuning !!! 
#
# chkconfig: 2345 90 60
# description: Splunk Core service
#
# v 20191008

RETVAL=0
USER=${USERSPLUNK}

SPLUNK_SUBSYS=${SPLUNK_SUBSYS}
 
. /etc/init.d/functions

# note : THP should probably be done at the system level or you may use the dynamic version in this script if you prefer

# Note : change_ulimit no longer needed as we now use systematically su that log to splunk and call pam_limits
# make sure you have deployed /etc/security/limits.d/99-splunk-limits.conf (or equivalent) with appropriate values for your splunk usage

 
splunk_start() {
  echo Starting $servicename...
  su - \${USER} -s /bin/bash -c '"${SPLUNK_HOME}/bin/splunk" start --no-prompt --answer-yes'
  RETVAL=\$?
  [ \$RETVAL -eq 0 ] && touch /var/lock/subsys/\${SPLUNK_SUBSYS}
}
splunk_stop() {
  echo Stopping $servicename...
  su - \${USER} -s /bin/bash -c '"${SPLUNK_HOME}/bin/splunk" stop'
  RETVAL=\$?
  [ \$RETVAL -eq 0 ] && rm -f /var/lock/subsys/\${SPLUNK_SUBSYS}
}
splunk_restart() {
  echo Restarting $servicename...
  su - \${USER} -s /bin/bash -c '"${SPLUNK_HOME}/bin/splunk" restart'
  RETVAL=\$?
  [ \$RETVAL -eq 0 ] && touch /var/lock/subsys/\${SPLUNK_SUBSYS}
}
splunk_status() {
  echo $servicename status:
  su - \${USER} -s /bin/bash -c '"${SPLUNK_HOME}/bin/splunk" status'
  RETVAL=\$?
}

case "\$1" in
start)
   splunk_start
   ;;
stop)
   splunk_stop
   ;;
restart)
   splunk_restart
   ;;
status)
   splunk_status
   ;;
esac

 
exit \$RETVAL
EOF
    print FH $strinit;
    close(FH);
    # exec 
    `chmod u+x $filenameinit`;
    print "telling systemd the unit file may have changed\n";
    `systemctl daemon-reload`;
    print "telling systemd the service is enabled";
    `systemctl enable $servicename`;
    print "telling systemd to start the service";
    `systemctl restart $servicename`;
  } # inittemplatemode
  # change var inside the su as the shell script wont pass the variable when switching user
  #`sed -i '' 's/$\{SPLUNK_HOME\}/$SPLUNK_HOME/g' /etc/init.d/$SPLUNK_SUBSYS`;
  # check here -> we may need extra system command to make sure service is enabled for splunkforwarder case
  print "telling systemd the unit file may have changed\n";
  `systemctl daemon-reload`;
  print "waiting 10s....\n";
  # time to let splunk initialize correctly
  sleep(10);
  print "restarting splunk to make distributed functions operationnal (Please wait for restart to complete)\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk restart --no-prompt " `;
  print "waiting 10s....\n";
  # time to let splunk initialize correctly
  sleep(10);
}


# this has been moved to user-seed
# change password by default , required for distributed search to work
#`$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk edit user admin -password '$SPLUNKPWD' -role admin --no-prompt -auth admin:changeme"`;

# splunk should now have started and move user-seed to passwd. If the file doesn't exist and we are not on a splunkforwarder we have a problem...
unless ($SPLPASSWDFILE || $SPLUNK_SUBSYS=="splunkforwarder") {
    die("problem : admin password not set after restart. user-seed.conf may have been invalid");
}


#print "remove password change on UI\n";
# remove password change request on UI
`$SUBIN - $USERSPLUNK -c "/usr/bin/touch ${SPLUNK_HOME}/etc/.ui_login" `;


print "end of installation script\n";
#  



