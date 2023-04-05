#!/usr/bin/perl -w

# Copyright 2022 Splunk Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributor :
#
# Matthieu Araman, Splunk
#

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
# 20190918 fix splunk stop case issue before service configured or when moving to systemd
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
# 20201009 typos fix to remove warning and improve logging
# 20201010 add version detection logic
# 20201011 remove extra die when no user seed for 7.0
# 20201019 add support for running pre 7.3 version on systemd capable (falling back to init) 
# 20201020 slight change to systemd service file for cgroups WLM support (as 8.1 changed again to execstartpost, we try to do both
# 20201103 remove the post statement from systemd for now as 8.0.7 now complain about it...
# 20201104 add logic to push different systemd file for 8.1 as 8.0.7 refuse to see execstartpost during a upgrade but 8.1 need it
# 20201104 add both cpu and memory to execstart pre and post
# 20210126 fix quotes in execstartpre to make systemd happy
# 20210201 include default workload pool in systemd mode
# 20210204 improve splunk version detection to remove extra message in case of upgrade + add fallback method via rpm version  + fallback to 8.1.0 by default 
# 20210208 increase max mem for ingest pool
# 20210406 add debian fallback to policykit instead of polkit (see https://wiki.debian.org/PolicyKit ) (this is less granular than the polkit version but the less evil way of doing under debian at the moment...) 
# 20210413 add disable-wlm option 
# 20210413 add options for multids 
# 20210414 more debian support
# 20210415 more debian support
# 20210521 autoadapt splunkhome for forwarder subsys
# 20210521 more multids stuff
# 20210526 tar for multids
# 20210527 add auto port support for multids, register to lb, option to specify splunk group
# 20210527 more tuning for ds splunk-launch, deployment apps hard link support 
# 20210604 add mgmt port list to file for reload script
# 20210604 add auto link for serverclass app (need to be named app_serverclass and contain local/serverclass.conf), app inputs.conf specific ds name support
# 20210607 add dsetcapps option
# 20210608 add splunkorg option and automatically use it for dsetcinapps list
# 20210615 fix regression with AWS1 support
# 20210627 update help to state it is fine with 8.2 (no change)
# 20211013 test for 8.3 (no change)
# 20211016 add option to use generated polkit + set group when calling boot-start in systemd mode (for default case)
# 20211021 add systemd in option name for default service file to ease usage
# 20220112 fix type mismatch in test
# 20220119 add more tests and messages for DS splunk-launch tuning and restart service after applying
# 20220203 fix warning in test condition
# 20220316 add logic for splunktar without DS
# 20220611 fix test condition "generated"
# 20221205 add support for splunkacceptlicense tag 
# 20221205 add extra chown before first version detection
# 20230104 fix typo in text
# 20230106 add more arguments to splunkconf-init so it knows it is running in cloud and new tag splunkpwdinit
# 20230108 add more arguments region and splunkpwdarn
# 20230108 add splunkpwdinit support (aws specific)
# 20230109 remove potential extra line output from rand command
# 20230329 rework logic block for interacting with AWS SSM for user seed 
# 20230329 remove commented code to improve readability and add more info  message
# 20230405 update wlm default pools

# warning : if /opt/splunk is a link, tell the script the real path or the chown will not work correctly
# you should have installed splunk before running this script (for example with rpm -Uvh splunk.... which will also create the splunk user if needed)
# the script also work for upgrades

use strict;
use Getopt::Long;

my $VERSION;
$VERSION="20230405a";

print "splunkconf-init version=$VERSION\n";

my $DEBUG=1;

my $MANAGEDSECRET=1; # if true , we have already deployed splunk.secret and dont want to install splunk in case we forgot to copy splunk.secret

# you can now specify command line args to disable it for initial splunk.secret generation (to generate the first splunk.secret file)
# $MANAGEDSECRET=0;     # we dont care but we wont be able to push obfuscated password easily

print "managedsecret=$MANAGEDSECRET \n" if ($DEBUG);

# user for splunk
my $USERSPLUNK='splunk';
my $GROUPSPLUNK='splunk';

# setup directories for splunk :

my $SPLUNK_SUBSYS="splunk";
my $SPLUNK_HOME="/opt/splunk";

# for splunkpwdinit
# multiple of 3 or padding with = occur
# https://en.wikipedia.org/wiki/Base64#Output_padding
my $length=20;
my $valid=0;
my $res="";
my $maxgen=1000;
my $gen=0;
my $hash="";
my $newhash=1;

my $str="";

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
my $disablewlm="";
my $systemdpolkit="inline";
my $splunkrole="";
my $splunkorg="org";
my $instancenumber="";
# only for multids, otherwise it has been deployed before (usually via rpm)
my $splunktar="";
my $usedefaultunitfile="";
my $splunkacceptlicense="no";
my $cloud_type="";
my $splunkpwdinit="no";
my $dsetcapps="org_all_deploymentserverbase,org_full_license_slave,org_to-site_forwarder_central_outputs,org_search_outputs-disableindexing,org_dsmanaged_disablewebserver";
my $region="missing";
my $splunkpwdarn="notset";


GetOptions (
     'help|h'=> \$help,
     'SPLUNK_HOME|s=s'=> \$SPLUNK_HOME,
     'user_splunk|u=s' => \$USERSPLUNK,
     'group_splunk|g=s' => \$GROUPSPLUNK,
     'use_managed_secret|m=i'=> \$MANAGEDSECRET,
     'splunk_subsys|sub=s' => \$SPLUNK_SUBSYS,
     'dry_run|dry-run' => \$dry_run,
     'systemd-managed|systemd=s' => \$enablesystemd,
     'systemd-polkit=s' => \$systemdpolkit,
     'no-prompt' => \$no_prompt,
     'disable-wlm' => \$disablewlm,
     'splunkrole=s' => \$splunkrole,
     'splunkorg=s' => \$splunkorg,
     'dsetcappss=s' => \$dsetcapps,
     'instancenumber=i' => \$instancenumber,
     'splunktar=s' => \$splunktar,
     'splunkacceptlicense=s' => \$splunkacceptlicense,
     'with-default-service-file|with-default-systemd-service-file' => \$usedefaultunitfile,
     'service-name=s' => \$servicename,
     'cloud_type=s' => \$cloud_type,
     'splunkpwdinit=s' => \$splunkpwdinit,
     'region=s' => \$region,
     'splunkpwdarn=s' => \$splunkpwdarn

  );

if ($help) {
	print "splunkconf-initsplunk.pl [options]
This script will initialize Splunk software after package installation or upgrade (tar or RPM)
This version works with Splunk 7.1,7.2,7.3,8.0,8.1,8.2,8.3 and 9.0(it would only work for upgrade for previous versions as the admin user creation changed)
This version will work for full Splunk Enterprise or UF
The behavior will change depending on type
admin password creation (Full, required existing or via user-seed.conf, UF no account creation required (unless you provide user-seed.conf file)


       where options are 
	--help|-h this help
        --SPLUNK_HOME|-s=   SPLUNK_HOME custom path (default /opt/splunk)
        --user_splunk|u= splunk_user to use (user must exist, default = splunk)
        --group_splunk|g= group_user to use (group must exist, default = splunk)
        --use_managed_secret=|-m= Managed Secret mode (0=each instance generate a custom splunk.secret (prevent centralized obfuscated passwords)(use this first time to generate one), 1=managed secret provided, refuse to install if not present)(defautl, recommended)
	--splunk_subsys=|sub= name of Splunk service (splunk or splunkforwarder or the instance name) ?(default=splunk)
        --systemd-managed|systemd=s  auto|systemd|init auto=let splunk decide, systemd ask for systemd
        --systemd-polkit=s  inline|generated  inline(default)=use the splunkconf-init version, generated = ask splunk to generate it (8.1+ required)
        --service-name=    specific service name for systemd 
        --with-default-systemd-service-file  use the default systemd file generated by splunk (without extra tuning)
        --disable-wlm do not create wlm configuration (systemd only)
        --splunkorg=org specify org name used for base apps (dont use org, replace with the one from your organisation)
        --splunkrole=xxx run specific code for a specific role (currently implemented : ds) 
        --instancenumber=number to be used for multids only , will use this for suffix and will also change ports and register the instance in lvs vip (created before outside this script)
        --dsetcapps=\"app1,app2,app3,....\" to automatically set up the etc app versions of these apps from deployment-apps on a DS (short name, apps need to be defined in deployment-apps BEFORE) (example(replace org with your org): $dsetcapps)
rg_all_tls
        --splunktar=splunkxxxx.tar.gz required for multids 
        --splunkacceptlicense=\"yes|no\" pass the setting along  (obviously if no, you wont go far)
        --splunkpwdinit=\"yes|no\" tell if this instance is supposed to generate a pawssword and user seed if needed (no admin set from backup and no user-seed provided) 
        --region=xxx cloud region (needed for pwdinit)
        --splunkpwdarn=xxxxx  splunkadminpwd AWS secretsmanager arn  (only for splunkpwdinit)
        --dry-run  dont really do it (but run the checks)
        --no-prompt   disable prompting (for scripts) (will disable ask for user seed creation for example)
";
	exit 0;
} else {
  print "splunkconf-initsplunk.pl : use --help for script explanation and options\n";
}

if ( !defined($splunkacceptlicense) ) {
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : ***************** A T T E N T I O N *************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : please read and accept Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html then add --splunkacceptlicense=yes|no as parameter to this script and relaunch\n";
  print "FAIL : if running in cloud env, that should come from instance tag splunkacceptlicense . If the env is created by terraform, that is configured via variables.tf and you didnt set it up if you read this\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  exit 1 unless ($dry_run);
}
if ($splunkacceptlicense ne "yes" ) {
  print "FAIL : *************************************************************************************\n";
  print "FAIL : ***************** A T T E N T I O N *************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : please read and accept Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html as this is needed to setup Splunk via this script\n";
  print "FAIL : if running in cloud env, that should come from instance tag splunkacceptlicense . If the env is created by terraform, that is configured via variables.tf and you didnt set it up if you read this\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  print "FAIL : *************************************************************************************\n";
  exit 1 unless ($dry_run);
} else {
  print "OK got splunkacceptlicense=yes option passed along\n";
}

if ($SPLUNK_SUBSYS =~/forwarder/) {
  #$SPLUNK_SUBSYS="splunkforwarder";
  $SPLUNK_HOME="/opt/splunkforwarder";
  print "forwarder -> changing default splunk_home to $SPLUNK_HOME\n";
}

if ($systemdpolkit eq "inline" || $systemdpolkit eq "generated" ) {
   print "systemdpolkit value set to $systemdpolkit\n";
} else {
   print " WARNING ! invalid value $systemdpolkit for systemdpolkit passed to splunkconf-init, using inline default\n";
   $systemdpolkit="inline";
}
 
# for multids, we keep the original path as it contain global stuff
my $SPLUNK_HOME_ORIG=$SPLUNK_HOME;

if ($splunkrole =~/ds|deployment/ ) {
  print "switching to deployment server install mode\n";
  $splunkrole="ds";
  if ($instancenumber>0) {
    $SPLUNK_HOME="$SPLUNK_HOME/splunk_ds$instancenumber";
    print "deployment server with multiple instances (ds in a box) mode (SPLUNK_HOME=$SPLUNK_HOME)\n";
    if (-e $splunktar) {
      `mkdir -p $SPLUNK_HOME;cd $SPLUNK_HOME;tar --strip-components=1 -zxvf $splunktar; chown -R $USERSPLUNK. $SPLUNK_HOME` unless ($dry_run);
    } else {
      print "ERROR : you need to specify a valid splunk_tar option (current splunktar=$splunktar) that point to splunk tar gz file as we need it to deploy DS\n";
      die ("please fix and relaunch") unless ($dry_run);
    }
  }
} elsif (-e $splunktar) {
  print "deploying with tar splunk $splunktar at $SPLUNK_HOME with user=$USERSPLUNK";
  `mkdir -p $SPLUNK_HOME;cd $SPLUNK_HOME;tar --strip-components=1 -zxvf $splunktar; chown -R $USERSPLUNK. $SPLUNK_HOME` unless ($dry_run);
}

#my $res;
$res = $dsetcapps =~ s/org/$splunkorg/ge;


# we need to store if the command exist even if we dont deploy splunk in systemd mode
# if on a systemd systemd, we will use this command to tell systemd when we update files for example

my $systemctlexist=check_exists_command('systemctl');

my $distritype="rh";

if ($enablesystemd==0 || $enablesystemd eq "init") {
  $enablesystemd=0;
} else {
  $enablesystemd=1 ;
  if (check_exists_command('systemctl') && check_exists_command('rpm') ) {
    print "systemd present and rpm, may be systemd with newer polkit \n";
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
        print " check systemd version ko, fallback to init d\n";
         $enablesystemd=0 ;
    }
  } elsif (check_exists_command('systemctl') && check_exists_command('apt-get') ) {
      $distritype = "debian";
      # debian / ubuntu
      my $systemdversion=`systemctl --version| head -1 | cut -d" " -f 2`;
      chomp($systemdversion);
      if ($systemdversion>218) {
        print " systemd version ($systemdversion) ok\n";
        $enablesystemd=1 ;
        print " check systemd version ok\n";
      } else {
         $enablesystemd=0 ;
         print " check systemd version  ko\n";
      }
  } else {
    print "systemctl not detected or unknown distrib, lets fallback to use initd\n";
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
     print "INFO: su found in /bin \n" if ($DEBUG);
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
my $SPLUSERSEED_ORIG=$SPLUNK_HOME_ORIG."/etc/system/local/user-seed.conf";

my $SPLPASSWDFILE=$SPLUNK_HOME."/etc/passwd";

my $INITIALSPLAPPSDIR=$SPLUNK_HOME."/splunkapps/initialapps";

my $SPLAPPSDIR=$SPLUNK_HOME."/etc/apps";

my $SPLETCDIR=$SPLUNK_HOME."/etc";

my $SPLDEPLAPPSDIR=$SPLUNK_HOME."/etc/deployment-apps";
my $SPLDEPLAPPSDIROLD=$SPLUNK_HOME."/etc/deployment-apps-old";
my $SPLDEPLAPPSDIR_ORIG=$SPLUNK_HOME_ORIG."/etc/deployment-apps";

my $SPLSECRET=$SPLUNK_HOME."/etc/auth/splunk.secret";
my $SPLSECRET_ORIG=$SPLUNK_HOME_ORIG."/etc/auth/splunk.secret";

my $SPLCERTS=$SPLUNK_HOME."/etc/auth/mycerts";
my $SPLCERTS_ORIG=$SPLUNK_HOME_ORIG."/etc/auth/mycerts";

my $SPLSPLUNKBIN=$SPLUNK_HOME."/bin/splunk";
unless (-e $SPLSPLUNKBIN) {
  die ("cant find splunk bin. Please check path ($SPLSPLUNKBIN) and make sure you installed splunk via rpm -Uvh splunkxxxxxxx.rpm (or yum) which also created user and splunk group");
}

if ($splunkrole =~/ds|deployment/ ) {
  if ( -d $SPLDEPLAPPSDIR_ORIG ) {
     print "$SPLDEPLAPPSDIR_ORIG exist, reusing as reference for $SPLDEPLAPPSDIR\n";
     # unlink if we already had created symlimk link, otherwise we rename to backup dir then create a symlink (so there is only one real directory that can be accesssed through different paths
     `unlink $SPLDEPLAPPSDIR; mv $SPLDEPLAPPSDIR $SPLDEPLAPPSDIROLD;ln -s $SPLDEPLAPPSDIR_ORIG $SPLDEPLAPPSDIR`; 
  } else {
    `mkdir -p $SPLETCDIR`;
    # moving to reuse default content then creating symlink
    `mv $SPLDEPLAPPSDIR $SPLDEPLAPPSDIR_ORIG;ln -s $SPLDEPLAPPSDIR_ORIG $SPLDEPLAPPSDIR`;
  }
  # adding links fron deployment apps to etc apps on DS to increase app consistency (still need a manual restart of DS in case the config change)
  my @etcapps= split(',',$dsetcapps);
  foreach my $val (@etcapps) {
    print "looking at etc apps for $val\n";
    if ( -d "$SPLDEPLAPPSDIR/$val" ) {
      print "$val exist in $SPLDEPLAPPSDIR, adding link in etc app to the version in deployment-apps \n";
      `cd $SPLAPPSDIR; ln -sv ../deployment-apps/$val`;
    } else {
      print "ATTENTION : apps $val specified as argument doesnt exist -> I wont create link for now to a non existing dir but you probably have either a typo or you forget to populate deployment-apps ! Probably not what you want, please check and correct/relaunch\n";
    }
  }
  print "multids -> copy template files for splunk.secret, user-seed.conf and certificates from ${SPLUNK_HOME_ORIG} to ${SPLUNK_HOME}\n";
  # splunk.secret, user-seed.conf and certificates
  `cp -p $SPLUSERSEED_ORIG $SPLUSERSEED; cp -p $SPLSECRET_ORIG $SPLSECRET; mkdir -p $SPLCERTS_ORIG;cp -rp $SPLCERTS_ORIG $SPLCERTS`;
# add here test + deployment apps link
  my $splunk_web_port=8000+$instancenumber;
  my $splunk_mgmt_port=18089+$instancenumber;
  my $splunk_app_port=28065+$instancenumber;
  my $splunk_kvstore_port=8191+$instancenumber;
  print "multids -> changing port for instance $instancenumber to splunk_web_port=$splunk_web_port,splunk_mgmt_port=$splunk_mgmt_port,splunk_app_port=$splunk_app_port\n";
  `mkdir -p ${SPLUNK_HOME}/etc/apps/${servicename}/local`;
  my $WEBCONF="${SPLUNK_HOME}/etc/apps/${servicename}/local/web.conf";
  open(FH, '>', ${WEBCONF}) or die $!;
  $str= <<EOF;
[settings]
httpport = $splunk_web_port
mgmtHostPort = $splunk_mgmt_port
appServerPorts = $splunk_app_port

EOF
  print FH $str;
  close(FH);
  my $SERVERCONF="${SPLUNK_HOME}/etc/apps/${servicename}/local/server.conf";
  open(FH, '>', ${SERVERCONF}) or die $!;
  $str= <<EOF;
[kvstore]
port = $splunk_kvstore_port

EOF
  print FH $str;
  close(FH);
  print ("initializing server.conf with ${servicename}\nDo NOT modify server.conf in system/local as reinstalling would wipe it, please use apps\n");
  `echo "[general]" > ${SPLUNK_HOME}/etc/system/local/server.conf; echo "serverName = ${servicename}" >> ${SPLUNK_HOME}/etc/system/local/server.conf`;
  #  inputs.conf (so internal logs easier to find out which instance is doing what)
   if ( ! -e "${SPLUNK_HOME}/etc/system/local/inputs.conf" ) { 
      # Splunk was never started  
      print ("initializing inputs.conf with ${servicename}\n");
      `echo "[default]" > ${SPLUNK_HOME}/etc/system/local/inputs.conf`;
      `echo "host = ${servicename}" >> ${SPLUNK_HOME}/etc/system/local/inputs.conf`;
      `chown $USERSPLUNK. ${SPLUNK_HOME}/etc/system/local/inputs.conf`;
   } else {
      print "inputs already there, not recreating\n";
   }
  `chown -R $USERSPLUNK. $SPLUNK_HOME`;
  # register to lb $splunk_mgmt_port here

  my $VIPPORT=8089;
  my $IP=`ip route get 8.8.8.8 | head -1 | cut -d' ' -f7`;
  chomp($IP);
  print "adding to lvs for VIP $IP:$VIPPORT instance DS with IP=$IP and port=$splunk_mgmt_port\n";
  `ipvsadm --add-server -t $IP:$VIPPORT -r $IP:$splunk_mgmt_port -m; ipvsadm --save > /etc/sysconfig/ipvsadm`;
  my $SCRIPTS_DIR_ORIG=$SPLUNK_HOME_ORIG."/scripts";
  my $FIM=$SPLUNK_HOME_ORIG."/scripts/mgtport.txt";
  my $FIM2=$SPLUNK_HOME_ORIG."/scripts/mgtport.txt.old";
  print "adding mgmt port $splunk_mgmt_port to list in $FIM to be used for reloading config\n";
  if ( -e "$FIM" ) {
    print "renaming\n";
    `mv $FIM $FIM2`;
  }
  `mkdir -p $SCRIPTS_DIR_ORIG;chown $USERSPLUNK. $SCRIPTS_DIR_ORIG;cat $FIM2 | grep -v $splunk_mgmt_port > $FIM; echo $splunk_mgmt_port >> $FIM;chown $USERSPLUNK. $FIM`;
  # serverclass deployment app link
  # auto link for serverclass app (need to be named app_serverclass and contain local/serverclass.conf)
  if ( -e "$SPLUNK_HOME_ORIG/etc/deployment-apps/app_serverclass/local/serverclass.conf" ) {
    print "app app_serverclass already exist\n";
  } else {
    print "creating app_serverclass,  make sure to sync it in git repo if git used\n";
    `mkdir -p $SPLUNK_HOME_ORIG/etc/deployment-apps/app_serverclass/local`;
    `touch $SPLUNK_HOME_ORIG/etc/deployment-apps/app_serverclass/local/serverclass.conf`;
    `chown -R $USERSPLUNK. $SPLUNK_HOME`;
  }
  if ( -e "$SPLUNK_HOME/etc/apps/app_serverclass/local/serverclass.conf" ) {
    print "app_serverclass link already present in $SPLUNK_HOME/etc/apps, doing nothing\n";
  } else {
    print "creating app_serverclass link in $SPLUNK_HOME/etc/apps to point on deployment-apps\n";
    `cd $SPLUNK_HOME/etc/apps;ln -sv ../deployment-apps/app_serverclass`;
  }
  # potentially add link here for deploymentserver_base , output and license app instead of relying on initial apps but we dont known the app names upfront (need another option ?) 
}



my $VERSIONFULL=`chown -R $USERSPLUNK. $SPLUNK_HOME;su - $USERSPLUNK -c "$SPLSPLUNKBIN --version --accept-license --answer-yes --no-prompt| grep build | tail -1"`;
my $SPLVERSIONMAJ="0";
my $SPLVERSIONMIN="0";
my $SPLVERSIONMAINT="0";
my $SPLVERSIONEXTRA="0";

# examples
# Splunk 8.0.6 (build 152fb4b2bb96)
my $RES= $VERSIONFULL =~ /Splunk\s+(\d+)\.(\d+)\.(\d+)/;
if ($RES) {
  $SPLVERSIONMAJ=$1;
  $SPLVERSIONMIN=$2;
  $SPLVERSIONMAINT=$3;
} else {
  print " version detection via splunk command failed , may be because extra message during a upgrade, trying fallback methos via rpm version\n";
  $VERSIONFULL=`rpm -qi splunk | grep ^Version| tail -1"`;
# example
# Version     : 8.1.2
  $RES= $VERSIONFULL =~ /Version\s+:\s+(\d+)\.(\d+)\.(\d+)/;
  # note we force the regex to take the left part do if a extra number is present, it should mach the regex (exemple 8.1.1.1)
  if ($RES) {
    $SPLVERSIONMAJ=$1;
    $SPLVERSIONMIN=$2;
    $SPLVERSIONMAINT=$3;
  } else {
    print " version detection failed ! Please investigate, assuming 8.1.0 !\n";
    $SPLVERSIONMAJ=8;
    $SPLVERSIONMIN=1;
    $SPLVERSIONMAINT=0;
    $SPLVERSIONEXTRA="0";
  }
}
my $SPLVERSION="$SPLVERSIONMAJ.$SPLVERSIONMIN";

print "version full =$VERSIONFULL, major version = $SPLVERSIONMAJ, minor version = $SPLVERSIONMIN, maintenance version = $SPLVERSIONMAINT , extra version = $SPLVERSIONEXTRA, splversion = $SPLVERSION\n";

if ($enablesystemd==1 && $SPLVERSION < "7.3") {
    # let s fallback to init mode for these versions (7.2.2+ are compatible but not tested here and we are probably just in a upgrade process so wont stay in that version for ever
    print "system looks compatible but falling back in legacy mode for Splunk version under 7.3\n";
    $enablesystemd=0;
}  

if (-d $INITIALSPLAPPSDIR) {
   print "$INITIALSPLAPPSDIR directory is existing. Alls the apps in this directory will be copied initially to etc/apps directory. Please make sure you only copy the necessary apps and manage as needed via a central mechanism \n";
   `cp -rp $INITIALSPLAPPSDIR/* $SPLAPPSDIR/` unless ($dry_run); 
} else {
  print "$INITIALSPLAPPSDIR directory is not existing. No initial app will be copied\n";
}

# if splunkforwarder then it is normal to not create a admin account to reduce attack surface
if (-e $SPLPASSWDFILE) {
  print "OK: splunk pwd file exist (from backup or because upgrade)-> Existing passord, all good, no need to fetch user seed or generate one\n";
} elsif (-e $SPLUSERSEED) {
  print "OK: no existing password yet but splunk user seed file provided, will use this user seed file\n";
} elsif ($SPLUNK_SUBSYS eq "splunkforwarder") {
  print "OK: this is a splunkforwarder and user seed not provided, no need for admin user account on a splunk forwarder, that is fine\n";
} else {
  print "INFO: no user seed file provided and admin account need to be created\n";
  if ($cloud_type == 1) {
    print "INFO: running inside AWS\n";
    #if ($splunkpwdinit eq "no") {
    #  print "INFO : splunkpwd=no disabling pwd generation on this instance but we still may try to get a user seed\n";
    #} elsif (($cloud_type == 1) && $splunkpwdinit eq "yes") {
    #print "running in AWS with splunkpwdinit set and no passwd defined or provided by user-seed -> trying to get one or generate \n";
    $res="";
    $hash=""; 
    if ($splunkpwdinit eq "yes") {
      # pre generating new hash before checking AWS to reduce race condition risk 
      do {
        $gen++;
        $res=`openssl rand -base64 $length`;
        chomp($res);
        print "$res";
        $res =~ s/^([^=]+)[=]*$/$1/;
        print "$res";
        if (($res =~ /\d/) && ($res =~/[\\\/\+\-\,\.\%\$]+[=]*/)) {
          print "res looks ok, using generated value\n";
          $hash=`$SPLUNK_HOME/bin/splunk hash-passwd $res`;
          if ($hash =~ /^\$6\$/) {
            chomp($hash);
            print "ok hash $hash\n";
            $valid=1;
          }
         }
      } until ($valid==1 || $gen>=$maxgen );
      if ($valid==1) {
        print "pwd gen ok in $gen attempts\n";
      } else {
        print "pwd gen ko after $gen attempts. Impossible to generate a valid pwd, something is wrong, please check and correct os and splunk installation\n";
      }
    }
    my $ssmhash=`aws ssm get-parameter --name splunk-user-seed --query "Parameter.Value" --output text --region $region`;
    my $found=0;           
    if ($ssmhash) {
      chomp ($ssmhash);
      print "INFO : got existing hash $ssmhash via SSM, using this for user seed\n";
      $hash=$ssmhash;
      $newhash=0;
      $valid=0;
      $found=1;
    } elsif ( ($splunkpwdinit eq "yes") && ($valid == 1) ) {
      print "user seed not present via ssm iand splunkpwdinit set, seeding SSM and secrets manager with new password\n";
      print "writing hash=$hash to SSM param splunk-user-seed in region $region\n";
      my $ssmputres=`  aws ssm put-parameter --name splunk-user-seed --value '$hash' --type String  --region $region`;
      print "result of ssm put-parameters : $ssmputres\n";
      my $secres=`aws secretsmanager put-secret-value --secret-id $splunkpwdarn --secret-string '$res' --region $region`;
      print "result of secretsmanager put-secret-value : $secres\n";
      $found=1;
    } else {
      print "initial ssm get failed, waiting a bit for other instance with splunkpwdinit set to start and populate it\n";
      my $try=0;
      my $maxtry=10;
      do {
        $try++;
        $ssmhash=`aws ssm get-parameter --name splunk-user-seed --query "Parameter.Value" --output text --region $region`;
        if ($ssmhash) {
          chomp ($ssmhash);
          print "INFO : got existing hash $ssmhash via SSM, using this for user seed\n";
          $hash=$ssmhash;
          $newhash=0;
          $valid=0;
          $found=1;
        } else {
          print "waiting 10s before retrying (waiting for other potential instance) ($try/$maxtry)\n";
          sleep 10;
        }
      } until ($found==1 || $try>=$maxtry );
      if ($found == 0) {
        print "FAIL: ************* splunkpwdinit disabled and no other instance has generated a user seed, something is wrong, make sure you enable at least one instance with splunkpwdinit enabled\n";
        print "INFO: Your instance will not have pwd set, you may later configure by providing a user-seed.conf\n";
      }
    }
    if ($found == 1) {
      print "generating user-seed.conf file\n";
      open(FH, '>', ${SPLUSERSEED}) or die $!;
      $str= <<EOF;
# this file was generated by splunkconf-init
[user_info]
USERNAME = admin
HASHED_PASSWORD = $hash

EOF
      print "Writing to file $SPLUSERSEED with content \n $str\n";
      print FH $str;
      close(FH);
      `chown $USERSPLUNK. $SPLUSERSEED`;
    }
  # end if cloud type == AWS
  } elsif ($no_prompt) {
    print "this is a new installation of splunk. Please provide a user-seed.conf with the initial admin password as described in https://docs.splunk.com/Documentation/Splunk/latest/Admin/User-seedconf you should probably use splunk hash-passwd commend to generate directly the hashed version  \n";
    #die("") unless ($dry_run);
  } else { # we still havent one but we are interactive mode so we have a human who can answer our questions so we can generate user seed 
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
    $str = <<ENDING;
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
} # end else condition

# to be able to reread password obfuscated with splunk.secret,
#  we need to save and restore this file before splunk restart (or a new one would be created and all the password saved would not be readable by Splunk

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
print "Splunk user ${USERSPLUNK} \n";
print "Managed Secret ${MANAGEDSECRET}\n";
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
if ($enablesystemd==1  && $distritype eq "rh") {
  print "configuring with systemd for rh like distribution\n";
  $servicename="splunk" unless ($servicename);
  # install and restart as may be needed
  print "installing polkit if necessary\n";
  `yum install -y polkit`;
  my $POLKITRULE="/etc/polkit-1/rules.d/99-splunk.rules";
  my $POLKITHELPER="/usr/local/bin/polkit_splunk";
  if ($systemdpolkit eq "generated") {
     print "not creating inline polkit as generated asked\n";
  } else {
    print "inline polkit mode\n";
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
      my $strpolhelp= <<'EOF';
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
  } # generated or inline
  # depending on polkit version, it is necessary to restart the service to have it reread config files so let's do it
  print "restarting polkit\n";
  `sleep 1;systemctl restart polkit`;
} elsif ($enablesystemd==1  && $distritype eq "debian") {
# Attention , when / if debian change its mind and update to newer package the same version than rh case should be used as more granular
# this may come in debian 11 ? see https://salsa.debian.org/utopia-team/polkit/-/blob/master/debian/changelog 
# there doesnt seem to be a way to be more granular with policykit on debian at the moment (or please report it back)
# at least this will allow splunk restart from splunk to work which is assumed later in the script and other such as esinstall script
  print "configuring with systemd for debian like distribution\n";
  ##### ATTENTION : this is the official package but sometimes apt-get install cant find it -> not sure why , please verify (also we may have to restart the service to avoid rebooting)
  `apt-get install policykit-1`; 
  `mkdir -p /etc/polkit-1/localauthority/50-local.d`;
  my $POLKITRULE="/etc/polkit-1/localauthority/50-local.d/splunk-manage-units.pkla";
  if ($systemdpolkit == "generated") {
     print "not creating inline polkit as generated asked\n";
  } else {
    unless (-e ${POLKITRULE} ) {
      print ("debian polkit file file hasn't been copied by you before starting splunk first time. Trying to fix with inline version \n");
      open(FH, '>', ${POLKITRULE}) or die $!;
      my $strpol= <<EOF;
[Allow users to manage services]
Identity=unix-group:splunk
Action=org.freedesktop.systemd1.manage-units
ResultActive=yes
EOF
    print FH $strpol;
    close(FH);
    `chown root. ${POLKITRULE}; chmod 444 ${POLKITRULE}`;

    } # exist polkit
  } # generated or inline
} elsif ($enablesystemd==0  && $distritype eq "rh") {
  print "systemd support disabled and RH -> RH6/AWS1 like -> ok (but deprecated)\n";
} else {
  die "logic error or unsupported distribution, please investigate (enablesystemd=$enablesystemd distritype=$distritype \n";  
}

if ($enablesystemd==1 && !$disablewlm) {
  #we are in systemd mode with polkit -> we are enabling WLM 
  # for the moment , we deployed consistently in system local
  # if you want to deploy it via a app, remove the system local (see doc, dont mix files here)
  my $WLMCONF="${SPLUNK_HOME}/etc/system/local/workload_pools.conf";
  open(FH, '>', ${WLMCONF}) or die $!;
  my $wlmconf= <<'EOF';
[general]
enabled = true
default_pool = standard_perf
ingest_pool = ingest
workload_pool_base_dir_name = splunk

[workload_category:search]
cpu_weight = 65
# mem_weight = 55
mem_weight = 100

[workload_category:ingest]
cpu_weight = 20
mem_weight = 100

[workload_category:misc]
cpu_weight = 15
# mem_weight = 40
mem_weight = 100

[workload_pool:standard_perf]
cpu_weight = 35
mem_weight = 100
category = search
default_category_pool = 1

[workload_pool:ingest]
cpu_weight = 100
mem_weight = 100
category = ingest
default_category_pool = 1

[workload_pool:misc]
cpu_weight = 100
mem_weight = 100
category = misc
default_category_pool = 1

[workload_pool:high_perf]
cpu_weight = 60
mem_weight = 100
category = search
default_category_pool = 0

[workload_pool:limited_perf]
cpu_weight = 5
mem_weight = 100
category = search
default_category_pool = 0

EOF
  print FH $wlmconf;
  close(FH);
  `/bin/chown $USERSPLUNK. ${WLMCONF}`;
} elsif ($enablesystemd==1 ) {
  print "systemd but disablewlm was set -> not setting wlm\n";
}


if ($enablesystemd==1 ) {
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
  if ($systemdpolkit eq "generated") {
    print "enabling boot-start via $SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK -group $GROUPSPLUNK -systemd-managed 1 -systemd-unit-file-name $servicename -create-polkit-rules 1\n";
    `$SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK -group $GROUPSPLUNK -systemd-managed 1 -systemd-unit-file-name $servicename -create-polkit-rules 1`;
  } else {
    print "enabling boot-start via $SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK  -group $GROUPSPLUNK -systemd-managed 1 -systemd-unit-file-name $servicename\n";
    `$SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK  -group $GROUPSPLUNK -systemd-managed 1 -systemd-unit-file-name $servicename`;
  }
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
      print "Reusing Systemd Memory limit we got from default service file MemoryLimit=$systemdmemlimit\n";
    }
    my $str;
    open(FH, '>', $filenameservice) or die $!; 
    if ($SPLVERSION < "8.1") {
      print "using systemd unit file for version pre 8.1 (using execstartpre, no execstartpost)";
      $str= <<EOF;
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
Group=$GROUPSPLUNK
Delegate=true
CPUShares=1024
MemoryLimit=$systemdmemlimit
PermissionsStartOnly=true
# change needed for 8.0+ to change the permissions before Splunk is started (see answers 781532 )
ExecStartPre=/bin/bash -c "chown -R $USERSPLUNK:$GROUPSPLUNK /sys/fs/cgroup/cpu/system.slice/%n;chown -R $USERSPLUNK:$GROUPSPLUNK /sys/fs/cgroup/memory/system.slice/%n"
## Modifications to the base Splunkd.service that is created from the "enable boot-start" command ##
# set additional ulimits:
LimitNPROC=262143
LimitFSIZE=infinity
LimitCORE=infinity
# Have splunk if just starting after an upgrade or for the first time accept the license and answer yes to the migration
#ExecStartPre=/bin/bash -c '/usr/bin/su - $USERSPLUNK -s /bin/bash -c \'$SPLUNK_HOME/bin/splunk status --accept-license --answer-yes --no-prompt\';true'
ExecStartPre=/bin/bash -c "/usr/bin/su - $USERSPLUNK -s /bin/bash -c \'$SPLUNK_HOME/bin/splunk status --accept-license --answer-yes --no-prompt\'";true
# wait to avoid restarting too fast
RestartSec=5s

[Install]
WantedBy=multi-user.target


EOF
    } else { # version is at least 8.1
      print "using systemd unit file for version 8.1+ (using execstartpost, no execstartpre)";
      $str= <<EOF;
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
Group=$GROUPSPLUNK
Delegate=true
CPUShares=1024
MemoryLimit=$systemdmemlimit
PermissionsStartOnly=true
# for 8.1, that is now back to ExecStartPost 
ExecStartPost=/bin/bash -c "chown -R $USERSPLUNK:$GROUPSPLUNK /sys/fs/cgroup/cpu/system.slice/%n;chown -R $USERSPLUNK:$GROUPSPLUNK /sys/fs/cgroup/memory/system.slice/%n"
## Modifications to the base Splunkd.service that is created from the "enable boot-start" command ##
# set additional ulimits:
LimitNPROC=262143
LimitFSIZE=infinity
LimitCORE=infinity
# Have splunk if just starting after an upgrade or for the first time accept the license and answer yes to the migration
#ExecStartPre=/bin/bash -c '/usr/bin/su - $USERSPLUNK -s /bin/bash -c \'$SPLUNK_HOME/bin/splunk status --accept-license --answer-yes --no-prompt\';true'
ExecStartPre=/bin/bash -c "/usr/bin/su - $USERSPLUNK -s /bin/bash -c \'$SPLUNK_HOME/bin/splunk status --accept-license --answer-yes --no-prompt\'";true
# wait to avoid restarting too fast
RestartSec=5s

[Install]
WantedBy=multi-user.target


EOF
    } # if version<8,1 else ...
    print FH $str;
    close(FH);
    # remove exec as not needed and may create warning by systemd
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
  if ($SPLVERSION < "7.2") {
    # note this is really 7.2.2+
    print "falling back in legacy mode, splunk doesnt have yet a systemd option\n";
    `$SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK `;
  } else {  
    `$SPLUNK_HOME/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user $USERSPLUNK -systemd-managed 0 `;
  }
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
    if ($systemctlexist) {
      print "telling systemd the unit file may have changed\n";
      `systemctl daemon-reload`;
      print "telling systemd the service is enabled";
      `systemctl enable $servicename`;
      print "telling systemd to start the service";
      `systemctl restart $servicename`;
    } else {
      # 
      print "systemctl not present, please check if service is correctly set to initialize\n";
    }
  } # inittemplatemode
  # change var inside the su as the shell script wont pass the variable when switching user
  #`sed -i '' 's/$\{SPLUNK_HOME\}/$SPLUNK_HOME/g' /etc/init.d/$SPLUNK_SUBSYS`;
  # check here -> we may need extra system command to make sure service is enabled for splunkforwarder case
  if ($systemctlexist) {
    print "telling systemd the unit file may have changed\n";
    `systemctl daemon-reload`;
  }
  print "waiting 10s....\n";
  # time to let splunk initialize correctly
  sleep(10);
  print "restarting splunk to make distributed functions operationnal (Please wait for restart to complete)\n";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk restart --no-prompt " `;
  print "waiting 10s....\n";
  # time to let splunk initialize correctly
  sleep(10);
}

if ($SPLVERSION < "7.1") {
  print "Splunk version is below 7.1, default admin account is admin changeme which will prevent working correctly in disrtributed mode, lets change the password the old way !\n";
  print "Attention ! You may need to change password to a more secure one \n";
  # for 7.1+, this has been moved to user-seed
  # change password by default , required for distributed search to work
  # legacy here
  my $SPLUNKPWD="changed123,";
  `$SUBIN - $USERSPLUNK -c "$SPLUNK_HOME/bin/splunk edit user admin -password '$SPLUNKPWD' -role admin --no-prompt -auth admin:changeme"`;

}
# splunk should now have started and move user-seed to passwd. If the file doesn't exist and we are not on a splunkforwarder we have a problem...
unless ($SPLPASSWDFILE || $SPLUNK_SUBSYS=="splunkforwarder") {
    die("problem : admin password not set after restart. user-seed.conf may have been invalid");
}


if ($splunkrole =~/ds|deployment/ ) {
  # Note this tuning require that the system tuning was deployed as the kernel tcp/ip limits needs to be over !
  my $SPLUNKLAUNCHCONF="${SPLUNK_HOME}/etc/splunk-launch.conf";
  if ( -e $SPLUNKLAUNCHCONF) {
    # removing stanza if exist then readding
    print "Tuning SPLUNK_LISTEN_BACKLOG to 2048 for DS in etc/splunk-launch.conf (need to be done after first start)\n";
    ` grep -v SPLUNK_LISTEN_BACKLOG $SPLUNKLAUNCHCONF > /tmp/SPLUNKLAUNCHCONF;cp /tmp/SPLUNKLAUNCHCONF $SPLUNKLAUNCHCONF; echo "SPLUNK_LISTEN_BACKLOG = 2048" >> $SPLUNKLAUNCHCONF`;
    print "telling systemd to restart the $servicename service via systemctl restart $servicename in order for tuning to be applied\n";
    `systemctl restart $servicename`;
  } else {
    print "WARNING ! Something is wrong ! splunk-launch.conf not yet created at $SPLUNKLAUNCHCONF, not applying tuning yet\n";
  }
}

#print "remove password change on UI\n";
# remove password change request on UI
`$SUBIN - $USERSPLUNK -c "/bin/touch ${SPLUNK_HOME}/etc/.ui_login || /usr/bin/touch ${SPLUNK_HOME}/etc/.ui_login" `;


print "end of installation script\n";
#  



