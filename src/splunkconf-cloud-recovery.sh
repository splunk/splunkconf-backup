#!/bin/bash -x 
exec >> /var/log/splunkconf-cloud-recovery-debug.log 2>&1

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
# This script is used either :
#   - after cloud user-data launched by AWS S3 autoscaling to setup the OS , dowwnload and restore files to prepare for Splunk isntallation upgrade
#   - on a running instance to perform a upgrade (same thing but the OS partition are expected to be there and the reboot is not done as we havent updated the system)

# this script is expecting that :
# instances tags were configured and already written to /etc/instance-tags by user-data
# 
# this script is :
# - creating the splunk user (unless existing)
# - setting up the os partitions for splunk
# - downloading and setting up tuning for Splunk (ulimits, THP, TCP/IP and kernel + systemd / policykit integration for running splunk in systemd mode) 
# - downloading and restoring conf backups (for kvdump, copying the file that will be autonatically restored inside splunk by splunkconf-backup)
# - downloading and install splunk via rpm
# - setting up Splunk service (accept license, enable boot start, upgrade if necessary)
# - rebooting at the end as this is needed if we are in install mode and just updated the system

# 20180626 init and merge back things from Ivan version
# 20181127 add debug log
# 20190314 fixes and more things
# 20190326 change modinput to state to match newer splunkconf backup scripts naming convention
# 20190326 add call to script /opt/splunk/scripts/aws_dns_update/dns_update.sh if it exist (downloaded as part of the backup) which can be useful for updating for example cluster master entry in aws dns
# 20190912 update and more var
# 20190913 generalize post install hook to have it directly from s3
# 20190914 update disk init for newer linu
# 20190915 update script name, comments, glue for init, improve fixed hostname for first time installx
# 20190918 move all splunk init to splunkconf-init
# 20190925 fix permission order for indexes dir 
# 20190927 uniformize -> to var/backups not var/backup, helper script changed to root script dir, more comments, update splunk version to 7.3.1.1
# 20190928 legerage new user data that create /etc/ec2-tags containing s3 bucket names and instance type
# 20190929 add explicit polkit deployment for aws2 ami case
# 20191001 move partition for indx after ec2 tags + cleanuo 
# 20191001 add tuned installation for aws2 case (to be more rh like)
# 20200203 change order to better work by default when upgrading at same time (minor version for example) (better to use backup then upgrade so that will update a file if in conflict between backup and product as it is owned by product) (that avoid having to list all the product files and maintain the exclusion list) + prefer to use the kvdump as there are more chance that this is valid (and take less space !) 
# 20200413 add curl package installation just in case (should be present in most os installation), move logs to usual system dir, add protection mechanism to avoid breaking big kvdump restore that would start in //
# 20200414 fix typo and add extra dir creation for user seed copy 
# 20200416 add support for post launch mode to be able to deploy partially splunk on ephemeral
# 20200503 add exclusion to avoid overriding this script with older version from backup, add extra test and copy for sessions.py (8.0 specific)
# 20200512 disable backup restore test for idx case
# 20200617 add description and improve logs, add var for VERSION, add ugrade mode (that is not requiring destroying the instance and recreating), integrate getting tags so that it run in upgrade mode also
# 20200618 change disk creation code for imdsv2 + ephemeral or EBS (1 type)
# 20200618 readd indexes dir creation and permissions
# 20200623 add lvm package installation when missing in image , add exclusion for case where script is deployed in /usr/local/bin
# 20200623 add support for tags with splunk prefix (with legacy mode if the filter is removed) and filter on prefix for instance tags file creation, move splunk home to ephemeral for i3+smarstore scenario
# 20200624 add detection logic for tags with or without prefix tag to ease migration scenarios, disable bash e flag 
# 20200624 integrate and generalize AZ detection logic to build site app for indexers
# 20200625 add initialtlsapps to package dir to ease initial tls deployment 
# 20200626 add aws-terminate systemd service helper to optimize indexer scale down events
# 20200629 prioritize custom certs from s3 over ones in backup to ease upgrade scenarios
# 20200720 add support for one disk instance (not recommended for vol management but can be useful for lab)
# 20200911 change default version to 8.0.6
# 20200925 add deployment of upgrade-local script for install mode only
# 20200927 add logic to detect RH6 versus RH7+ and apply different tuning system dymamically (by having both packages on S3 with fallback mechanism to not break previous package name   
# 20200927 fix splunk prefix tag detection, add splunktargetbinary tag usage
# 20200929 add tuned service start for AWS2 case
# 20201006 deploy splunkconfbackup from s3 (needed for upgrade case) and remove old cron version if present to prevent double run + update autonatically master_uri to splunk-cm.awsdnszone 
# 20201007 various fixes + add --no-prompt when calling splunkconf-init
# 20201009 optimize restore detection logging 
# 20201010 add splunksecrets deployment via pip, add more cases and safeguards for splunkconf-backup deployment in a existing env
# 20201011 extend master_uri to use tag + also ds + targetsplunkenv + optionnally run a specific env script (used for disabling stuff (mails, external ticketing,...) in a test env for example )
# 20201011 rename error log file to debug
# 20201011 add gdb package for making sure pstack is there (in case support ask for it)
# 20201011 add check for root user (only useful when manually launched)
# 20201012 remove accidental whitespaces from tags at fetch time (for example prevent fail upgrade because the rpm check would fail) (copy/paste...)
# 20201015 add special case for giving dir to splunk for indexer creation case (when fs created in AMI)
# 20201017 add master_uri (cm) support for idx discovery + lm support 
# 20201022 add support for using extra splunkconf-swapme.pl to tune swap
# 20201102 set permission for local upgrade script, add copy for extra check and set tags, update to 8.0.7 by default
# 20201103 add download ES from s3 pre install script
# 20201106 remove any extra spaces in tags around the = sign
# 20201106 make master_uri form more restrictive in server.conf
# 20201109 yet another fix for master_uri regex
# 20201110 remove sessions.py test , move es prep script outside test to have it downloaded in all cases
# 20201110 fix typo in splunktargetenv support 
# 20201111 add java openjdk 1.8 installation (needed for dbconnect for example)
# 20210120 disable default master_uri replacement without tags
# 20210125 change aws to cloud + initial gcp detection
# 20210125 add GPG key check for RPM + direct download option in case RPM not in install bucket
# 20210125 move aws s3 cp to a function and add GCP support
# 20210125 change logging to not clean file at launch + add first boot check (needed for GCP which launch the script at every boot)
# 20210126 add support for setting hostname at boot for gcp, add tests and more meaningfull messages when missing backups or initial files 
# 20210127 add zone detection support for GCP
# 20210127 add dns update support for GCP dns zones (need a splunkdnszoneid tag)
# 20210128 extend ephemeral support to GCP local ssd
# 20210131 inline splunk aws terminate to ease packaging
# 20210131 fix yum option that allow installing on missing rpm (to allow // install in general but still work when the rpm doesnt exist on sone os)
# 20210131 add test to only deploy terminate on systemd os 
# 20210202 splunk 8.1.2
# 20210216 add group + restore permissions on /usr/local/bin for indexer systemd terminate service 
# 20210409 splunk 8.1.3
# 20210526 splunk 8.1.4 as default + add 8.2.0 (not yet default)
# 20210526 add tar mode splbinary detection with logic to setup multiple instances in ds mode via splunkconf-init
# 20210527 add ds lb script deployment
# 20210531 move os detection + change system hostname to functions called at beginning then include route53 update for aws case to be inlined at beginning to avoid having to push extra script and speed up update (+remove some commented line fromn get_object conversion)
# 20210531 more get_object comment clean up and fixes for route53 inline
# 20210608 add splunkorg option to splunkconf-init call
# 20210614 add splunk-appinspect installation for multids
# 20210627 add check and stop when not yum as not currently fully implemented otherwise
# 20210627 add splunkconnectedmode tag + initial detection logic
# 20210627 add splunkosupdatemode tag
# 20210627 add rpm for 8.2.1 (no change to default)
# 20210707 fix regression in splunkconf-backup du to splunkbase packaging change
# 20210707 add splunkcloudmode support to ease deploying collection layer to splunkcloud or test instance that index to splunkcloud
# 20210719 up default to 8.1.5 
# 20210902 add splunkinstancesnb tag support (multids only)
# 20210906 up default to 8.2.2
# 20210907 add splunkcloudmode for gcp case
# 20211017 add more tag support to be able to use various splunkconf-init options from recovery, add initial support for custom user/group in the recovery part
# 20211021 more tag support
# 20211120 fix typo and add more error checking for multids script presence
# 20220102 fix cloud detection for newer AWS kernels
# 20220112 fix tag renaming support when splunkdnszone used (and add DEPRECATED warning to the old splunkawsdnszone )
# 20220112 increase token validity for aws metadata 
# 20220121 disable ami hotpatch not needed for splunk
# 20220129 deploy splunkconf-ds-reload.sh for ds instances type
# 20220129 add fake structure for multids to make splunkconf-backup happy
# 20220203 add splunkmode tag to ease uf detection (ie when to deploy uf instead of full enterprise)
# 20220204 fix permissions for script dir when not the default path
# 20220206 disable auto swap with swapme  when splunkmode=uf as probably not worth it in that case
# 20220217 default to 8.2.5
# 20220316 add ability to use tar mode even if not multi ds (but better to use rpm when possible + add splunkdnsmode tag (disabled or lambda) to disable inline mode for AWS)
# 20220316 improve auto space removal in tags
# 20220325 add zstd binary install + change tar option to autodetect format + add error handling for zstd backup with no zstd binary case (initial support)
# 20220327 relax form for permission on initial backups for zstd to prevent false warning
# 20220327 add protection from very old splunkconf backup that would run by cron as we dont want a conflict
# 20220409 add autoresizing for splunk partition when created in AMI and not a idx
# 20220410 for upgrade set setting for kvstore engine upgrade
# 20220410 default to 8.2.6
# 20220420 Fix regression that would try deploy multids when singleds case by adding a constraint on tag set for it
# 20220421 add logic for splunkconnectedmode 
# 20220421 move disk logic to functions, add comments for block to make log faster to read
# 20220506 update regex to replace lm when tag set
# 20220507 include splunk untar here for non rpmn case and move lm tag management after binary to get btool working at this point
# 20220611 add condition test to prevent false warning in debug log + add explicit message when old splunkconf-backup in scripts found 
# 20220615 up to v9.0.0 by default
# 20220617 add detection for empty tag value for user and group to fallback to splunk values
# 20220704 move packagelist to var 
# 20220812 add auto initial deployment of ds and manager-apps if provided  
# 20220812 try to handle lm tag replacement for ds
# 20220813 add dir creation for ds and cm skeleton creation as splunk not yet started when we copy files into
# 20220813 change regex to require master_uri at beginning of line for lm
# 20220813 add tag replacement for s2 tag
# 20221014 up to 9.0.1
# 20221117 up to 9.0.2
# 20221117 update regex for bucketname tag s3 replacement to only replace the variable
# 20221123 update tag replacement logic for enabling ds tag replace to work indeoendently of cm tag
# 20221205 add support for splunkacceptlicense tag and pass it along to splunkconf-init
# 20230102 up to 9.0.3
# 20230104 change way of calling swapme to remove false error message
# 20230106 add more arguments to splunkconf-init so it knows it is running in cloud and new tag splunkpwdinit
# 20230108 add tag splunkpwdarn and transfer it to splunkconfi-init with region also 
# 20230108 fix order of tag inclusion and splunkconfinit option
# 20230111 change form logic to set hosts for hf and uf except when containing -farm
# 20230123 add splunkenableunifiedpartition var
# 20230214 add manager and ds initial apps support
# 20230215 move initial backup and install directory creation after FS to account for potential conflict with FS creation 
# 20230317 up to 9.0.4
# 20230328 adding more debug log to identify issue with restoring kvdump
# 20230328 add more logic to avoid conflict with potential old backups done with previous versions
# 20230328 changed loop syntax to try to solve kvdump restore issue
# 20030328 comment the global logic flag for recovery so the new fine grained variable win and work in mixed mode (will work better with the kvdump restore)
# 20230328 tune permission on restored backup files (before use)
# 20230328 fix variable init issue then revert additional logic and debug 
# 20230328 more cleanup and simplification, avoid duplicate code for scripts-initial
# 20230402 logic change for splunkpwdinit tag management with more options passed along to splunkconfinit in all cases for AWS and improved logging
# 20230402 typo fix for sed command for login content adaptation
# 20230402 fix dir creation for initial managerapps support
# 20230403 add default value false for splunkenableunifiedpartition when unset
# 20230403 more regex fix for login_content adaptation
# 20230414 add yum option to work around conflict with AMI AL2023 and curl-minimal package
# 20230416 add manager_uri form for cm tag replacement in addition to master_uri
# 20230416 add missing manager-apps for multi ds (for consistency)
# 20230416 add splunkconf-backup-etc-terminate-helper service
# 20230416 fix for previous update
# 20230417 remove master-apps untarring to prevent conflict with manager-apps
# 20230418 add cgroupv1 fallback for AL2023 so that WLM works 
# 20230419 adding logging on current cgroup mode
# 20230419 initial logic change to get ability to update and change cgroup at first boot in AWS
# 20230423 move all os update and cgroup to first boot logic, remove unused wait restoration code as no longer needed
# 20230423 add installphase variable
# 20230423 redo cgroup status and add needreboot logic
# 20230424 move init to a function and call it after param initiallization
# 20230427 add support fot tag splunk_smartstore_site_number so it possible to work with one instance without replication for hot data but still instance resiliency
# 20230508 rename splunk_smartstore_site_number to splunksmartstoresitenumber
# 20230521 add splunkenableworker tag
# 20230522 add more support for splunkenableworker tag
# 20230523 add ansible and boto3 install via pip for worker (as not yet via RPM for AL2023)
# 20230523 update boto3 deployment logic
# 20230529 convert to loop for worker deployment file and add one more file
# 20230530 up to 9.0.4.1
# 20230530 add ansible build inventory
# 20230603 up to 9.0.5
# 20230606 add ansible_deploysplunkansible_tf.yml to worker
# 20230606 and launch it automatically 
# 20230607 split ansible template deployment for worker
# 20230629 add more logging and extra check for not rebooting in upgrade mode
# 20230629 more logging, use intermediate var for nbarg
# 20230629 fix upgrade detection test
# 20230629 more manager_uri support and more tag replacement for idx discovery
# 20230629 up to 9.1.0 
# 20230701 add splunkrsyncmode tag to enable test rsync mode
# 20230701 change hf to not be farm by default 
# 20230707 up to 9.1.0.1
# 20230822 up to 9.1.0.2
# 20231025 autodisable ssg on idx to cleanup logging
# 20231108 fix typo 
# 20231108 improve curl outputs 
# 20231111 fix missing dir creation for worker use case
# 20231111 fix incorrect arg for downloading playbook for worker use case + improve logging
# 20231112 fix path for worker splunk ansible 
# 20231117 up to 9.1.2
# 20231120 add variable splversion and splhash to reduce typo risk when updating version
# 20231206 add tag splunkhostmode and splunkhostmodeos
# 20231213 bug fix with sed command for servername replacement
# 20231215 more bug fix with sed command for servername replacement
# 20231215 disabling splunksecrets deployment as can now be done mostly via splunk command line
# 20240109 set deploymentclient so ds comm works when hostmode in ami mode
# 20230125 up to 9.1.3
# 20240213 typo fix in log
# 20240213 update name for old backup app before upgrade from s3 version
# 20240313 update to 9.2.0.1
# 20240410 add ssm agent deployment for centos stream9
# 20240415 add splunkpostextracommand to allow launching a command at the end of installation
# 20240415 add splunkpostextrasyncdir
# 20240422 set latest var for AL2023 
# 20240423 change update logic for AL2023 to run for second boot to prevent potential conflict with SSM
# 20240424 add condition logic for log4jhotfix as not needed for AL2023
# 20240526 changedefault user to splunkfwd when uf to prevent issue with SPLUNK_HOME incorreclty set by splunk at boot start
# 20240526 up to 9.2.1
# 20240526 fix for uf group support and add support for sending options to splunkconf-init
# 20240526 add detection for curl-minimal package to clean up output when this package is deploeyed (like AL2023) 
# 20240526 disable tag replacement for uf to clean up logs
# 20240526 try to prevent SSM and rpm conflict at start breaking install
# 20240526 add loop to workaround yun lock issue
# 20240526 add splunkrole option to splunkconf-init so uf role is known to splunkconf-init
# 20240527 add flags for dnf command for better handling via script
# 20240527 rework rpm GPG check error handling
# 20240527 add more checks to clean up logs especially in uf mode and fix for splunksecretsdeploymentenable logic
# 20240527 add also retry logic for rpm install
# 20240805 up to 9.3.0
# 20240805 add tag for cgroup mode hint and more cgroupv2 support
# 20240910 add var for arch and warn if arch mismatch
# 20240915 up to 9.3.1
# 20240917 add splunktargetbinary=sc4s logic
# 20242020 add splunkswapmemode tag to control swapme activation and mode

VERSION="20242020a"

# dont break script on error as we rely on tests for this
set +e

TODAY=`date '+%Y%m%d-%H%M_%u'`;
echo "${TODAY} running splunkconf-cloud-recovery.sh with ${VERSION} version" >> /var/log/splunkconf-cloud-recovery-info.log

METADATA_URL="http://metadata.google.internal/computeMetadata/v1"
function check_cloud() {
  cloud_type=0
  response=$(curl -fs -m 5 -H "Metadata-Flavor: Google" ${METADATA_URL})
  if [ $? -eq 0 ]; then
    echo 'GCP instance detected'
    cloud_type=2
  # old aws hypervisor
  elif [ -f /sys/hypervisor/uuid ]; then
    if [ `head -c 3 /sys/hypervisor/uuid` == "ec2" ]; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
  fi
  # newer aws hypervisor (test require root)
  if [ -r /sys/devices/virtual/dmi/id/product_uuid ]; then
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "EC2" ]; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
    if [ `head -c 3 /sys/devices/virtual/dmi/id/product_uuid` == "ec2" ]; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
  fi
  # if detection not yet successfull, try fallback method
  if [[ $cloud_type -eq "0" ]]; then 
    # Fallback check of http://169.254.169.254/. If we wanted to be REALLY
    # authoritative, we could follow Amazon's suggestions for cryptographically
    # verifying their signature, see here:
    #    https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-identity-documents.html
    # but this is almost certainly overkill for this purpose (and the above
    # checks of "EC2" prefixes have a higher false positive potential, anyway).
    #  imdsv2 support : TOKEN should exist if inside AWS even if not enforced   
    TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
    if [ -z ${TOKEN+x} ]; then
      # TOKEN NOT SET , NOT inside AWS
      cloud_type=0
    elif $(curl --silent -m 5 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep -q availabilityZone) ; then
      echo 'AWS instance detected'
      cloud_type=1
    fi
  fi
}

# we will use SYSVER to store version type (used for packagesystem and hostname setting for example)
function check_sysver() {
  SYSVER=6
  if ! command -v hostnamectl &> /dev/null
  then
    echo "hostnamectl command could not be found -> Assuming RH6/AWS1 like distribution" >> /var/log/splunkconf-cloud-recovery-info.log
    SYSVER=6
  else
    echo "hostnamectl command detected, assuming RH7+ like distribution" >> /var/log/splunkconf-cloud-recovery-info.log
    # note we treat RH8 like RH7 for the moment as systemd stuff that works for RH7 also work for RH8 
    SYSVER=7
  fi
}

function set_hostname() {
  if [[ "$splunkhostmodeos" == "ami" ]]; then
    echo "splunkhostmodeos=ami , not changing os hostname"
  # set the hostname except if this is auto or contain idx or generic name
  elif ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf-farm|uf-farm|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then 
    echo "specific instance name ${instancename}: changing hostname to ${hostinstancename} at system level"
    if [ $SYSVER -eq "6" ]; then
      echo "Using legacy method" >> /var/log/splunkconf-cloud-recovery-info.log
      # legacy ami type , rh6 like
      sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${hostinstancename}/g" /etc/sysconfig/network
      # dynamic change on top in case correct hostname is needed further down in this script 
      hostname ${hostinstancename}
      # we should call a command here to force hostname immediately as splunk commands are started after
    else     
      # new ami , rh7+,...
      echo "Using new hostnamectl method" >> /var/log/splunkconf-cloud-recovery-info.log
      hostnamectl set-hostname ${hostinstancename}
    fi
  else
    echo "indexer -> not changing os hostname"
  fi
}

get_object () {
  if [ $# == 2 ]; then
    # correct
    orig=$1
    dest=$2
    if [ $cloud_type == 2 ]; then 
      echo "using GCP version with orig=$orig and dest=$dest\n"
      gsutil -q cp $orig $dest
    else
      aws s3 cp $orig $dest --quiet
    fi
  else
    echo "number of arguments passed to get_object is incorrect ($# instead of 2)\n"
  fi
}

# splunkconnectedmode   (tag got from instance)
# 0 = auto (try to detect connectivity) (default if not set)
# 1 = connected (set it if auto fail and you think you are connected)
# 2 = yum only (may be via proxy or local repo if yum configured correctly)
# 3 = no connection, yum disabled

# why we need this -> cloud context may vary depending on various compliance requirements
# the full connected world -> easier 
set_connectedmode () {
  if [ -z ${splunkconnectedmode+x} ]; then
     # variable not set -> default is auto
     splunkconnectedmode=0
  fi
  # FIXME here add logic for auto detect 
  # for now assuming connected
  if [ $splunkconnectedmode == 0 ]; then
    echo "switching from auto to fully connected mode"
    splunkconnectedmode=1
  elif [ $splunkconnectedmode == 1 ]; then
    echo "splunkconnectmode was set to fully connected"
  elif [ $splunkconnectedmode == 2 ]; then
    echo "splunkconnectmode was set to download via package manager (ie yum,...) only"
  elif [ $splunkconnectedmode == 3 ]; then
    echo "splunkconnectmode was set to no connection. Assuming you have deployed all the requirement yourself"
  else
    echo "splunkconnectmode=${splunkconnectedmode} is not a expected value, falling back to fully connected"
    splunkconnectedmode=1
  fi
  echo "splunkconnectedmode=${splunkconnectedmode}"
}

get_packages () {
  if [ $splunkconnectedmode == 3 ]; then
    echo "not connected mode, package installation disabled. Would have done yum install --setopt=skip_missing_names_on_install=True ${PACKAGELIST} -y"
  else 
    # perl needed for swap (regex) and splunkconf-init.pl
    # openjdk not needed by recovery itself but for app that use java such as dbconnect , itsi...
    # wget used by recovery
    # curl to fetch files
    # gdb provide pstack which may be needed to collect things for Splunk support

    if ! command -v yum &> /dev/null
    then
      echo "FAIL yum command could not be found, not RH like distribution , not fully implemented/tested at the moment, stopping here " >> /var/log/splunkconf-cloud-recovery-info.log
      exit 1
    fi
    RESYUM=1
    COUNT=0
    # we need to repeat in case yum lock taken as it will fail then later on other failures will occur like not having polkit ....
    # unfortunately if ssm is installed something from ssm configured at start may try install software in // breaking us....
    until [[ $COUNT -gt 5 ]] || [[ $RESYUM -eq 0 ]]
    do
      # one yum command so yum can try to download and install in // which will improve recovery time
      yum install --setopt=skip_missing_names_on_install=True  ${PACKAGELIST}  -y --skip-broken
      RESYUM=$?
      ((COUNT++))
      if [[ $RESYUM -ne 0 ]]; then
        echo "yum lock issue, sleeping 5 seconds before next retry  ($COUNT/5)"
        sleep 5
      fi
    done
    if [ $(grep -ic PLATFORM_ID=\"platform:al2023\" /etc/os-release) -eq 1 ]; then
      echo "distribution whithout log4j hotfix, no need to try disabling it"
    else 
      # disable as scan in permanence and not needed for splunk
      echo "trying to disable log4j hotfix, as perf hirt and not needed for splunk"
      systemctl stop log4j-cve-2021-44228-hotpatch
      systemctl disable log4j-cve-2021-44228-hotpatch
    fi
    # we deploy SSM after the previous yum as some ssm action may immediately run after and try to do a rpm which would lock rpm and create conflict
    if [[ "cloud_type" -eq 1 ]]; then
      # AWS
      # FIXME : test if service already deployed 
      if [ 'grep PLATFORM_ID /etc/os-release | grep platform:el9' ]; then
        echo "RH9/Centos9 like, forcing AWS SSM install in connected mode"
        # see https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-centos-stream.html
        # could be replaced by region specific to avoid dependency on global s3
        yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      fi
    fi
  fi #splunkconnectedmode
}

setup_disk () {
    DEVNUM=1
    if [[ "$splunkenableunifiedpartition" == "true" ]]; then
      echo "Usimg unified partition mode"
      MOUNTPOINT="$SPLUNK_HOME"
    else
      echo "Using distinct partition mode"
      MOUNTPOINT="/data/vol1"
    fi

    # let try to find if we have ephemeral storage
    if [[ "cloud_type" -eq 2 ]]; then
      # gcp
      INSTANCELIST=`nvme list | grep "nvme_card" | cut -f 1 -d" "`
    else
      # aws
      INSTANCELIST=`nvme list | grep "Instance Storage" | cut -f 1 -d" "`
    fi
    echo "instance storage=$INSTANCELIST" >> /var/log/splunkconf-cloud-recovery-info.log

    if [ ${#INSTANCELIST} -lt 5 ]; then
      echo "instance storage not detected" >> /var/log/splunkconf-cloud-recovery-info.log
      INSTANCELIST=`nvme list | grep "Amazon Elastic Block Store" | cut -f 1 -d" "`
      OSDEVICE=$INSTANCELIST
      echo "OSDEVICE=${OSDEVICE}" >> /var/log/splunkconf-cloud-recovery-info.log
      NBDISK=0
      for e in ${OSDEVICE}; do
        echo "checking EBS volume $e" >> /var/log/splunkconf-cloud-recovery-info.log
        RES=`mount | grep $e `
        if [ -z "${RES}" ]; then
          echo "$e not found in mounted devices" >> /var/log/splunkconf-cloud-recovery-info.log

          pvcreate $e >> /var/log/splunkconf-cloud-recovery-info.log
          # extend or create vg
          echo "adding $e to vgsplunkstorage${DEVNUM} " >> /var/log/splunkconf-cloud-recovery-info.log
          vgextend vgsplunkstorage${DEVNUM} $e || vgcreate vgsplunkstorage${DEVNUM} $e >> /var/log/splunkconf-cloud-recovery-info.log
          LIST="$LIST $e"
          #pvdisplay
          ((NBDISK=NBDISK+1))
        else
          echo "$e is already mounted, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
        fi
      done
      echo "LIST=$LIST NBDISK=$NBDISK" >> /var/log/splunkconf-cloud-recovery-info.log
      if [ $NBDISK -gt 0 ]; then
        echo "we have $NBDISK disk(s) to configure" >> /var/log/splunkconf-cloud-recovery-info.log
        lvcreate --name lvsplunkstorage${DEVNUM} -l100%FREE vgsplunkstorage${DEVNUM} >> /var/log/splunkconf-cloud-recovery-info.log
        pvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
        vgdisplay >> /var/log/splunkconf-cloud-recovery-info.log
        lvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
        # note mkfs wont format if the FS is already mounted -> no need to check here
        mkfs.ext4 -L storage1 /dev/vgsplunkstorage1/lvsplunkstorage1 >> /var/log/splunkconf-cloud-recovery-info.log
        mkdir -p $MOUNTPOINT
        RES=`grep $MOUNTPOINT /etc/fstab`
        #echo " debug F=$RES."
        if [ -z "${RES}" ]; then
          #mount /dev/vgsplunkephemeral1/lvsplunkephemeral1 $MOUNTPOINT && mkdir -p $MOUNTPOINT/indexes
          echo "$MOUNTPOINT not found in /etc/fstab, adding it" >> /var/log/splunkconf-cloud-recovery-info.log
          echo "/dev/vgsplunkstorage${DEVNUM}//lvsplunkstorage${DEVNUM} $MOUNTPOINT ext4 defaults,nofail 0 2" >> /etc/fstab
          mount $MOUNTPOINT
        else
          echo "$MOUNTPOINT is already in /etc/fstab, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
        fi
      else
        echo "no EBS partition to configure" >> /var/log/splunkconf-cloud-recovery-info.log
      fi
      # Note : in case there is just one partition , this will create the dir so that splunk will run
      # for volume management to work in classic mode, it is better to use a distinct partition to not mix manage and unmanaged on the same partition
      echo "creating /data/vol1/indexes and giving to splunk user" >> /var/log/splunkconf-cloud-recovery-info.log
      mkdir -p $MOUNTPOINT/indexes
      chown -R ${usersplunk}. $MOUNTPOINT/indexes
    else
      echo "instance storage detected"
      #OSDEVICE=$(lsblk -o NAME -n | grep -v '[[:digit:]]' | sed "s/^sd/xvd/g")
      #OSDEVICE=$(lsblk -o NAME -n --nodeps | grep nvme)
      #pvdisplay
      OSDEVICE=$INSTANCELIST
      echo "OSDEVICE=${OSDEVICE}" >> /var/log/splunkconf-cloud-recovery-info.log
      for e in ${OSDEVICE}; do
        echo "creating physical volume $e" >> /var/log/splunkconf-cloud-recovery-info.log
        pvcreate $e >> /var/log/splunkconf-cloud-recovery-info.log
        # extend or create vg
        echo "adding $e to vgsplunkephemeral${DEVNUM}" >> /var/log/splunkconf-cloud-recovery-info.log
        vgextend vgsplunkephemeral${DEVNUM} $e || vgcreate vgsplunkephemeral${DEVNUM} $e >> /var/log/splunkconf-cloud-recovery-info.log
        LIST="$LIST $e"
        #pvdisplay
      done
      echo "LIST=$LIST" >> /var/log/splunkconf-cloud-recovery-info.log
      #vgcreate vgephemeral1 $LIST
      lvcreate --name lvsplunkephemeral${DEVNUM} -l100%FREE vgsplunkephemeral${DEVNUM} >> /var/log/splunkconf-cloud-recovery-info.log
      pvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
      vgdisplay >> /var/log/splunkconf-cloud-recovery-info.log
      lvdisplay >> /var/log/splunkconf-cloud-recovery-info.log
      # note mkfs wont format if the FS is already mounted -> no need to check here
      mkfs.ext4 -L ephemeral1 /dev/vgsplunkephemeral1/lvsplunkephemeral1  >> /var/log/splunkconf-cloud-recovery-info.log
      mkdir -p $MOUNTPOINT
      RES=`grep $MOUNTPOINT /etc/fstab`
      #echo " debug F=$RES."
      if [ -z "${RES}" ]; then
        #mount /dev/vgsplunkephemeral1/lvsplunkephemeral1 $MOUNTPOINT && mkdir -p $MOUNTPOINT/indexes
        echo "$MOUNTPOINT not found in /etc/fstab, adding it" >> /var/log/splunkconf-cloud-recovery-info.log
        echo "/dev/vgsplunkephemeral${DEVNUM}/lvsplunkephemeral${DEVNUM} $MOUNTPOINT ext4 defaults,nofail 0 2" >> /etc/fstab
        mount $MOUNTPOINT
        echo "creating $MOUNTPOINT/indexes and giving to splunk user" >> /var/log/splunkconf-cloud-recovery-info.log
        mkdir -p $MOUNTPOINT/indexes
        chown -R ${usersplunk}. $MOUNTPOINT/indexes
        if [[ $splunkenableunifiedpartition -eq "true" ]]; then
          echo "fusion partition, SPLUNK_HOME already in epehemeral, ok"
        else 
          echo "moving splunk home to ephemeral devices in /data/vol1/splunk (smartstore scenario)" >> /var/log/splunkconf-cloud-recovery-info.log
          (mv /opt/splunk /data/vol1/splunk;ln -s /data/vol1/splunk /opt/splunk;chown -R ${usersplunk}. /opt/splunk) || mkdir -p /data/vol1/splunk
          SPLUNK_HOME="/data/vol1/splunk"
        fi
      else
        echo "$MOUNTPOINT is already in /etc/fstab, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
      fi
    fi
    PARTITIONFAST="$MOUNTPOINT"
    # FS created in AMI, need to give them back to splunk user
    if [ -e "/data/hotwarm" ]; then
       chown -R ${usersplunk}. /data/hotwarm
       PARTITIONFAST="/data/hotwarm"
       # resize when size in AMI not the right one
       resize2fs /dev/xvda1
       resize2fs /dev/xvdb
    fi
    if [ -e "/data/cold" ]; then
       chown -R ${usersplunk}. /data/cold
    fi
}

extend_fs () {
    # for non idx where AMI was created with FS no matching what was created, try to extend the partition
    # without LVM
    # note it will print resize2fs help if not exist, that is fine
    # note if /opt/splunk exist we try it first
    echo "trying to extend /opt/splunk if created in AMI"
    mount |grep " /opt/splunk " |  cut -s -d" " -f 1 | xargs resize2fs
    echo "trying to extend / if created in AMI"
    mount |grep " / " |  cut -s -d" " -f 1 | xargs resize2fs
    # with LVM
    # now if the FS was created with LVM we need to do it via lvextend
    echo "trying to extend /opt/splunk via LVM if created in AMI"
    mount |grep " /opt/splunk " |  cut -s -d" " -f 1 | xargs lvextend --resizefs -l +100%FREE
    echo "trying to extend / via LVM if created in AMI"
    mount |grep " / " |  cut -s -d" " -f 1 | xargs lvextend --resizefs -l +100%FREE
}

tag_replacement () {
  if [ ! -z ${splunkdnszone+x} ]; then 
    # lm case 
    if [ -z ${splunktargetlm+x} ]; then
      echo "tag splunktargetlm not set, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
    elif [ "${splunkmode}" == "uf" ]; then
      echo "uf install, tag replacement not needed" >> /var/log/splunkconf-cloud-recovery-info.log
    else
      echo "tag splunktargetlm is set to $splunktargetlm and will be used as the short name for master_uri config under [license] in server.conf to ref the LM" >> /var/log/splunkconf-cloud-recovery-info.log
      echo "using splunkdnszone ${splunkdnszone} from instance tags [license] master_uri=${splunktargetlm}.${splunkdnszone}:8089 (lm name or a cname alias to it)  " >> /var/log/splunkconf-cloud-recovery-info.log
      ${SPLUNK_HOME}/bin/splunk btool server list license --debug | grep -v m/d | grep master_uri | cut -d" " -f 1 | head -1 |  xargs -L 1 sed -i -e "s%^master_uri.*=.*$%master_uri=https://${splunktargetlm}.${splunkdnszone}:8089%" 
      ${SPLUNK_HOME}/bin/splunk btool server list license --debug | grep -v m/d | grep manager_uri | cut -d" " -f 1 | head -1 |  xargs -L 1 sed -i -e "s%^manager_uri.*=.*$%manager_uri=https://${splunktargetlm}.${splunkdnszone}:8089%" 
      echo "trying also lm replacement for DS"  >> /var/log/splunkconf-cloud-recovery-info.log
      FILM="${SPLUNK_HOME}/etc/deployment-apps/${splunkorg}_full_license_slave/local/server.conf"
      if [ -e "$FILM" ]; then
        # note : no space allowed before master_uri
        sed -i -e 's%^master_uri.*=.*$%master_uri=https://${splunktargetlm}.${splunkdnszone}:8089%' ${FILM}
        sed -i -e 's%^manager_uri.*=.*$%manager_uri=https://${splunktargetlm}.${splunkdnszone}:8089%' ${FILM}
      else 
        echo "$FILM doesnt exist, not trying to replace master_uri or manager_uri for LM in deployment-apps"
      fi
    fi
    # s2 case (could be run on ds or cm probably)
    if [ "${splunkmode}" == "uf" ]; then
      echo "uf install, tag replacement for s2 not needed" >> /var/log/splunkconf-cloud-recovery-info.log
    elif [ ! -z ${splunks3databucket+x} ]; then
       echo "trying to replace path for smartstore with the one generated and that we got from tags"
       #find ${SPLUNK_HOME} -wholename "*s2_indexer_indexes/local/indexes.conf" -exec grep -l path {} \; -exec sed -i -e "s%^path.*=.*$%path=s3://${splunks3databucket}/smartstore%" {} \; 
       find ${SPLUNK_HOME} -wholename "*s2_indexer_indexes/local/indexes.conf" -exec grep -l path {} \; -exec sed -i -e "s%mybucketname%${splunks3databucket}%" {} \; 
    else
      echo "INFO : splunks3databucket not defined not doing any replacement (fine if just using collection layer)"
    fi
  fi
}

cgroup_status () {
  # in case we want to force to v2
  NEEDCGROUPV2ENABLED=0
  # in case we want to force to v1
  NEEDCGROUPDISABLED=0
  TEST1=$(stat -fc %T /sys/fs/cgroup/)
  if [ -e /sys/fs/cgroup/unified/ ]; then
    echo "identified cgroupsv2 with unified off, disabling unified was done (running in v1 compat mode) -> nothing to do for v1, need to reenable for v2"
    NEEDCGROUPV2ENABLED=1
    NEEDCGROUPDISABLED=0
  elif [ $TEST1 = "cgroup2fs" ]; then
    echo "identified cgroupv2 with unified on, nothing to do for v2, need disabling to go v1 compat"
    NEEDCGROUPV2ENABLED=0
    NEEDCGROUPDISABLED=1
  else
    echo "cgroupsv1, nothing to do (impossible to enable v2 with this kernel)"
  fi
}



force_cgroupv1 () {
  if [[ $NEEDCGROUPDISABLED == 1 ]]; then
    echo "Forcing cgroupv1 (need reboot) (needed for AL2023 at the moment)"
    grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
    NEEDREBOOT=1
  else
    echo "INFO : no need to disable cgroupsv2"
  fi
}

force_cgroupv2 () {
  if [[ $NEEDCGROUPV2ENABLED == 1 ]]; then
    echo "Forcing cgroupv2 compatibility mode (systemd.unified_cgroup_hierarchy=1) (need reboot) (needed for RH9/Centos 9/AL2023 and all newer distributions at the moment for v9.3+)"
    grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"
    NEEDREBOOT=1
  else
    echo "INFO : no need to enable cgroupsv2"
  fi
}

os_update() {
  echo "#************************************* OS UPDATES MANAGEMENT ********************************************************"
  if [ $(grep -ic PLATFORM_ID=\"platform:al2023\" /etc/os-release) -eq 1 ]; then
    # we are running AL2023, we want to use latest release all the time then leverage smart-restart to minimize reboot need
    # see https://docs.aws.amazon.com/linux/al2023/ug/managing-repos-os-updates.html
    echo latest | sudo tee /etc/dnf/vars/releasever
    dnf install --quiet -y smart-restart
  fi #AL2023
  if [ -z ${splunkosupdatemode+x} ]; then
    splunkosupdatemode="updateandreboot" 
  fi
  if [ "${splunkosupdatemode}" = "disabled" ]; then
    echo "os update disabled, not applying them here. Make sure you applied them already in the os image or use for testing"
  elif [[ $splunkconnectedmode == 3 ]]; then
    echo "Full disconnected mode ! Attention, I wont try to apply latest/updates fixes even if splunosupdatemode is not set to disabled -> incoherent settings"
  else 
    echo "applying latest os updates/security and bugfixes"
    yum update -y
    if [ "${splunkosupdatemode}" = "noreboot" ]; then
      echo "tag splunkosupdatemode set to no reboot"
      # we do not disable here as cgroups disabling may have asked for reboot
    elif [ $(grep -ic PLATFORM_ID=\"platform:al2023\" /etc/os-release) -eq 1 ]; then
       if [ -e "/run/smart-restart/reboot-hint-marker" ]; then 
          NEEDREBOOT=1
       else 
          echo "AL2023 and smart-restart or no update to apply, no need to reboot"
       fi
    else
       NEEDREBOOT=1
    fi
  fi
}



# This parse argument and handle logic to launch os update and cgroup
# then decide on second boot if needed
# this need to be done after parameters initialisation
# cgroup_status should have ran before
init_arg() {
  echo "INFO: in init_arg"
  # arguments : are we launched by user-data or in upgrade mode ?
  if [ $NBARG -eq 1 ]; then
    MODE=$ARG1
    echo "Your command line contains 1 argument mode=$MODE" >> /var/log/splunkconf-cloud-recovery-info.log
    if [ "$MODE" == "upgrade" ]; then 
      echo "INFO : upgrade mode" >> /var/log/splunkconf-cloud-recovery-info.log
    else
      echo "unknown parameter, ignoring" >> /var/log/splunkconf-cloud-recovery-info.log
      MODE="0"
    fi
  elif [ $NBARG -gt 1 ]; then
    echo "ERROR: Your command line contains too many ($#) arguments. Ignoring the extra data" >> /var/log/splunkconf-cloud-recovery-info.log
    MODE=$ARG1
    if [ "$MODE" == "upgrade" ]; then 
      echo "INFO: upgrade mode" >> /var/log/splunkconf-cloud-recovery-info.log
    else
      echo "INFO: unknown parameter, ignoring, assuming boot mode (user data)" >> /var/log/splunkconf-cloud-recovery-info.log
      MODE="0"
    fi
  else
    echo "INFO: No arguments given, assuming launched by user data" >> /var/log/splunkconf-cloud-recovery-info.log
    MODE="0"
  fi

  echo "INFO: running $0 version=$VERSION with MODE=${MODE}" >> /var/log/splunkconf-cloud-recovery-info.log

  INSTALLPHASE=1
  # 1 update/cgroup only
  # 2 normal install
  # 3 exit mode

  # in user data mode, updates and cgroupv1 handling
  if [[ "$MODE" == 0 ]]; then
    echo "INFO: user-data mode"
    SECONDSTART="/var/lib/cloud/scripts/per-boot/splunkconf-secondstart.sh"
    # check by provider as it is different
    if [[ $cloud_type == 1 ]]; then
      # AWS
      if [ -e "/root/second_boot.check" ]; then 
        echo "ERROR : we are launched a 3rd time, which is not supposed to happen, please investigate"
        echo "INFO: second boot already ran, exiting to prevent boot loop (AWS)"
        if [ -e "${SECONDSTART}" ]; then 
          rm ${SECONDSTART}
        fi
        INSTALLPHASE=3
        exit 1
      elif [ -e "/root/first_boot.check" ]; then 
        echo "INFO: First boot already ran, going to normal install mode (AWS)"
        if [ -e "${SECONDSTART}" ]; then 
          rm ${SECONDSTART}
        fi
        touch "/root/second_boot.check"
        INSTALLPHASE=2
        if [ $(grep -ic PLATFORM_ID=\"platform:al2023\" /etc/os-release) -eq 1 ]; then
          # we run update at first step on all distrib except AL2023 as we try to do a fast first run for cgroup then do the update after without rebootin
          os_update
        fi
      else
        echo "INFO: This is First boot, setting up logic for second boot (AWS)"
        INSTALLPHASE=1
        if [ -e "${SECONDSTART}" ]; then 
          rm ${SECONDSTART}
        fi
        cat <<EOF >> ${SECONDSTART}
#!/bin/bash -x 
exec >> /var/log/splunkconf-cloud-recovery-secondboot.log 2>&1
 
VERSION=$VERSION

echo "running splunkconf-secondboot.sh"
echo "renaming log to avoid loosing them"
mv /var/log/splunkconf-cloud-recovery-debug.log.1 /var/log/splunkconf-cloud-recovery-debug.log.2
mv /var/log/splunkconf-cloud-recovery-info.log.1 /var/log/splunkconf-cloud-recovery-info.log.2
mv /var/log/splunkconf-cloud-recovery-debug.log /var/log/splunkconf-cloud-recovery-debug.log.1
mv /var/log/splunkconf-cloud-recovery-info.log /var/log/splunkconf-cloud-recovery-info.log.1

/usr/local/bin/splunkconf-cloud-recovery.sh

echo "end of running splunkconf-secondboot.sh"
EOF
        #echo $INPUT > ${SECONDSTART}
        chmod a+x ${SECONDSTART}
      fi
    elif [[ $cloud_type == 2 ]]; then
      # GCP
      if [ -e "/root/second_boot.check" ]; then
        echo "INFO : we are launched a 3rd time, which is normal on GCP but then we are no longer in install mode"
        echo "INFO: second boot already ran, exiting (GCP)"
        INSTALLPHASE=3
      elif [ -e "/root/first_boot.check" ]; then
        echo "INFO: First boot already ran, going to normal install mode (GCP)"
        touch "/root/second_boot.check"
        INSTALLPHASE=2
      else
        INSTALLPHASE=1
        echo "This is first boot"
      fi
      # GCP after reboot if we already ran then we set hostname
      if [ -e "/etc/instance-tags" ]; then 
        . /etc/instance-tags
        instancename=$splunkinstanceType 
        echo "splunkinstanceType : instancename=${instancename}" >> /var/log/splunkconf-cloud-recovery-info.log
        set_hostname
      fi
      if [[ "${INSTALLPHASE}" == 3 ]]; then
        echo "GCP : exit ok"
        exit 0
      fi
    fi
    if [[ "${INSTALLPHASE}" == 1 ]]; then
      # common actions at first boot in user data mode
      echo "INFO: Doing first boot actions"
      touch "/root/first_boot.check"
      NEEDREBOOT=0
      if [ ! $(grep -ic PLATFORM_ID=\"platform:al2023\" /etc/os-release) -eq 1 ]; then
        # we run update at first step on all distrib except AL2023 as we try to do a fast first run for cgroup then do the update after without rebootin
        os_update
      fi
      # disabling if value = 3
      if (( splunkcgroupmode == 3 )); then
        echo "splunkcgroupmode=3 not changing cgroup mode as requested"
      elif (( splunkcgroupmode == 1 )); then
        echo "splunkcgroupmode=1 so trying to force cgroup v1 mode"
        force_cgroupv1
      elif (( splunkcgroupmode == 2 )); then
        echo "splunkcgroupmode=2 so trying to force cgroup v2 mode"
        force_cgroupv2
      else
        echo "splunkcgroupmode=0 , default mode is currently forcing v1"
        force_cgroupv1
      fi
      TODAY=`date '+%Y%m%d-%H%M_%u'`;
      if [[ $NEEDREBOOT = 0 ]]; then
        echo "no need to reboot, forcing setting to second_boot"
        if [ -e "${SECONDSTART}" ]; then 
          rm ${SECONDSTART}
        fi
      elif [ "$MODE" == "upgrade" ]; then 
        # not supposed to happen here
        echo "WARNING: reboot may be needed but in upgrade mode so not rebooting"
      else
        echo "INFO: reboot needed (MODE=$MODE)"
        echo "${TODAY} splunkconf-cloud-recovery.sh (version=${VERSION} ) end of script, initiating reboot via init 6 (needreboot set)" >> /var/log/splunkconf-cloud-recovery-info.log
        echo "#************************************* END with reboot ***************************************"
        init 6
        exit 0
      fi
    fi
  else
    echo "INFO: not in MODE=0 (MODE=$MODE)"
  fi  # MODE = 0 (user-data)

  echo "INFO: INSTALLPHASE=${INSTALLPHASE} (MODE=$MODE), end if init_arg" 

}

echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#*************************************  START  ********************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"
echo "#******************************************************************************************************"

# check that we are launched by root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: Exiting ! This recovery script need to be run as root !" 
   exit 1
fi

# storing arg now for later use
NBARG=$#
ARG1=$1


check_cloud
check_sysver
cgroup_status

echo "cloud_type=$cloud_type, sysver=$SYSVER"

# setting variables

# disabling splunksecrets deployment as can now be done mostly via splunk command line  
splunksecretsdeploymentenable=0


INSTANCEFILE="/etc/instance-tags"

if [[ "cloud_type" -eq 1 ]]; then
  # aws
  # we get most var dynamically from ec2 tags associated to instance

  # getting tokens and writting to /etc/instance-tags

  # setting up token (IMDSv2)
  TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
  # lets get the s3splunkinstall from instance tags
  INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
  REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `

  # we put store tags in /etc/instance-tags -> we will use this later on
  aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/'   | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' | grep -E "^splunk" > $INSTANCEFILE
  if grep -qi splunkinstanceType $INSTANCEFILE
  then
    # note : filtering by splunk prefix allow to avoid import extra customers tags that could impact scripts
    echo "filtering tags with splunk prefix for instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "splunk prefixed tags not found, reverting to full tag inclusion" >> /var/log/splunkconf-cloud-recovery-info.log
    aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text |sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]*=[[:space:]]*/=/' | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/'  > $INSTANCEFILE
  fi
elif [[ "cloud_type" -eq 2 ]]; then
  # GCP
  splunkinstanceType=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkinstanceType`
  if [ -z ${splunkinstanceType+x} ]; then
    echo "GCP : Missing splunkinstanceType in instance metadata"
  else 
    # > to overwrite any old file here (upgrade case)
    echo -e "splunkinstanceType=${splunkinstanceType}\n" > $INSTANCEFILE
  fi
  splunks3installbucket=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3installbucket`
  if [ -z ${splunks3installbucket+x} ]; then
    echo "GCP : Missing splunks3installbucket in instance metadata"
  else 
    echo -e "splunks3installbucket=${splunks3installbucket}\n" >> $INSTANCEFILE
  fi
  splunks3backupbucket=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3backupbucket`
  if [ -z ${splunks3backupbucket+x} ]; then
    echo "GCP : Missing splunks3backupbucket in instance metadata"
  else 
    echo -e "splunks3backupbucket=${splunks3backupbucket}\n" >> $INSTANCEFILE
  fi
  splunks3databucket=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunks3databucket`
  if [ -z ${splunks3databucket+x} ]; then
    echo "GCP : Missing splunks3databucket in instance metadata"
  else 
    echo -e "splunks3databucket=${splunks3databucket}\n" >> $INSTANCEFILE
  fi
  splunkorg=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkorg`
  splunkdnszone=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnszone`
  splunkdnszoneid=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnszoneid`
  numericprojectid=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/project/numeric-project-id`
  projectid=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/project/project-id`
  splunkawsdnszone=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkawsdnszone`
  splunkcloudmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkcloudmode`
  splunkconnectedmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkconnectedmode`
  splunkosupdatemode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkosupdatemode`
  splunkdsnb=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdsnb`
  splunksystemd=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksystemd`
  splunksystemdservicefile=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksystemdservicefile`
  splunksystemdpolkit=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksystemdpolkit`
  splunkdisablewlm=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdisablewlm`
  splunkuser=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkuser`
  splunkgroup=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkgroup`
  splunkmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkmode`
  splunkdnsmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkdnsmode`
  splunkacceptlicense=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkacceptlicense`
  splunkpwdinit=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkpwdinit`
  splunkpwdarn=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkpwdarn`
  splunkenableunifiedpartition=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkenableunifiedpartition`
  splunksmartstoresitenumber=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunksmartstoresitenumber`
  splunkenableworker=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkenableworker`
  splunkrsyncmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkrsyncmode`
  splunkhostmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkhostmode`
  splunkhostmodeos=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkhostmodeos`
  splunkpostextracommand=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkpostextracommand`
  splunkpostextrasyncdir=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkpostextrasyncdir`
  splunkcgroupmode=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/splunkcgroupmode`
  #=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/attributes/`
  
fi

if [ -e "$INSTANCEFILE" ]; then
  chmod 644 $INSTANCEFILE
  # including the tags for use in this script
  . $INSTANCEFILE
else
  echo "WARNING : no instance tags file at $INSTANCEFILE"
fi


# additional options to splunkconf-init
# default to empty
# if we receive a tag with a non default value, we add it incremetaly to this variable 
# this allow not to call splunkinit will all the options set 
SPLUNKINITOPTIONS=""

if [ -z ${splunksystemd+x} ]; then 
  echo "splunksystemd is unset, falling back to default value of auto"
  splunksystemd="auto"
elif [ "${splunksystemd}" == "systemd" ]; then 
  SPLUNKINITOPTIONS+=" --systemd=systemd"
elif [ "${splunksystemd}" == "init" ]; then
  SPLUNKINITOPTIONS+=" --systemd=init"
elif [ "${splunksystemd}" == "auto" ]; then
  echo "systemd tag set to auto -> default"
else
  echo "unsupported/unknown value for splunksystemd:${splunksystemd} , falling back to default"
fi

if [ -z ${splunkenableunifiedpartition+x} ]; then 
  echo "splunkenableunifiedpartition is unset, falling back to default value false"
  splunkenableunifiedpartition="false"
fi

# splunkhostmodeos 
# set mode if we set hostname at system level
# set (default)  : we will change hostname 
# vanilla or ami : let ami set it

# splunkhostmode
# how we adapt host on splunk side 
# instance (default)  : we set it from splunkinstancetype
# prefix : we build a value with splunkinstancetype and os host 
# os : we set it from os host name
# in all cases, it will also depend if there is a backup used for this instance type, values from backup will override this

if [ -z ${splunkhostmodeos+x} ]; then 
  echo "splunkhostmodeos is unset, falling back to default value ami"
  splunkhostmodeos="ami"
elif [ "${splunkhostmodeos}" == "set" ]; then
  echo "splunkhostmodeos=set, using default mode"
elif [ "${splunkhostmodeos}" == "vanilla" ] || [ "${splunkhostmodeos}" == "os" ] || [ "${splunkhostmodeos}" == "ami" ]; then
  echo "splunkhostmodeos=${splunkhostmodeos}, letting AMI decide"
  splunkhostmodeos="ami"
else 
  echo "ATTENTION : invalid value splunkhostmodeos=${splunkhostmodeos}, falling back to set" 
  splunkhostmodeos="set"
fi
  
if [ -z ${splunkcgroupmode+x} ]; then 
  echo "splunkcgroupmode is unset, falling back to default value 0 (auto)"
  splunkcgroupmode=0
elif (( splunkcgroupmode == 0 )) || (( splunkcgroupmode == 1 )) || (( splunkcgroupmode == 2 )) || (( splunkcgroupmode == 3 )); then
  echo "splunkcgroupmode=${splunkcgroupmode}"
else
  echo "invalid value splunkcgroupmode=${splunkcgroupmode} , forcing auto (ie 0 )"
  splunkcgroupmode=0
fi 

if [ -z ${splunkhostmode+x} ]; then 
  echo "splunkhostmode is unset, falling back to default value splunkinstancetype"
  splunkhostmode="splunkinstancetype"
elif [ "${splunkhostmode}" == "splunkinstancetype" ]; then
  echo "splunkhostmode=splunkinstancetype, using default mode"
elif [ "${splunkhostmode}" == "prefix" ]; then 
  echo "splunkhostmode=prefix, will use prefix mode ie start with the splunk name then use the initial host. This is useful for farm to both differentiate instances (for DC/DS and reporting) and having a easy form for serverclasses"
elif [ "${splunkhostmode}" == "os" ]; then
  echo "splunkhostmode=os, using what the os set (ie let splunk decide)"
else
  echo "ATTENTION : invalid value splunkhostmode=${splunkhostmode}, falling back to splunkinstancetype" 
  splunkhostmode="splunkinstancetype"
fi

if [ -z ${splunksmartstoresitenumber+x} ]; then 
  echo "splunksmartstoresitenumber is unset, falling back to default value 3"
  splunksmartstoresitenumber=3
fi

if [ -z ${splunkenableworker+x} ]; then 
  echo "splunkenableworker is unset, falling back to default value 0 (disabled)"
  splunkenableworker=0
fi

if [ -z ${splunkrsyncmode+x} ]; then 
  echo "splunkrsyncmode is unset, falling back to default value 0 (disabled)"
  splunkrsyncmode=0
fi

if [ -z ${splunkpostextrasyncdir+x} ]; then 
  echo "splunkpostextrasyncdir is unset"
else
  echo "splunkpostextrasyncdir is set to ${splunkpostextrasyncdir}"
fi

if [ -z ${splunkpostextracommand+x} ]; then 
  echo "splunkpostextracommand is unset"
else
  echo "splunkpostextracommand is set to ${splunkpostextracommand}"
fi

if [[ "${cloud_type}" -eq 1 ]]; then
  # AWS
  # tell splunkconfinit we are running in AWS 
  SPLUNKINITOPTIONS+=" --cloud_type=${cloud_type}"
  if [ -z ${REGION+x} ]; then
    echo "REGION is not set ! unexpected here , please fix";
  else
    SPLUNKINITOPTIONS+=" --region=$REGION" 
  fi
  if [ -z ${splunkpwdarn+x} ]; then
    echo "tag splunkpwdarn is not set ! Please add it if you use tag splunkpwdinit so we can update the secret or you will not be able to get the password !";
  else
    SPLUNKINITOPTIONS+=" --splunkpwdarn=$splunkpwdarn" 
  fi
  if [ "${splunkpwdinit}" == "yes" ]; then
    # tell splunkconfinit (in AWS context) that if user seed was not provided and pwd is not present from backup to create one and store it via AWS secrets
    echo "tag splunkpwdinit is set ! This instance is allowed to create a pwd if needed"
    SPLUNKINITOPTIONS+=" --splunkpwdinit=yes"
  else
    echo "splunkpwdinit tag not present, this instance wont be  allowed to create pwd itself so it shoudl already have it or another instance should have this tag set"
  fi
else
  echo "not adding cloud type option to splunkconf-init as not in AWS"
fi
  
if [ -z ${splunkswapmemode+x} ]; then 
  echo "splunkswapmemode not set , default to enabled if script present"
  splunkswapmemode=1
elif [ "${splunkswapmemode}" == "auto" ] || [ "${splunkswapmemode}" == "1" ] || [ "${splunkswapmemode}" == "yes" ]  || [ "${splunkswapmemode}" == "enabled"  ]; then 
  echo "splunkswapmemode enabled if script present"
  splunkswapmemode=1
elif [ "${splunkswapmemode}" == "0" ] || [ "${splunkswapmemode}" == "no" ] || [ "${splunkswapmemode}" == "disabled" ]; then 
  echo "splunkswapmemode disabled by tag"
  splunkswapmemode=0
else
  echo "splunkswapmemode=${splunkswapmemode} unkown value, set to enabled if script present"
  splunkswapmemode=1
fi

if [ -z ${splunkacceptlicense+x} ]; then 
  echo "splunkacceptlicense is unset, assuming no, please read description in variables.tf and fix there as Splunk init will fail later on and please define this tag at intance level"
  splunkacceptlicense="no"
elif [ "${splunkacceptlicense}" == "yes" ]; then 
  echo "OK got tag splunkacceptlicense=yes"
elif [ "${splunkacceptlicense}" == "no" ]; then 
  echo "WARNING got tag splunkacceptlicense=no , please read description in variables.tf and fix there as Splunk init will fail later on ! "
else 
  echo "ERROR unknown value for splunkacceptlicense (${splunkacceptlicense} ), please fix and relaunch, Exiting"
  exit 1
fi
SPLUNKINITOPTIONS+=" --splunkacceptlicense=${splunkacceptlicense}"

# set the mode based on tag and test logic
set_connectedmode

# instance type
if [ -z ${splunkinstanceType+x} ]; then 
  if [ -z ${instanceType+x} ]; then
    echo "ERROR : instance tags are not correctly set (splunkinstanceType). I dont know what kind of instance I am ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-cloud-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunkinstanceType)" >> /var/log/splunkconf-cloud-recovery-info.log
    splunkinstanceType=$instanceType
  fi
else 
  echo "using splunkinstanceType from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
# will become the name when not a indexer, see below
instancename=$splunkinstanceType 
if [ "${splunkhostmode}" == "os" ]; then
  hostinstancename=`hostname --short | head -1`
  echo "using os name ${hostinstancename}"
elif [ "${splunkhostmode}" == "prefix" ]; then
  shorthost=`hostname --short | head -1`
  hostinstancename="${instancename}-${shorthost}"
  echo "building with prefix and os name ${hostinstancename}"
else 
  hostinstancename=$instancename
  echo "using instancetype ,  not using host name . ${hostinstancename}"
fi
echo "splunkinstanceType : instancename=${instancename},hostinstancename=${hostinstancename}" >> /var/log/splunkconf-cloud-recovery-info.log

set_hostname

# splunk s3 install bucket
if [ -z ${splunks3installbucket+x} ]; then 
  if [ -z ${s3installbucket+x} ]; then
    echo "instance tags are not correctly set (splunks3installbucket). I dont know where to get the installation files ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-cloud-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunks3installbucket)" >> /var/log/splunkconf-cloud-recovery-info.log
    splunks3installbucket=$s3installbucket
  fi
else 
  echo "using splunks3installbucket from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "splunks3installbucket is ${splunks3installbucket}" >> /var/log/splunkconf-cloud-recovery-info.log

# splunk s3 backup bucket
if [ -z ${splunks3backupbucket+x} ]; then 
  if [ -z ${s3backupbucket+x} ]; then
    echo "instance tags are not correctly set (splunks3backupbucket). I dont know where to get the backup files ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-cloud-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunks3backupbucket)" >> /var/log/splunkconf-cloud-recovery-info.log
    splunks3backupbucket=$s3backupbucket
  fi
else 
  echo "using splunks3backupbucket from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "splunks3backupbucket is ${splunks3backupbucket}" >> /var/log/splunkconf-cloud-recovery-info.log

# splunkmode 
# value = uf mean will be deploying uf only
# currently the only possible value

SPLUNK_HOME="/opt/splunk"
if [ -z ${splunkmode+x} ]; then 
  echo "splunkmode is not set, assuming full mode" >> /var/log/splunkconf-cloud-recovery-info.log
  splunkmode="ent"
elif [ "${splunkmode}" == "uf" ]; then 
  echo "splunkmode is set to uf, we will deploy uf" >> /var/log/splunkconf-cloud-recovery-info.log
  SPLUNK_HOME="/opt/splunkforwarder"
  SPLUNKINITOPTIONS+=" --SPLUNK_HOME=${SPLUNK_HOME} --service-name=splunkforwarder"
else
  echo "ATTENTION : Invalid value ${splunkmode} for splunkmode , ignoring it, please correct and relaunch if needed" >> /var/log/splunkconf-cloud-recovery-info.log
  splunkmode="ent"
fi

# splunk org prefix for base apps
if [ -z ${splunkorg+x} ]; then 
    echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
    #we can continue as we will just do nothing, ok for legacy mode  
    #exit 1
else 
  echo "using splunkorg from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "splunkorg is ${splunkorg}" >> /var/log/splunkconf-cloud-recovery-info.log

# splunkdnszone used for updating route53 when apropriate (replace splunkawsdnszone that we still try to detect as a fallback) 
if [ -z ${splunkdnszone+x} ]; then 
  if [ -z ${splunkawsdnszone+x} ]; then 
    echo "instance tags are not correctly set (splunkdnszone or splunkawsdnszone). I dont know splunkdnszone to use for updating dns ! Please add splunkdnszone tag" >> /var/log/splunkconf-cloud-recovery-info.log
    #we can continue as we will just do nothing but obviously route53 update will fail if this is needed for this instance
    #exit 1
  else 
    echo "using splunkawsdnszone from instance tags (DEPRECATED, please consider renaming splunkawsdnszone to splunkdnszone) " >> /var/log/splunkconf-cloud-recovery-info.log
    splunkdnszone=$splunkawsdnszone
  fi
fi
if [ -z ${splunkdnszone+x} ]; then 
  echo "splunkdnszone not set, disabling dns update" >> /var/log/splunkconf-cloud-recovery-info.log
else
  echo "using splunkdnszone $splunkdnszone from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
  if [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    echo " indexer , no dns update on this kind of host"
  elif [ $cloud_type == 1 ]; then
    if [ -z ${splunkdnsmode+x} ]; then
      splunkdnsmode="inline"
    fi
    if [[ "${splunkdnsmode}" =~ (lambda|disabled) ]]; then
      echo "disabling route53 update inside recovery as explicitiley disabled by admin or running in lambda mode (splunkdnsmode=${splunkdnsmode})" >> /var/log/splunkconf-cloud-recovery-info.log
    else 
      echo "#************************************* ROUTE53 ********************************************************"
      echo "updating dns via route53 api" >> /var/log/splunkconf-cloud-recovery-info.log
      # AWS doing direct dns update in recovery
      TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600"`
      IP=$( curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 )
      # need iam ->  policy  permissions of
      #
      #{
      #    "Version": "2012-10-17",
      #    "Statement": [
      #        {
      #            "Sid": "VisualEditor0",
      #            "Effect": "Allow",
      #            "Action": [
      #                "route53:ChangeResourceRecordSets",
      #                "route53:ListHostedZonesByName"
      #            ],
      #            "Resource": "*"
      #        }
      #    ]
      #}

      NAME=$instancename
      #NAME=`hostname --short`
      DOMAIN=$splunkdnszone
      FULLNAME=$NAME"."$DOMAIN

      HOSTED_ZONE_ID=$( aws route53 list-hosted-zones-by-name | grep -i ${DOMAIN} -B5 | grep hostedzone | sed 's/.*hostedzone\/\([A-Za-z0-9]*\)\".*/\1/')
      echo "Hosted zone being modified: $HOSTED_ZONE_ID"

      INPUT_JSON=$(cat <<EOF
{ "ChangeBatch":
 {
  "Comment": "Update the record set of ${FULLNAME}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${FULLNAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${IP}"
          }
        ]
      }
    }
  ]
 }
}
EOF
)

      echo "updating dns via route53 API for ${FULLNAME} to ${IP}"
      aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --cli-input-json "$INPUT_JSON" || echo "ERROR updating dns record for ${FULLNAME}"
    fi  # splunkdnsmode
  elif [ -z ${splunkdnszoneid+x} ]; then
    echo "ERROR ATTENTION splunkdnszoneid is not defined, please add it as we cant update dns in GCP without this"
  elif [ $cloud_type == 2 ]; then
    echo "#************************************* GCP DNS RECORD-SETS ********************************************************"
    # GCP doing direct dns update in recovery
    MYIP=`ifconfig |  grep -v 127.0.0.1 | grep inet | grep -v inet6 | grep -Eo 'inet\s[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+'`
    OLDIP=`gcloud dns --project=${projectid} record-sets list --zone=${splunkdnszoneid} --name=${instancename}.${splunkdnszone} --type A | tail -1 |grep -Eo '[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+'`
    # the api ask to remove the record with current value before being able to add again ... pretty complex 
    if [ -z "${OLDIP}" ]; then
      echo "MYIP=$MYIP OLDIP=N/A"
      RES=`gcloud dns --project=${projectid} record-sets transaction start --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction add ${MYIP} --name=${instancename}.${splunkdnszone} --ttl=180 --type=A --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction execute --zone=${splunkdnszoneid}`
    else
      echo "MYIP=$MYIP OLDIP=$OLDIP"
      RES=`gcloud dns --project=${projectid} record-sets transaction start --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction remove ${OLDIP} --name=${instancename}.${splunkdnszone} --ttl=180 --type=A --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction add ${MYIP} --name=${instancename}.${splunkdnszone} --ttl=180 --type=A --zone=${splunkdnszoneid};gcloud dns --project=${projectid} record-sets transaction execute --zone=${splunkdnszoneid}`
    fi
  else
    echo "unknown cloud type, not doing any dns update"
  fi 
fi
echo "splunkdnszone is ${splunkdnszone}" >> /var/log/splunkconf-cloud-recovery-info.log
echo "splunkdnszoneid is ${splunkdnszoneid}" >> /var/log/splunkconf-cloud-recovery-info.log
echo "splunkdnszone is ${splunkdnszone}" >> /var/log/splunkconf-cloud-recovery-info.log



echo "SPLUNK_HOME is ${SPLUNK_HOME}" >> /var/log/splunkconf-cloud-recovery-info.log
localbackupdir="${SPLUNK_HOME}/var/backups"
localinstalldir="${SPLUNK_HOME}/var/install"
SPLUNK_DB="${SPLUNK_HOME}/var/lib/splunk"
localkvdumpbackupdir="${SPLUNK_DB}/kvstorebackup/"
if [ $cloud_type == 2 ]; then
  remotebackupdir="${splunks3backupbucket}/splunkconf-backup/${instancename}"
  remoteinstalldir="${splunks3installbucket}/install"
  remotepackagedir="${splunks3installbucket}/packaged/${instancename}"
else
  remotebackupdir="s3://${splunks3backupbucket}/splunkconf-backup/${instancename}"
  remoteinstalldir="s3://${splunks3installbucket}/install"
  remotepackagedir="s3://${splunks3installbucket}/packaged/${instancename}"
fi
remoteinstallsplunkconfbackup="${remoteinstalldir}/apps/splunkconf-backup.tar.gz"
# this path expected by ES install script
localappsinstalldir="${SPLUNK_HOME}/splunkapps"
localscriptdir="${SPLUNK_HOME}/scripts"
localrootscriptdir="/usr/local/bin"
# by default try to restore backups
# we will disable if indexer detected as not needed
RESTORECONFBACKUP=1

echo "#************************************* ARGUMENTS for upgrade, os update, cgroup and reboot logic  ********************************************************"

init_arg

echo "#************************************* SPLUNK USER AND GROUP CREATION ********************************************************"
# splunkuser checks


if [ "${splunkmode}" == "uf" ] && [ -z ${splunkuser+x} ]; then 
  usersplunk="splunkfwd"
  splunkuser="splunkfwd"
  echo "splunkuser is unset and uf mode set, user default to splunkfwd (SPLUNK_HOME=${SPLUNK_HOME})"
elif [ -z ${splunkuser+x} ]; then 
  usersplunk="splunk"
  splunkuser="splunk"
  echo "splunkuser is unset (default mode), user default to splunk (SPLUNK_HOME=${SPLUNK_HOME})"
else 
  sizeuser=${#splunkuser} 
  sizemin=5
  if (( sizeuser < sizemin )); then
    # this may be the case on GCP du to thwe way we get tag, the var exist but is empty like
    echo "splunk user length too short or empty tag, bad input or extra characters, ignoring tag value and assuming user is splunk"
    usersplunk="splunk"
    splunkuser="splunk"
  fi
  echo "splunkuser='${splunkuser}'" 
  usersplunk=$splunkuser
fi

if [ "${splunkmode}" == "uf" ] && [ -z ${splunkgroup+x} ]; then 
  splunkgroup="splunkfwd"
  echo "splunkgroup is unset and uf mode set, group default to splunkfwd (SPLUNK_HOME=${SPLUNK_HOME})"
elif [ -z ${splunkgroup+x} ]; then 
  splunkgroup="splunk"
  echo "splunkgroup is unset, default to splunk"
else 
  sizegroup=${#splunkgroup} 
  sizemin=5
  if (( sizegroup < sizemin )); then
    echo "splunk group length too short or empty tag, bad input or extra characters, ignoring tag value and assuming group is splunk"
    splunkgroup="splunk"
  fi
  echo "splunkgroup='${splunkgroup}'" 
fi

USERFOUND=0
if id "${splunkuser}" &>/dev/null; then
  echo 'splunkuser ${splunkuser} found'
  USERFOUND=1 
else
  echo 'splunkuser ${splunkuser} not found'
  USERFOUND=0 
fi

GROUPFOUND=0
if id "${splunkgroup}" &>/dev/null; then
  echo 'splunkgroup ${splunkgroup} found'
  GROUPFOUND=1
else
  echo 'splunkgroup ${splunkgroup} not found'
  GROUPFOUND=0
fi


# check the splunkuser is not a admin, remove this check only if you understand what that mean

sizeuser=${#splunkuser} 
sizegroup=${#splunkgroup} 
# size min (5 will avoid for exemple calling it root)
sizemin=5


if (( sizeuser < sizemin )); then 
  echo "FAIL : splunk user length too short, minimum = $sizemin, please fix and relaunch"
  exit 1
fi 

if (( sizegroup < sizemin )); then 
  echo "FAIL : splunk group length too short, minimum = $sizemin, please fix and relaunch"
  exit 1
fi 

# fixme add group support here

# fixme more checks here

# manually create the splunk user so that it will exist for next step   
useradd --home-dir ${SPLUNK_HOME} --comment "Splunk Server" ${splunkuser} --shell /bin/bash 

if (( splunkrsyncmode == 1 )); then
  if [[ "cloud_type" -eq 1 ]]; then
    # aws
    echo "rsync over ssh mode, trying to setup keys"
    mkdir -p ${SPLUNK_HOME}/.ssh
    chmod u=rwx,og-rwx ${SPLUNK_HOME}/.ssh
    chown ${splunkuser}. ${SPLUNK_HOME}/.ssh
    aws ssm get-parameter --name splunk_ssh_key_rsync_priv --query "Parameter.Value" --output text --region $REGION > ${SPLUNK_HOME}/.ssh/id_rsa
    chown ${splunkuser}. ${SPLUNK_HOME}/.ssh/id_rsa
    chmod u=rw,go= ${SPLUNK_HOME}/.ssh/id_rsa
    aws ssm get-parameter --name splunk_ssh_key_rsync_pub --query "Parameter.Value" --output text --region $REGION >> ${SPLUNK_HOME}/.ssh/authorized_keys
    chown ${splunkuser}. ${SPLUNK_HOME}/.ssh/authorized_keys
    chmod u=rw,go= ${SPLUNK_HOME}/.ssh/authorized_keys
  else
    echo "fixme : rsync mode not implemented  with cloud_type=$cloud_type "
  fi
fi

# install addition os packages 
PACKAGELIST="wget perl java-1.8.0-openjdk nvme-cli lvm2 gdb polkit tuned zstd pip"
if [ $( rpm -qa | grep -ic curl-minimal  ) -gt 0 ]; then
        echo "curl-minimal package detected"
else
        echo "curl-minimal not detected, assuming curl"
        PACKAGELIST="${PACKAGELIST} curl"
fi
if [[ $splunkenableworker == 1 ]]; then
  PACKAGELIST="${PACKAGELIST} ansible"
  echo "INFO: splunkenableworker=1 adding ansible to packagelist"
fi
if [ "${splunktargetbinary}" == "sc4s" ]; then
  PACKAGELIST="${PACKAGELIST} docker"
  echo "INFO: sc4s needed adding docker to packagelist"
fi

get_packages


if [ "$MODE" == "upgrade" ]; then 
  echo "#************************************* UPGRADE ENGINE MIGRATION CHECK ********************************************************"
  # add storageEngineMigration=true
  SPLSPLUNKBIN="${SPLUNK_HOME}/bin/splunk";
  kvengine=`su - $usersplunk -c "$SPLSPLUNKBIN btool server list kvstore | grep storageEngine | grep -v storageEngineMigration | cut -d\" \" -f 3"`
  kvmigration=`su - $usersplunk -c "$SPLSPLUNKBIN btool server list kvstore | grep storageEngineMigration | cut -d\" \" -f 3"`

  if [ "$kvmigration" == "false" ]; then
    if [ "$kvengine" == "mmapv1" ]; then
          echo "nmapv1 in use and kvstore enginemigration not set, setting it so upgrade will initiate migration"
          echo -e "\n[kvstore]\nstorageEngineMigration=true\n" >> ${SPLUNK_HOME}/etc/system/local/server.conf
    else
          echo "engine already migrated , nothing to do"
    fi
  else
    echo "kvmigration already set, nothing to do"
  fi
fi

if [ "$MODE" != "upgrade" ]; then 
  # if idx
  if [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    echo "#************************************** DISK ************************"
    echo "indexer -> configuring additional partition(s)" >> /var/log/splunkconf-cloud-recovery-info.log
    RESTORECONFBACKUP=0
    setup_disk
  else
    echo "not a idx, no additional partition to configure" >> /var/log/splunkconf-cloud-recovery-info.log
    extend_fs
    PARTITIONFAST="/"
  fi # if idx

  echo "#************************************** BACKUP AND INSTALL DIR STRUCTURE CREATION  ************************"
  # localbackupdir creation
  mkdir -p ${localbackupdir}
  chown ${usersplunk}. ${localbackupdir}
  mkdir -p ${localinstalldir}
  chown ${usersplunk}. ${localinstalldir}

  echo "#************************************** SWAP MANAGEMENT ************************"
  if [ "$splunkswapmemode" == "1" ]; then
    # swap management
    swapme="splunkconf-swapme.pl"
    get_object ${remoteinstalldir}/${swapme} ${localrootscriptdir}
    if [ ! -f "${localrootscriptdir}/${swapme}"  ]; then
      echo "WARNING  : ${swapme} is not present in ${remoteinstalldir}/${swapme}, unable to tune swap  -> please verify the version specified is presen or use splunkswapme tag to choose the mode you prefer" >> /var/log/splunkconf-cloud-recovery-info.log
    else
      chmod u+x ${localrootscriptdir}/${swapme}
      if [ "${splunkmode}" == "uf" ]; then
        echo "INFO: disabling swapme support as uf detected" >> /var/log/splunkconf-cloud-recovery-info.log
      else
        # launching script and providing it info about the main partition that should be SSD like and have some room
        ${localrootscriptdir}/${swapme} $PARTITIONFAST
      fi
    fi
  else
    echo "INFO: splunkswapme logic disabled by config"
  fi
fi # if not upgrade



echo "#************************************** SPLUNK SOFTWARE BINARY INSTALLATION ************************"
# Splunk installation
# note : if you update here, that could update Splunk version at reinstanciation (redeploy backup while upgrading to this version), make sure you know what you do !
splversion="9.3.1"
splhash="0b8d769cb912"
splversionhash=${splversion}-${splhash}""
# this is spl arch, arch will be the one from os
splarch="x86_64"
arch=`uname --hardware-platform`


if [ "$splunkmode" == "uf" ]; then 
  splbinary="splunkforwarder-${splversionhash}.${splarch}.rpm"
  echo "switching to uf binary ${splbinary} if not set in tag"
else
  #splbinary="splunk-9.1.2-b6b9c8185839.x86_64.rpm"
  splbinary="splunk-${splversionhash}.${splarch}.rpm"
fi

if [ -z ${splunktargetbinary+x} ]; then 
  echo "splunktargetbinary not set in instance tags, falling back to use version ${splbinary} from cloud recovery script" >> /var/log/splunkconf-cloud-recovery-info.log
elif [ "${splunktargetbinary}" == "auto" ]; then
  echo "splunktargetbinary set to auto in instance tags, falling back to use version ${splbinary} from cloud recovery script" >> /var/log/splunkconf-cloud-recovery-info.log
  unset ${splunktargetbinary}
elif [ "${splunktargetbinary}" == "sc4s" ]; then
  echo "splunktargetbinary set to sc4s in instance tags, will try to deploy docker and sc4s service" >> /var/log/splunkconf-cloud-recovery-info.log
else 
  splbinary=${splunktargetbinary}
  splarch=$(echo "${splunktargetbinary}" | cut -d '.' -f 2)
  if [[ $splarch == $arch ]]; then
    echo "INFO: good, arch match $splarch" 
  else
    echo "WARN: ATTENTION **************************arch mismatch or detection issue, install may fail ********************"
  fi 
  echo "using splunktargetbinary=\"${splunktargetbinary}\" with splarch=${splarch} and arch=$arch from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
echo "remote : ${remoteinstalldir}/${splbinary}" >> /var/log/splunkconf-cloud-recovery-info.log
# aws s3 cp doesnt support unix globing
get_object ${remoteinstalldir}/${splbinary} ${localinstalldir} 
ls ${localinstalldir}
if [ "${splunktargetbinary}" == "sc4s" ]; then
  echo "sc4s mode"
elif [ ! -f "${localinstalldir}/${splbinary}"  ]; then
  if [ $splunkconnectedmode == 2 ] || [ $splunkconnectedmode == 3 ]; then
    echo "RPM missing from install and splunkconnectedmode setting prevent trying to download directly "
  elif [ "$splunkmode" == "uf" ]; then 
    echo "RPM not present in install, trying to download directly (uf version)"
    ###### change from version on splunk.com : add -q , add ${localinstalldir}/ and add quotes around 
    `wget -q -O ${localinstalldir}/${splbinary} "https://download.splunk.com/products/universalforwarder/releases/${splversion}/linux/${splbinary}"`
    #`wget -q -O ${localinstalldir}/splunkforwarder-9.1.2-b6b9c8185839.x86_64.rpm "https://download.splunk.com/products/universalforwarder/releases/9.1.2/linux/splunkforwarder-9.1.2-b6b9c8185839.x86_64.rpm"`
  else
    echo "RPM not present in install, trying to download directly (ent version)"
    ###### change from version on splunk.com : add -q , add ${localinstalldir}/ and add quotes around 
    `wget -q -O ${localinstalldir}/${splbinary} "https://download.splunk.com/products/splunk/releases/${splversion}/linux/${splbinary}"`
  fi
  if [ ! -f "${localinstalldir}/${splbinary}"  ]; then
    echo "ERROR FATAL : ${splbinary} is not present in s3 -> please verify the version specified is present in s3 install (or fix the wget with wget -q -O ... if you just copied paste wget))  " >> /var/log/splunkconf-cloud-recovery-info.log
    # better to exit now and have the admin fix the situation
    exit 1
  fi
else
  echo "succesfully downloaded splbinary ${splbinary} from ${remoteinstalldir}/${splbinary}"
fi

echo "importing GPG key"
cat <<EOF >/root/splunk-gpg-key.pub
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBFtbebEBEADjLzD+QXyTqLwT2UW1Dle5MpBj+C5cbaCIpFEhl+KemcnUKHls
TlCxEpzJczZPiYtcp+wtKCaNG/zoEvYCQ0jKk6Wgoa2cLkDeHtNiuBCHrztgeDTe
FpPT+xmtLoJvu1T0JV/iPG7p5FBGYKOKApnd/awRRC47plCGfVA3VVdQP8jhpMZV
T9C86hWbNo/NRjNH69x1xAe/9POc8KmVxZQb+KGG5tulGIWa7jlTMw850HZwFcft
F13DiAVgCj516K8oZBb5bjgu2ZvpCtMRbCmrzx26ilcB7VJRsTaB6G8MqRzVgLuj
11dTG2XMuBw+3UcjAlZ/y6Cut0Gc5FHIKqwMVXf29y9uXddvIqQnkE0AkOj6flm6
OElvmq7v+NVYLRb9XTy0oWTwOtyGTTso2xwZ8itDT4rIWeta0FxtQPt8Kq369ZGy
CbKl1PU9IrKAeST0AkXyfQXqPc0IzHxz3AhOLzvwm/9/0OWs0ONbxdyTCxQjrhe6
1YBoVv2T5K27fTp7rMFEstyU0NFI3J5P/oxg5ts6y2lCMUB7Q71yAOWVZPgucOAH
7iiNmvrytuGT0c8TfJku1cneajW9jmNvKVD/r3qj6YTAL3mqC0yYx3PiLyUVm8OZ
q90hpFHAI7zV1u6zMqV4EkWg5tEknMWcjQnyIfn0Jx8LedDjbTM8Dt9VKQARAQAB
tCFTcGx1bmssIEluYy4gPHJlbGVhc2VAc3BsdW5rLmNvbT6JAk4EEwEIADgWIQRY
wzMQt6NUwSedtmle+gHts81EIAUCW1t5sQIbAwULCQgHAgYVCAkKCwIEFgIDAQIe
AQIXgAAKCRBe+gHts81EIEsUD/9urCsBW40ahPr1gBsu6TlFbVWFN6TK7NpByecr
KzhDlOGJbh7g1u1qRO88ncUb/iPFfBjpJJ0RbskrZQKVVbmnhLeNPw4oqHq4kNmN
Kc8iV9tynw55Ww5Y0cJoeWrx9Ireub3+1GhKzUomIK0TuQtMULmW7Tdwm46iEDgC
qox2hOutlMFjrT9XOFnluCeyi8HL9m6xUlvvsxYxqWIzWUvoWH3AwpGSPMwg/nzH
Vl1Wz9IJOLqjQFBiA1Vmb/UEkP60JAtXWtNKJ7OqTLag29XBSaJO1NiQFZYb8uCU
GSqNOKYUwiO3ZivmVYlXBT7fC2uHpU45g/d2PrRKgVvIOC9xKiG8+jh/WuWlTl4i
vVjAIEnIFwO8Nig7uoR9xi+0ZxzkP00tGO2Cgv0cFf3TYQrSgrD7QDRBN2az4HtF
WvxJuOYjNLl7mp+Lx0Aj9wtb1WkYNBV0NMXThhnZsDU6Uo6ijJa2uBwkT8MljCHX
n7DjVFZYoZ6m2cwUdR5XSwfpSq0lA7LcSbef4CIC1H0mVxVzeB2B6xGxpVIMNGs4
B1RXW1amVeKmv9ZbTAQpGNVMyGJ8oOhksBFL2Ng0Z5kA9aCuwr1OjyrxBdglfGd/
wmEGIX2cLNNvS+Elh4JzFuKsURWbJ8qFl7cQvKQkS+UTwu7e3CCp8VztfRqPvgQi
A+2oI7kCDQRbW3mxARAAtoBTC9nNiY3301QKzTyPvudD3XI03RZTXVsSHVP4yV0x
fobD2aRhMjxwRjrajZnMCEFKB7yYtsbyiRfznLoycFBse6p4y9gguWEIgaW6TTQP
zQTEgi6AKt38nqDN42L/WurNhAKq9R5X/85vr2t6b18Yp2kw62okbuTtVLjuNwzh
tnZE/HziWVbtBy0KfZ0c6QMUHn7j0U67+QJeIzLcQuBn4qnb177TRtnqNZ9aFTXX
mnUA7qTOAvL+wsoyOcuOboj4N45H5s/izPSiXkoUM1ITuuUI3QHi46zw5cEvSLg+
WImwwZCN4tC275abjxW7XbirglV1EOlCWoALIOAh1BwXDA/JJGwbGOp+ueE7askJ
TiAtP9EM1mJSWnbE9uKDUvEMIaavwtt0kWmQOrB4HFY0AsTOnCxWQYCOb0CDImyq
ScblC3tqvoZzbjPBHQFvxClzxfGdmvQwoxr2WRfsspLPuG1FzgmmX29/WaOV747W
TwJP9xw1OtJmAkq/+CH6J12PmXHy9sJRdk6d1PPEuHjJ588U3Kwc7B5uAtgnwQO8
aS4zPM45y6+J1D2SdM0ydwuqQ9z9wwa022EGTa89k5Vfigx+C/VaDMa1Bu/NSkZ8
7S0NpQGbRwDp76gSKvV1T/15hYVg2nOsI1hTVmM8hVZQO3kO4zFjl0rNNjwWor0A
EQEAAYkCNgQYAQgAIBYhBFjDMxC3o1TBJ522aV76Ae2zzUQgBQJbW3mxAhsMAAoJ
EF76Ae2zzUQg26YP/0dj63ldEluB8L7+dFm9stebcmpgxAugmntdlprDkGi6Rhfd
ks7ufF+mny731GZPcJWIYKi797qerG5O1AI4siaK9FRKzw4PLIGvhOoNg2wrSP/+
7qTFf+ZbT7H5VpIqwcnnnRT05pi1KiMIXW82h47daFYVNhQPbV4+USHwFG7r3Lku
XdiS4hrcoe+Y/a9zGVAdU9QwrT8CuNAw8SYNYx1rJECHiMxmMaEw42a5NARoFdbh
swnR6Mwy5sPhzOHjSI/ZPyM/W9TKAoXfmDQSGDrvnU6NAdpIbP1Ab1FtMjuARfRg
8ndqfm/n8MIvAxjzoBBZkdV5HLOndX3fLVNewnvSWQx9OlV4a7+dKXeQ8TueOMq+
XMA4RKsh3gEMJWbVRZwZnxy+3UKGJD3el0+C7m483ptR8Tj8qBq5KELO0vkcq8+a
eHIbzmQSsj9iAdNfGVLYhimzpZy5NCTl2sgmy4g33pd1jMtUzdFZhvelVzMNlkLZ
AmAJX7yZLQwLsXDEpffgp2S/U8vYAZNTdeZqKvmvCCO+fweRRC7NnnPJQ7nVhL7r
VDxHuk8oMqBQIUdE7Z+WDfyagMMhJWbeMNnnhTZdoPmpXEGkjUKwPDYl+GmF50c1
6vjXtbrcP42pu2IQxiqiaTSLei8LRwPck1eE+78sSUxjVuWRuThoYRhGYoXt
=ivRW
-----END PGP PUBLIC KEY BLOCK-----
EOF
echo "importing GPG key (2)"
rpm --import /root/splunk-gpg-key.pub

INSTALLMODE="rpm"
if [[ ${splbinary} == *.tgz ]] # * is used for pattern matching
then
  echo "non rpm installation, disabling rpm install"; 
  INSTALLMODE="tgz"
else
  echo "RPM installation";
  RES=1
  COUNT=0
  # we need to repeat in case rpm lock taken as it will fail then later on other failures will occur like not having polkit ....
  # unfortunately if ssm is installed something from ssm configured at start may try install software in // breaking us....
  until [[ $COUNT -gt 10 ]] || [[ $RES -eq 0 ]]
  do
    echo "checking GPG key (rpm)"
    rpm -K "${localinstalldir}/${splbinary}" 
    #rpm -K "${localinstalldir}/${splbinary}" || (echo "ERROR : GPG Check failed, splunk rpm file may be corrupted, please check and relaunch\n";exit 1)
    RES=$?
    ((COUNT++))
    if [[ $RES -ne 0 ]]; then
      if [[ $COUNT -gt 5 ]]; then
        echo "ERROR : GPG Check failed after multiple tries, splunk rpm file may be corrupted, please check and relaunch\n"
        exit 1
      else
        echo "ERROR : GPG Check failed, may be temporary du to rpm lock, will retry (COUNT=$COUNT)"
        sleep 5
        # retry import key just in case this is the issue
        rpm --import /root/splunk-gpg-key.pub
        sleep 1
      fi
    fi
  done
  INSTALLMODE="rpm"
fi


# no need to do this for multids (in tar mode)
# may need to fine tune the condition later here
#if [ "$INSTALLMODE" == "rpm" ]; then
# commented for the moment as we still need the dir structure


  # creating dir as we may not have yet deployed RPM
  mkdir -p ${SPLUNK_HOME}/etc/system/local/
  mkdir -p ${SPLUNK_HOME}/etc/apps/
  mkdir -p ${SPLUNK_HOME}/etc/auth/
  chown -R ${usersplunk}. ${SPLUNK_HOME}
#fi

echo "#****************************************** tuning system ***********************************"
echo "Tuning system"
if [ "$SYSVER" -eq 6 ]; then
  # RH6/AWS1 like (deprecated)
  echo "remote : ${remoteinstalldir}/package-systemaws1-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/package-systemaws1-for-splunk.tar.gz  ${localinstalldir} 
  if [ -f "${localinstalldir}/package-systemaws1-for-splunk.tar.gz"  ]; then
    echo "deploying system tuning for Splunk, version for AWS1 like systems" >> /var/log/splunkconf-cloud-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-systemaws1-for-splunk.tar.gz
  else
    echo "remote : ${remoteinstalldir}/package-system-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remoteinstalldir}/package-system-for-splunk.tar.gz  ${localinstalldir} 
    echo "deploying system tuning for Splunk" >> /var/log/splunkconf-cloud-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz
  fi
  # enable the system tuning 
  sysctl --system;/etc/rc.d/rc.local 
  if [ "$splunksecretsdeploymentenable" -eq "1" ]; then
    echo "#****************************************** splunksecrets deployment ***********************************"
    # deploying splunk secrets
    if [ $splunkconnectedmode == 1 ] || [ $splunkconnectedmode == 2 ]; then 
      yum install -y python36-pip
    fi
    if [ $splunkconnectedmode == 1 ]; then 
      pip install --upgrade pip
    fi
    sleep 1
    # this is now problematic to install on AWS1 which is so old
    if [ $splunkconnectedmode == 1 ]; then 
      pip install splunksecrets
      pip-3.6 install splunksecrets
    fi
  else 
    echo "splunksecrets deployment disabled, please use splunk command line support"
  fi
else
  # RH7/8 AWS2 like
  # issue on aws2 , polkit and tuned not there by default
  # in that case, restart from splunk user would return
  # Failed to restart splunk.service: The name org.freedesktop.PolicyKit1 was not provided by any .service files
  # See system logs and 'systemctl status splunk.service' for details.
  # despite the proper policy kit files deployed !
  # moved up for perf
  #yum install polkit tuned -y
  systemctl enable tuned.service
  systemctl start tuned.service
  echo "remote : ${remoteinstalldir}/package-system7-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/package-system7-for-splunk.tar.gz  ${localinstalldir} 
  if [ -f "${localinstalldir}/package-system7-for-splunk.tar.gz"  ]; then
    echo "deploying system tuning for Splunk, version for RH7+ like systems" >> /var/log/splunkconf-cloud-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system7-for-splunk.tar.gz
  else
    echo "remote : ${remoteinstalldir}/package-system-for-splunk.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
    get_object ${remoteinstalldir}/package-system-for-splunk.tar.gz  ${localinstalldir} 
    if [ -f "${localinstalldir}/package-system-for-splunk.tar.gz"  ]; then
      echo "deploying system tuning for Splunk" >> /var/log/splunkconf-cloud-recovery-info.log
      # deploy system tuning (after Splunk rpm to be sure directory structure exist and splunk user also)
      tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz
    else
      echo "ATTENTION ERROR system tuning is missing and could not be deployed, check it is on install bucket and instance has access"
    fi
  fi
  # enable the tuning done via rc.local and restart polkit so it takes into account new rules
  sysctl --system;sleep 1;chmod u+x /etc/rc.d/rc.local;systemctl start rc-local;systemctl restart polkit
  echo "#****************************************** splunksecrets deployment ***********************************"
  # deploying splunk secrets
  if [ $splunkconnectedmode == 1 ]; then 
    pip3 install splunksecrets
  fi
fi

# removal of any leftover from previous splunkconf-backup (that would come from AMI)
if [ -e "/etc/cron.d/splunkbackup.cron" ]; then
   echo "#****************************************** old splunkconf-backup cleanup ***********************************"
   rm /etc/cron.d/splunkbackup.cron
   warn_log "ATTENTION : I had to remove a old splunkbackup cron entry, you may have a old splunkback version deployed as part of the os image. The cron removal will prevent it to run"
fi

if [ "$MODE" != "upgrade" ]; then
  echo "#****************************************** Initial files (skeleton) management ***********************************"
  # fetching files that we will use to initialize splunk
  # splunk.secret just in case we are on a new install (ie won't be in the backup)
  echo "remote : ${remoteinstalldir}/splunk.secret" >> /var/log/splunkconf-cloud-recovery-info.log
  # FIXME : temp , logic is in splunkconf-init
  get_object ${remoteinstalldir}/splunk.secret ${SPLUNK_HOME}/etc/auth 

  echo "remote : ${remotepackagedir} : copying initial apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-cloud-recovery-info.log
  # copy to local
  get_object ${remotepackagedir}/initialapps.tar.gz ${localinstalldir} 
  if [ -f "${localinstalldir}/initialapps.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/initialapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "${remotepackagedir}/initialapps.tar.gz not found, trying without but this may lead to a non functional splunk. This should contain the minimal apps to attach to the rest of infrastructure"
  fi
  echo "remote : ${remotepackagedir} : copying initial TLS apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-cloud-recovery-info.log
  # to ease initial deployment, tls app is pushed separately (warning : once the backups run, backup would restore this also of course)
  get_object  ${remotepackagedir}/initialtlsapps.tar.gz ${localinstalldir} 
  if [ -f "${localinstalldir}/initialtlsapps.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/initialtlsapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "${remotepackagedir}/initialtlsapps.tar.gz not found, trying without but this may lead to a non functional splunk if you enabled custom certificates. This should contain the minimal apps to configure TLS in order to attach to the rest of infrastructure"
  fi
  echo "remote : ${remotepackagedir} : copying ds initial apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/deployment-apps (it will only exist if we are a ds) " >> /var/log/splunkconf-cloud-recovery-info.log
  # copy to local
  get_object ${remotepackagedir}/initialdsapps.tar.gz ${localinstalldir}
  if [ -f "${localinstalldir}/initialdsapps.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/deployment-apps" -zxf ${localinstalldir}/initialdsapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "${remotepackagedir}/initialdsapps.tar.gz not found, this is expected if we are not on a ds"
  fi
  echo "remote : ${remotepackagedir} : copying manager initial apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/manager-apps " >> /var/log/splunkconf-cloud-recovery-info.log
  # copy to local
  get_object ${remotepackagedir}/initialmanagerapps.tar.gz ${localinstalldir}
  if [ -f "${localinstalldir}/initialmanagerapps.tar.gz"  ]; then
    # dir may not exist at this point, need to create it first to populate initial manager apps
    mkdir -p ${SPLUNK_HOME}/etc/manager-apps
    chmod 700 ${SPLUNK_HOME}/etc/manager-apps
    chown ${usersplunk}. ${SPLUNK_HOME}/etc/manager-apps
    tar -C "${SPLUNK_HOME}/etc/manager-apps" -zxf ${localinstalldir}/initialmanagerapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  else
    echo "${remotepackagedir}/initialmanagerapps.tar.gz not found, this is expected if we are not a cm" >> /var/log/splunkconf-cloud-recovery-info.log
  fi
  echo "remote : ${remotepackagedir} : copying splunkcloud uf app to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-cloud-recovery-info.log
  get_object  ${remotepackagedir}/splunkclouduf.spl ${localinstalldir} 
  if [ -f "${localinstalldir}/splunkclouduf.spl"  ]; then
    # 1 = send to splunkcloud only with provided configuration, 2 = clone to splunkcloud with provided configuration, 3 = byol or manual config to splunkcloud
    if [ -z ${splunkcloudmode+x} ]; then 
      echo "splunkcloudmode not set, setting to manual (3)"
      splunkcloudmode="3"
    fi
    if [ "${splunkcloudmode}" -eq "3" ]; then
      echo "splunkcloudmode is manual, not deploying splunkclouduf.spl (that was present, may be you forgot to set splunkcloudmode tag ?)"
    else 
      echo "deploying splunkclouduf.spl (splunkcloudmode=$splunkcloudmode)"
      # FIXME add clone support here ?
      tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/splunkclouduf.spl >> /var/log/splunkconf-cloud-recovery-info.log
    fi
  else
    echo "${remotepackagedir}/splunkclouduf.spl not found, assuming no need to send to splunkcloud or manual config"
  fi
  echo "remote : ${remotepackagedir} : copying certs " >> /var/log/splunkconf-cloud-recovery-info.log
  # copy to local
  get_object  ${remotepackagedir}/mycerts.tar.gz ${localinstalldir}
  if [ -f "${localinstalldir}/mycerts.tar.gz"  ]; then
    tar -C "${SPLUNK_HOME}/etc/auth" -zxf ${localinstalldir}/mycerts.tar.gz 
  else
    echo "${remotepackagedir}/mycerts.tar.gz not found, trying without but this may lead to a non functional splunk if you enabled custom certificates. This should contain the custom certs to configure TLS in order to attach to the rest of infrastructure"
  fi
  if [[ "${instancename}" =~ ds ]]; then
    echo "remote : ${remotepackagedir} : copying initial ds apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/deployment-apps " >> /var/log/splunkconf-cloud-recovery-info.log
    # copy to local
    get_object ${remotepackagedir}/initialdsapps.tar.gz ${localinstalldir} 
    if [ -f "${localinstalldir}/initialdsapps.tar.gz"  ]; then
      mkdir -p "${SPLUNK_HOME}/etc/deployment-apps"
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -zxf ${localinstalldir}/initialdsapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
    else
      echo "${remotepackagedir}/initialdsapps.tar.gz not found, trying without but this may lead to a non functional splunk. This should contain the minimal ds apps deployed to rest of infra and referenced in serverclass configured via deploymentserver app"
    fi
  fi
  #if [[ "${instancename}" =~ cm ]]; then
  #  echo "remote : ${remotepackagedir} : copying initial manager(ex master) apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/master-apps (for the moment, not the logic to avoid conflict between master-apps and manager-apps) " >> /var/log/splunkconf-cloud-recovery-info.log
  #  # FIXME : we need to add logic for v9+ new directory and manage conflicts 
  #  echo "WARNING ! Assuming master-apps is used , update to newer recovery uf you want to use manager-apps on v9+"
  #  # copy to local
  #  get_object ${remotepackagedir}/initialmanagerapps.tar.gz ${localinstalldir} 
  #  if [ -f "${localinstalldir}/initialmanagerapps.tar.gz"  ]; then
  #    mkdir -p "${SPLUNK_HOME}/etc/master-apps"
  #    tar -C "${SPLUNK_HOME}/etc/master-apps" -zxf ${localinstalldir}/initialmanagerapps.tar.gz >> /var/log/splunkconf-cloud-recovery-info.log
  #  else
  #    echo "${remotepackagedir}/initialmanagerapps.tar.gz not found, trying without but this may lead to a non functional splunk. This should contain the apps push from cm to idx"
  #  fi
  #fi
  ## 7.0 no user seed with hashed passwd, first time we have no backup lets put directly passwd 
  #echo "remote : ${remoteinstalldir}/passwd" >> /var/log/splunkconf-cloud-recovery-info.log
  #aws s3 cp ${remoteinstalldir}/passwd ${localinstalldir} --quiet
  ## copying to right place
  #cp ${localinstalldir}/passwd /opt/splunk/etc/
  #chown -R ${usersplunk}. /opt/splunk

  # giving the index directory to splunk if they exist
  if [ -d "/data/vol1/indexes" ]; then 
    chown -R ${usersplunk}. /data/vol1/indexes
  fi
  if [ -d "/data/vol2/indexes" ]; then 
    chown -R ${usersplunk}. /data/vol2/indexes
  fi

  echo "#****************************************** BACKUP DOWNLOAD AND DEPLOYMENT ***********************************"
  # deploy including for indexers
  echo "remote : ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz ${localbackupdir}
  # setting up permissions for backup
  chown ${usersplunk}. ${localbackupdir}/*.tar.*
  chmod 400 ${localbackupdir}/*.tar.*
  if [ -f "${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz"  ]; then
    # excluding this script to avoid restoring a older version from backup
    tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh --exclude opt/splunk/scripts/splunkconf-cloud-recovery.sh --exclude usr/local/bin/splunkconf-cloud-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz
  else
    echo "INFO: ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz not found, trying without. You can use this to package custom scripts to be deployed at installation time" 
  fi
  if [ "$RESTORECONFBACKUP" -eq 1 ]; then
    # getting backups  
    echo "***********Starting to download backups (autodetecting each type)***********" >> /var/log/splunkconf-cloud-recovery-info.log
    kvdumpbackupfound=0
    etcbackupfound=0
    statebackupfound=0
    scriptsbackupfound=0
    for type in etc-targeted state scripts kvdump kvstore
    do 
       #FOUND=0
       DONE=0
       if [ ${kvdumpbackupfound} = "1" ]; then
           if [ ${type} = "kvstore" ]; then
               echo "skipping kvstore detection as kvdump present" >> /var/log/splunkconf-cloud-recovery-info.log
               continue
           fi
       fi
       # we are looping with priority so as soon as we find we exit the loop to find the next type
       for mode in rel abs
       do  
           for compress in zst gz
           do  
               compressbin="gzip"
               if [ "${compress}" = "zst" ]; then
                   compressbin="zstd"
               fi
               extmode=""
               backupuntardir="/"
               if [ "${mode}" = "rel" ]; then
                   extmode="rel-"
                   backupuntardir="${SPLUNK_HOME}"
                   # this is the form that gets added in name if the backup was made relative to splunk home
                   # otherwise no extension
               fi
               FI="backupconfsplunk-${extmode}${type}.tar.${compress}"
               localdir=${localbackupdir}
               if [ "${type}" = "kvdump" ]; then
                   localdir=${localkvdumpbackupdir}
               fi
               if [ ! -d ${localdir} ]; then
                    mkdir -p ${localdir}
                    chown ${usersplunk}. ${localdir}
               fi
               get_object ${remotebackupdir}/${FI} ${localdir}
               if [ -e "${localdir}/${FI}" ]; then
                   echo "backup form ${FI} found" >> /var/log/splunkconf-cloud-recovery-info.log
                   # making sure splunk user can access the backup
                   chmod 400 ${localdir}/$FI
                   chown ${usersplunk}. ${localdir}/$FI
                   if [ "${compress}" = "zst" ]; then
                       if ! command -v zstd &> /dev/null
                       then
                          echo "ERROR FATAL : backup $FI was created with zstd but zstd binary could not be deployed to this instance, stopping here to force admin fix that unforeseen situation !" >> /var/log/splunkconf-cloud-recovery-info.log
                          exit 1
                       fi
                   fi
                   if [ "${type}" = "kvdump" ]; then
                       mv ${localdir}/$FI ${localdir}/backupconfsplunk-kvdump-toberestored.tar.${compress}
                       echo "DEBUG: ${type} backup found"
                       kvdumpbackupfound=1
                   else   # untarring
                       echo "Deploying ${localdir}/$FI into ${backupuntardir}" >> /var/log/splunkconf-cloud-recovery-info.log
                       tar -I ${compressbin} -C ${backupuntardir} -xf ${localdir}/$FI
                       chown -R ${usersplunk}. ${SPLUNK_HOME}
                   fi
                   DONE=1
               else
                   echo "backup form ${FI} not found, trying next form if applicable" >> /var/log/splunkconf-cloud-recovery-info.log
               fi
               if [[ $DONE == 1 ]]; then
                   break
               fi
           done # compress
           if [[ $DONE == 1 ]]; then
               break
           fi
       done # mode
       if [[ $DONE == 1 ]]; then
           continue
       else
           echo "attention, no remote backup found for $type (this is expected if you just created the env otherwise you are probably in trouble)" 
       fi
    done   # type

    echo "localbackupdir ${localbackupdir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
    ls -l ${localbackupdir} >> /var/log/splunkconf-cloud-recovery-info.log

    echo "localkvdumpbackupdir ${localkvdumpbackupdir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
    ls -l ${localkvdumpbackupdir} >> /var/log/splunkconf-cloud-recovery-info.log

    if [ -f "${localinstalldir}/mycerts.tar.gz"  ]; then
      # if we updated certs, we want them to optionally replace the ones in backup
      tar -C "${SPLUNK_HOME}/etc/auth" -zxf ${localinstalldir}/mycerts.tar.gz 
    fi
  # if restore
  fi

  echo "#****************************************** SPLUNK HOSTNAMES MANAGEMENT ***********************************"
  # set the hostname except if this is auto or contain idx or generic name
  # below is the exception criteria (ie indexer, uf  we cant set the name for example as there can be multiple instance of the same type)
  if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then 
    echo "specific instance name : changing hostname to ${hostinstancename} "
    # first time actions 
    # set instance names if splunk instance was already started (in the ami or from the backup...) 
    #sed -i -e "s/ip\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}/${hostinstancename}/g" ${SPLUNK_HOME}/etc/system/local/inputs.conf
    sed -i -e "s/^host.*$/host = ${hostinstancename}/g" ${SPLUNK_HOME}/etc/system/local/inputs.conf
    #sed -i -e "s/ip\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}/${hostinstancename}/g" ${SPLUNK_HOME}/etc/system/local/server.conf
    sed -i -e "s/^serverName.*$/serverName = ${hostinstancename}/g" ${SPLUNK_HOME}/etc/system/local/server.conf
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/inputs.conf"  ]; then
      # Splunk was never started  (ie we just deployed in the recovery above)
      echo "initializing inputs.conf with ${hostinstancename}\n"
      echo "[default]" > ${SPLUNK_HOME}/etc/system/local/inputs.conf
      echo "host = ${hostinstancename}" >> ${SPLUNK_HOME}/etc/system/local/inputs.conf
      chown ${usersplunk}. ${SPLUNK_HOME}/etc/system/local/inputs.conf
    fi
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/server.conf"  ]; then
      # Splunk was never started  (ie we just deployed in the recovery above)
      echo "initializing server.conf with ${hostinstancename}\n"
      echo "[general]" > ${SPLUNK_HOME}/etc/system/local/server.conf
      echo "serverName = ${hostinstancename}" >> ${SPLUNK_HOME}/etc/system/local/server.conf
      chown ${usersplunk}. ${SPLUNK_HOME}/etc/system/local/server.conf
    fi
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/deploymentclient.conf"  ]; then
      echo "initializing deploymentclient.conf with ${hostinstancename}\n"
      echo "[deployment-client]" > ${SPLUNK_HOME}/etc/system/local/deploymentclient.conf
      echo "clientName = ${hostinstancename}" >> ${SPLUNK_HOME}/etc/system/local/deploymentclient.conf
      chown ${usersplunk}. ${SPLUNK_HOME}/etc/system/local/deploymentclient.conf
    fi
  elif [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    echo "#****************************************** AUTO ZONE DETECTION ***********************************"
    if [ -z ${splunkorg+x} ]; then 
      echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
      splunkorg="org"
    else 
      echo "using splunkorg=${splunkorg} from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
    fi
    if [[ "cloud_type" -eq 2 ]]; then
      # gcp
      AZONE=`curl --silent --show-error -H "Metadata-Flavor: Google" -fs http://metadata/computeMetadata/v1/instance/zone`
    else # 1= AWS    
      AZONE=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone  `
    fi
    ZONELETTER=${AZONE: -1}
    sitenum=0
    # depending on region and what the user enabled there could be more than the first 3 AZ (example virginia)
    # the admin could have chosen different AZ
    # the site list should be defined and exactly matching what is used in the CM configuration
    case $ZONELETTER in
      a)
        sitenum="1" ;;
      b)
        sitenum="2" ;;
      c)
        sitenum="3" ;;
      d)
        sitenum="4" ;;
      e)
        sitenum="5" ;;
      f)
        sitenum="6" ;;
      g)
        sitenum="7" ;;
      h)
        sitenum="8" ;;
    esac
    if [[ $sitenum > $splunksmartstoresitenumber ]]; then
      echo "INFO: indexer started in a zone over splunksmartstoresitenumber (splunksmartstoresitenumber=${splunksmartstoresitenumber}), setting site to ${splunksmartstoresitenumber} so the site is accepted by cm (value would have been $sitenum))"
      echo "INFO: This is expected if you run over multiple zone for instance resiliency without replication (because you start less instance than zones and the cm need to see at least one idx per zone declared to switch to indexing-ready mode). If that is not the case, please set splunksmartstoresitenumber to match the availabilities zones (should be 3 with AZa, AZb and AZc usually)"
      sitenum=$splunksmartstoresitenumber
   fi
    site="site${sitenum}"
    echo "Indexer detected setting site for availability zone $AZONE (letter=$ZONELETTER,sitenum=$sitenum, site=$site) " >> /var/log/splunkconf-cloud-recovery-info.log
    # removing any conflicting app that could define site
    # giving back files to splunk user (this is required here as if the permissions are incorrect from tar file du to packaging issues, the delete from splunk below will fail here)
    chown -R ${usersplunk}. $SPLUNK_HOME
    FORME="*site*base"
    # find app that match forn and deleting the app folder
    su - ${usersplunk} -c "/usr/bin/find $SPLUNK_HOME/etc/apps/ -name \"${FORME}\" -exec rm -r {} \; "
    find $SPLUNK_HOME/etc/apps/ -name \"\*site\*base\" -delete -print >> /var/log/splunkconf-cloud-recovery-info.log
    mkdir -p "$SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base/local"
    echo -e "#This configuration was automatically generated based on indexer location\n#This site should be defined on the CM\n[general] \nsite=$site" > $SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base/local/server.conf
    # giving back files to splunk user
    chown -R ${usersplunk}. $SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base
    echo "Setting Indexer on site: $site" >> /var/log/splunkconf-cloud-recovery-info.log
    echo "Disabling SSG app (not needed/used on this instance)" >> /var/log/splunkconf-cloud-recovery-info.log
    mkdir -p "$SPLUNK_HOME/etc/apps/splunk_secure_gateway/local"
    echo -e "#This configuration was automatically generated to disable ssg on indexers\n[install] \nstate = disabled" > $SPLUNK_HOME/etc/apps/splunk_secure_gateway/local/app.conf
    # giving back files to splunk user
    chown -R ${usersplunk}. $SPLUNK_HOME/etc/apps/splunk_secure_gateway
    if [ $SYSVER -eq "6" ]; then
      echo "running non systemd os , we wont add a custom service to terminate"
    else
      echo "running systemd os , adding Splunk idx terminate service"
      # this service is ran at stop when a instance is terminated cleanly (scaledown event)
      # if will run before the normal splunk service and run a script that use the splunk offline procedure 
      # in order to tell the CM to replicate before the instance is completely terminated
      # we dont want to run this each time the service stop for cases such as rolling restart or system reboot
      read -d '' SYSAWSTERMINATE << EOF
[Unit]
Description=Splunk idx terminate helper Service
Before=poweroff.target shutdown.target halt.target
# so that it will stop before splunk systemd unit stop
Wants=splunk.target
Requires=network-online.target network.target sshd.service

[Service]
KillMode=none
ExecStart=/bin/true
#ExecStop=/bin/bash -c "/usr/bin/su - splunk -s /bin/bash -c \'/usr/local/bin/splunkconf-aws-terminate-idx\'";true
ExecStop=/bin/bash /usr/local/bin/splunkconf-aws-terminate-idx.sh
RemainAfterExit=yes
Type=oneshot
# stop after 15 min anyway as a safeguard, the shell script should use a timeout below that value
TimeoutStopSec=15min
User=splunk
Group=splunk

[Install]
WantedBy=multi-user.target

EOF

      echo "$SYSAWSTERMINATE" > /etc/systemd/system/aws-terminate-helper.service
      read -d '' SPLUNKOFFLINE << EOF
#!/bin/bash

# Matthieu Araman, Splunk
# 20200625 initial version
# 20200626 typos fix in log
# 20210131 typos fix and deployment inlined
# 20210216 fix escaping variable when inlined

SPLUNK_HOME="/opt/splunk"
LOGFILE="\${SPLUNK_HOME}/var/log/splunk/splunkconf-backup.log"

SCRIPTNAME="splunkconf-aws-terminate-idx"

# value need to be under the timeout in service (600s)
DECOMISSION_NODE_TIMEOUT=530

###### function definition

function echo_log_ext {
    LANG=C
    #NOW=(date "+%Y/%m/%d %H:%M:%S")
    NOW=(date)
    echo `$NOW`" \${SCRIPTNAME} \$1 " >> \$LOGFILE
}


function echo_log {
    echo_log_ext  "INFO id=\$ID \$1"
}

function warn_log {
    echo_log_ext  "WARN id=\$ID \$1"
}

function fail_log {
    echo_log_ext  "FAIL id=\$ID \$1"
}


# this script should run as splunk
echo_log "checking that we were not launched by root for security reasons"
# check that we are not launched by root
if [[ \$EUID -eq 0 ]]; then
   fail_log "Exiting ! This script must be run as splunk user, not root !"
   exit 1
fi

echo_log "\$SCRIPTNAME launched, this instance is  being shutdown or terminated, so we will call splunk offline command in a few seconds so that the cluster reassign primaries, replicate the remaining buckets hopefully before splunk stop (and searches may have somne time to complete)"
# let some time for splunk to index and replicate before kill
sleep 10

# note with smartstore, numrber of buckets to resync is reduced, decreasing impact and time
# this command rely on proper systemd + policykit configuration to be in place

\${SPLUNK_HOME}/bin/splunk offline --enforce-counts  --decommission_node_force_timeout \${DECOMISSION_NODE_TIMEOUT}

EOF
      echo "$SPLUNKOFFLINE" > /usr/local/bin/splunkconf-aws-terminate-idx.sh
      # restore permissions in case tar broke them (systemd would complain)
      chown root. /usr/local/bin
      chmod 755 /usr/local/bin
      systemctl daemon-reload
      systemctl enable aws-terminate-helper.service
      chown root.${splunkgroup} ${localrootscriptdir}/splunkconf-aws-terminate-idx.sh
      chmod 550 ${localrootscriptdir}/splunkconf-aws-terminate-idx.sh
    fi   
  else
    echo "other generic instance type( uf,...) , we wont change anything to avoid duplicate entries, using the name provided by aws"
  fi

  ## deploy or update the backup scripts
  #aws s3 cp ${remoteinstalldir}/install/splunkconf-backup-s3.tar.gz ${localbackupdir} --quiet
  #tar -C "/" -xzf ${localbackupdir}/splunkconf-backup-s3.tar.gz 

  # need user seed when 7.1

  # user-seed.config
  echo "remote : ${remoteinstalldir}/user-seed.conf" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/user-seed.conf ${localinstalldir}
  # copying to right place
  # FIXME : more  logic here
  if [ -e "${localinstalldir}/user-seed.conf" ]; then
    cp ${localinstalldir}/user-seed.conf ${SPLUNK_HOME}/etc/system/local/
    chown -R ${usersplunk}. ${SPLUNK_HOME}
  else
    echo "user-seed not provided, no need to deploy"
  fi

fi # if not upgrade

echo "#****************************************** CONF/BACKUPS ADAPTATION VIA TAGS ***********************************"
# updating master_uri or manager_uri (needed when reusing backup from one env to another)
# this is for indexers, search heads, mc ,.... (we will detect if the conf is present)
if [ -z ${splunktargetcm+x} ]; then
  echo "tag splunktargetcm not set, please consider setting it up (for example to splunk-cm) to be used as master_uri/manager_uri for cm (by default the current config will be kept as is"
  #disabled by default to require tags or do nothing 
  #  splunktargetcm="splunk-cm"
else 
  echo "tag splunktargetcm is set to $splunktargetcm and will be used as the short name for master_uri/manager_uri" >> /var/log/splunkconf-cloud-recovery-info.log
fi

if [ -z ${splunkorg+x} ]; then 
  echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
  splunkorg="org"
else 
  echo "using splunkorg=${splunkorg} from instance tags" >> /var/log/splunkconf-cloud-recovery-info.log
fi
# splunkdnszone used for updating route53 when apropriate
if [ -z ${splunkdnszone+x} ]; then 
    echo "instance tags is not defining splunkdnszone. Some features will be disabled such as updating master_uri/manager_uri in a cluster env ! Please consider adding splunkdnszone tag" >> /var/log/splunkconf-cloud-recovery-info.log
else
  if [ -z ${splunktargetcm+x} ]; then
    echo "instance tags is not defining splunktargetcm. Some features will be disabled such as updating master_uri/manager_uri in a cluster env ! Please consider adding splunktargetcm tag" >> /var/log/splunkconf-cloud-recovery-info.log
  else 
    echo "using splunkdnszone ${splunkdnszone} from instance tags (master_uri/manager_uri) manager_uri=https://${splunktargetcm}.${splunkdnszone}:8089 (cm name or a cname alias to it)  " >> /var/log/splunkconf-cloud-recovery-info.log
    # assuming PS base apps are used   (indexer and search)
    # we dont want to update master_uri=clustermaster:indexer1 in cluster_search_base
    find ${SPLUNK_HOME} -wholename "*cluster_search_base/local/server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*https.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    find ${SPLUNK_HOME} -wholename "*cluster_search_base/local/server.conf" -exec grep -l manager_uri {} \; -exec sed -i -e "s%^.*manager_uri.*=.*https.*$%manager_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    find ${SPLUNK_HOME} -wholename "*cluster_indexer_base/local/server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    find ${SPLUNK_HOME} -wholename "*cluster_indexer_base/local/server.conf" -exec grep -l manager_uri {} \; -exec sed -i -e "s%^.*manager_uri.*=.*$%manager_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    # for idx discovery
    find ${SPLUNK_HOME} -wholename "${splunkorg}*/outputs.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    find ${SPLUNK_HOME} -wholename "${splunkorg}*/outputs.conf" -exec grep -l manager_uri {} \; -exec sed -i -e "s%^.*manager_uri.*=.*$%manager_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    # it is also used for indexer discovery in outputs.conf
    find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/deployment-apps ${SPLUNK_HOME}/etc/shcluster/apps ${SPLUNK_HOME}/etc/system/local  -name "outputs.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/deployment-apps ${SPLUNK_HOME}/etc/shcluster/apps ${SPLUNK_HOME}/etc/system/local  -name "outputs.conf" -exec grep -l manager_uri {} \; -exec sed -i -e "s%^.*manager_uri.*=.*$%manager_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \; 
    # $$ echo "master_uri replaced" || echo "master_uri not replaced"
    # this wont work in that form because master_uri could be the one for license find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/system/local -name "server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://${splunktargetcm}.${splunkdnszone}:8089%" {} \;  $$ echo "master_uri replaced" || echo "master_uri not replaced"
  fi
  # DS case (targetUri)
  if [ -z ${splunktargetds+x} ]; then
    #echo "tag splunktargetds not set, will use splunk-ds as the short name for targertUri" >> /var/log/splunkconf-cloud-recovery-info.log
    echo "tag splunktargetds not set, doing nothing" >> /var/log/splunkconf-cloud-recovery-info.log
    #splunktargetds="splunk-ds"
  else
    echo "tag splunktargetds is set to $splunktargetds and will be used as the short name for deploymentclient config to ref the DS" >> /var/log/splunkconf-cloud-recovery-info.log
    echo "using splunkdnszone ${splunkdnszone} from instance tags (targetUri) targetUri=${splunktargetds}.${splunkdnszone}:8089 (ds name or a cname alias to it)  " >> /var/log/splunkconf-cloud-recovery-info.log
    find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/system/local -name "deploymentclient.conf" -exec grep -l targetUri {} \; -exec sed -i -e "s%^.*targetUri.*=.*$%targetUri=${splunktargetds}.${splunkdnszone}:8089%" {} \; 
  # $$ echo "targetUri replaced" || echo "targetUri not replaced"
  fi
  # fixme add shc deployer case here
fi

if [ -z ${splunktargetenv+x} ]; then
  echo "splunktargetenv tag not set , please consider adding it if you want to automatically modify login banner for a test env using prod backups" >> /var/log/splunkconf-cloud-recovery-info.log
else 
  echo "trying to replace login_content for splunktargetenv=$splunktargetenv"
  find ${SPLUNK_HOME}/etc/apps ${SPLUNK_HOME}/etc/system/local -name "web.conf" -exec grep -l login_content {} \; -exec sed -i -e "s%^.*login_content.*=.*$%login_content = This is a <b>$splunktargetenv server</b>.<br>Authorized access only%" {} \;  && echo "login_content replaced" || echo "login_content not replaced"
  envhelperscript="splunktargetenv-for${splunktargetenv}.sh"
  echo "remote : ${remoteinstalldir}/${envhelperscript}" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/${envhelperscript}  ${localinstalldir}
  if [ -e "${localinstalldir}/$envhelperscript" ]; then
    chown ${usersplunk}. ${localinstalldir}/$envhelperscript
    chmod u+rx  ${localinstalldir}/$envhelperscript
    # give back files 
    chown -R ${usersplunk}. ${SPLUNK_HOME}
    echo "launching $envhelperscript as splunk, please make sure you implement logic inside if needed to restrict to some instances only"  >> /var/log/splunkconf-cloud-recovery-info.log
    su - ${usersplunk} -c "${localinstalldir}/$envhelperscript"
  else
    echo "$envhelperscript not present in ${remoteinstalldir}/${envhelperscript}, please consider creating it if you need to customize things specifically for this ${splunktargetenv} env" >> /var/log/splunkconf-cloud-recovery-info.log  >> /var/log/splunkconf-cloud-recovery-info.log
  fi
fi

## moved with complete logic to splunkconf-init
#${SPLUNK_HOME}/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user splunk -systemd-managed 0 || ${SPLUNK_HOME}/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user splunk
##${SPLUNK_HOME}/bin/splunk enable boot-start -user splunk --accept-license
## if run first time, because we haven't started splunk yet, this risk writing some files as root so lets give them back to splunk
#chown -R ${usersplunk}. ${SPLUNK_HOME}

## redeploy system tuning as enable boot start may have overwritten files
##tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz

echo "#********************************************SC4S INSTALLATIONi (if selected) *****************************"

if [ "${splunktargetbinary}" == "sc4s" ]; then
  docker volume create splunk-sc4s-var
  mkdir -p /opt/sc4s/local
  mkdir -p /opt/sc4s/archive
  mkdir -p /opt/sc4s/tls
  get_object ${remoteinstalldir}/sc4s.service /lib/systemd/system/
  get_object ${remoteinstalldir}/env_file /opt/sc4s
  systemctl daemon-reload
  systemctl enable sc4s
  systemctl start sc4s
  systemctl status sc4s
fi
echo "#********************************************SPLUNK BINARY INSTALLATION*****************************"
if [ "$INSTALLMODE" = "tgz" ]; then
  echo "disabling rpm install as install via tar"
  mkdir -p $SPLUNK_HOME
  cd $SPLUNK_HOME
  splunktar="${localinstalldir}/${splbinary}"
  # we need to install here in order to get btool working which is needed for tag replacement
  tar --strip-components=1 -zxvf $splunktar
else
  echo "installing/upgrading splunk via RPM using ${splbinary}" >> /var/log/splunkconf-cloud-recovery-info.log
  RES=1
  COUNT=0
  # we need to repeat in case rpm lock taken as it will fail then later on other failures will occur like not having polkit ....
  # unfortunately if ssm is installed something from ssm configured at start may try install software in // breaking us....
  until [[ $COUNT -gt 10 ]] || [[ $RES -eq 0 ]]
  do
    # install or upgrade
    rpm -Uvh ${localinstalldir}/${splbinary}
    #rpm -K "${localinstalldir}/${splbinary}" || (echo "ERROR : GPG Check failed, splunk rpm file may be corrupted, please check and relaunch\n";exit 1)
    RES=$? 
    ((COUNT++))
    if [[ $RES -ne 0 ]]; then
      if [[ $COUNT -gt 5 ]]; then
        df -h
        echo "ERROR : rpm fail after multiple tries, please investigate and relaunch, exiting\n"
        exit 1
      else
        echo "ERROR : rpm command failed, may be temporary du to rpm lock, will retry (COUNT=$COUNT)"
        sleep 5 
      fi
    fi
  done
fi

# give back files (see RN)
chown -R ${usersplunk}. ${SPLUNK_HOME}

echo "#************************************MORE TAG REPLACEMENT IF NEEDED********************************"
tag_replacement

## using updated init script with su - splunk
#echo "remote : ${remoteinstalldir}/splunkenterprise-init.tar.gz" >> /var/log/splunkconf-cloud-recovery-info.log
#aws s3 cp ${remoteinstalldir}/splunkenterprise-init.tar.gz ${localinstalldir} --quiet
#tar -C "/" -xzf ${localinstalldir}/splunkenterprise-init.tar.gz 

# updating splunkconf-backup app from s3
# important : version on s3 should be up2date as it is prioritary over backups and other content
# only if it is not a indexer 
if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
  get_object ${remoteinstallsplunkconfbackup} ${localinstalldir}
  if [ -e "${localinstalldir}/splunkconf-backup.tar.gz" ]; then
    if [ -e "${SPLUNK_HOME}/etc/apps/splunkconf-backup" ]; then
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/apps/" -zcf ${localinstalldir}/splunkconf-backup-beforeupdate-${TODAY}.tar.gz ./splunkconf-backup
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/apps/splunkconf-backup" -delete
    else
     echo "no previous splunkconf-backup app deployed, no need to clean up before deploying app"
    fi
    # Note : old versions used relative path, new version without du to splunkbase packaging requirement
    tar -C "${SPLUNK_HOME}/etc/apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz 
    # removing old version for upgrade case 
    if [ -e "/etc/crond.d/splunkbackup.cron" ]; then
      rm -f /etc/crond.d/splunkbackup.cron
    fi
    if [ -e "${SPLUNK_HOME}/scripts/splunconf-backup" ]; then
      echo "renaming old legacy splunkconf-back from scripts dir to prevent usage of a old version in // of updated one"
      mv ${SPLUNK_HOME}/scripts/splunconf-backup ${SPLUNK_HOME}/scripts/splunconf-backup-disabled
    fi
    echo "splunkconfbackup found on s3 at ${remoteinstallsplunkconfbackup} and updated from it"
    # we may be on a DS then we need to also update it
    if [ -e "${SPLUNK_HOME}/etc/deployment-apps/splunkconf-backup" ]; then
      echo "updating splunkconf-backup on a DS"
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -zcf ${localinstalldir}/splunkconf-backup-${TODAY}-fromdeploymentapps.tar.gz ./splunkconf-backup
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/deployment-apps/splunkconf-backup" -delete
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz
    fi
    # we may be on a SHC deployer then we need to also update it
    if [ -e "${SPLUNK_HOME}/etc/shcluster/apps/splunkconf-backup" ]; then
      echo "updating splunkconf-backup on a SHC deployer"
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/shcluster/apps" -zcf ${localinstalldir}/splunkconf-backup-${TODAY}-fromshclusterapps.tar.gz
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/shcluster/apps/splunkconf-backup" -delete
      tar -C "${SPLUNK_HOME}/etc/shcluster/apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz
    fi
  else 
    echo "ATTENTION : splunkconf-backup not found on s3 so will not deploy it now. consider adding it at ${remoteinstallsplunkconfbackup} for autonatic deployment"
  fi
fi

if [[ "${instancename}" =~ ds ]]; then
  echo "instance is a deployment server, deploying ds serverclass reload script"
  DSRELOAD="splunkconf-ds-reload.sh"
  mkdir -p ${localscriptdir}
  chown $usersplunk.$groupsplunk ${localscriptdir}/
  chown $usersplunk.$groupsplunk ${localscriptdir}
  chmod 550  ${localscriptdir}
  get_object ${remoteinstalldir}/splunkconf-ds-reload.sh ${localscriptdir}/${DSRELOAD}
  if [ -e "${localscriptdir}/${DSRELOAD}" ]; then
    chown $usersplunk.$groupsplunk ${localscriptdir}/${DSRELOAD}
    chmod 550  ${localscriptdir}/${DSRELOAD}
  fi
fi


echo "#********************************************SPLUNK INITIALISATION*****************************"
# splunk initialization (first time or upgrade)
mkdir -p ${localrootscriptdir}
get_object ${remoteinstalldir}/splunkconf-init.pl ${localrootscriptdir}/

# make it executable
chmod u+x ${localrootscriptdir}/splunkconf-init.pl 

# we need this set to forward it to splunkconf-init
if [ -z ${splunkorg+x} ]; then
  echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-cloud-recovery-info.log
  splunkorg="org"
fi

# if we are a ds and number of ds instances is set , we are multi ds case , otherwise we just deploy like a normal instance
if [[ "${instancename}" =~ ds ]]  && [ ! -z ${splunkdsnb+x} ] && [[ $splunkdsnb -gt 1 ]]; then
  echo "#************************************************ MULI DS **************************************"
  echo "configuring for multi DS" 
  # multi DS here
  # for app inspect 
  if [ $splunkconnectedmode == 1 ] || [ $splunkconnectedmode == 2 ]; then
    yum groupinstall "Development Tools"
    yum install  python3-devel
  fi
  if [ $splunkconnectedmode == 1 ]; then
    pip3 install splunk-appinspect
  fi
  # LB SETUP for multi DS
  get_object ${remoteinstalldir}/splunkconf-ds-lb.sh ${localrootscriptdir}
  if [ ! -e "${localrootscriptdir}/splunkconf-ds-lb.sh" ]; then
    echo " ${localrootscriptdir}/splunkconf-ds-lb.sh doesnt exist, please fix (add file to expected location) and relaunch"
    exit 1
  fi 
  echo "creating DS LB via LVS"
  chown root. ${localrootscriptdir}/splunkconf-ds-lb.sh 
  chmod 750 ${localrootscriptdir}/splunkconf-ds-lb.sh 
  ${localrootscriptdir}/splunkconf-ds-lb.sh 
  echo "creating fake structure and files for splunkconf-backup not to complain and report failures when backuping (as we only car about deployment-apps related stuff)"
  mkdir -p ${SPLUNK_HOME}/etc/master-apps
  mkdir -p ${SPLUNK_HOME}/etc/manager-apps
  mkdir -p ${SPLUNK_HOME}/etc/shcluster
  touch ${SPLUNK_HOME}/etc/passwd
  mkdir -p ${SPLUNK_HOME}/etc/openldap
  touch ${SPLUNK_HOME}/etc/openldap/ldap.conf
  mkdir -p ${SPLUNK_HOME}/etc/users
  touch ${SPLUNK_HOME}/etc/splunk-launch.conf
  touch ${SPLUNK_HOME}/etc/instance.cfg
  touch ${SPLUNK_HOME}/etc/.ui_login
  mkdir -p ${SPLUNK_HOME}/etc/licenses
  touch ${SPLUNK_HOME}/etc/log.cfg
  mkdir -p ${SPLUNK_HOME}/etc/disabled-apps
  mkdir -p ${SPLUNK_HOME}/var/run/splunk
  chown -R ${usersplunk}. ${SPLUNK_HOME}
  NBINSTANCES=4
  if [ -z ${splunkdsnb+x} ]; then
    echo "multi ds mode used but splunkdsnb tag not defined, using 4 instances (default)"
  else
    NBINSTANCES=${splunkdsnb}
    if (( $NBINSTANCES > 0 )); then 
      echo "set NBINSTANCES=${splunkdsnb}"
   else
      echo " ATTENTION ERROR splunkdsnb is not numeric or contain invalid value, switching back to default 4 instances, please investigate and correct tag (remove extra spaces for example)" 
     NBINSTANCES=4
   fi
  fi
  #NBINSTANCES=1
  echo "setting up Splunk (boot-start, license, init tuning, upgrade prompt if applicable...) with splunkconf-init for dsinabox with $NBINSTANCES " >> /var/log/splunkconf-cloud-recovery-info.log
  # no need to pass option, it will default to systemd + /opt/splunk + splunk user
  for ((i=1;i<=$NBINSTANCES;i++)); 
  do 
    SERVICENAME="${instancename}_$i"
    echo "setting up instance $i/$NBINSTANCES with SERVICENAME=$SERVICENAME"
    ${localrootscriptdir}/splunkconf-init.pl --no-prompt -u=${splunkuser} -g=${splunkgroup} --splunkorg=$splunkorg --service-name=$SERVICENAME --splunkrole=ds --instancenumber=$i --splunktar=${localinstalldir}/${splbinary} ${SPLUNKINITOPTIONS}
  done
elif [ "$INSTALLMODE" = "tgz" ]; then
  echo "setting up Splunk (boot-start, license, init tuning, upgrade prompt if applicable...) with splunkconf-init in tar mode (please use RPM when possible)" >> /var/log/splunkconf-cloud-recovery-info.log
  # no need to pass option, it will default to systemd + /opt/splunk + splunk user
  ${localrootscriptdir}/splunkconf-init.pl --no-prompt -u=${splunkuser} -g=${splunkgroup} --splunkorg=$splunkorg --splunkrole=$splunkmode --splunktar=${localinstalldir}/${splbinary} ${SPLUNKINITOPTIONS} 
else
  echo "setting up Splunk (boot-start, license, init tuning, upgrade prompt if applicable...) with splunkconf-init" >> /var/log/splunkconf-cloud-recovery-info.log
  # no need to pass option, it will default to systemd + /opt/splunk + splunk user
  ${localrootscriptdir}/splunkconf-init.pl --no-prompt  -u=${splunkuser} -g=${splunkgroup} --splunkorg=$splunkorg  --splunkrole=$splunkmode ${SPLUNKINITOPTIONS}
fi


echo "localrootscriptdir ${localrootscriptdir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
ls ${localrootscriptdir} >> /var/log/splunkconf-cloud-recovery-info.log

echo "localinstalldir ${localinstalldir}  contains" >> /var/log/splunkconf-cloud-recovery-info.log
ls ${localinstalldir} >> /var/log/splunkconf-cloud-recovery-info.log

if [ "$MODE" != "upgrade" ]; then 
  # local upgrade script (we dont do this in upgrade mode as overwriting our own script already being run could be problematic)
  echo "remote : ${remoteinstalldir}/splunkconf-upgrade-local.sh" >> /var/log/splunkconf-cloud-recovery-info.log
  get_object ${remoteinstalldir}/splunkconf-upgrade-local.sh  ${localrootscriptdir}/
  chown root. ${localrootscriptdir}/splunkconf-upgrade-local.sh  
  chmod 700 ${localrootscriptdir}/splunkconf-upgrade-local.sh  
  get_object ${remoteinstalldir}/splunkconf-upgrade-local-precheck.sh  ${localrootscriptdir}/
  chown root. ${localrootscriptdir}/splunkconf-upgrade-local-precheck.sh  
  chmod 700 ${localrootscriptdir}/splunkconf-upgrade-local-precheck.sh  
  get_object ${remoteinstalldir}/splunkconf-upgrade-local-setsplunktargetbinary.sh  ${localrootscriptdir}/
  chown root. ${localrootscriptdir}/splunkconf-upgrade-local-setsplunktargetbinary.sh
  chmod 700 ${localrootscriptdir}/splunkconf-upgrade-local-setsplunktargetbinary.sh
  # if there is a dns update to do , we have put the script and it has been redeployed as part of the restore above
  # so we can run it now
  # the content will be different depending on the instance
  #if [ -e /opt/splunk/scripts/aws_dns_update/dns_update.sh ]; then
  #  /opt/splunk/scripts/aws_dns_update/dns_update.sh
  #fi
  # this is restored by backup scripts (initial one) but only present if the admin decided it is necessary (ie for example to update dns for some instances)
  # if needed this is calling other scripts
  if [ -e ${localrootscriptdir}/aws-postinstall.sh ]; then
    echo "lauching aws-postinstall in ${localrootscriptdir}/aws-postinstall.sh" >> /var/log/splunkconf-cloud-recovery-info.log
    chown root. ${localrootscriptdir}/aws-postinstall.sh
    chmod u+x ${localrootscriptdir}/aws-postinstall.sh
    ${localrootscriptdir}/aws-postinstall.sh
    # note if needed , this will transparently call other scripts deployed in the initial backup so that recovery script can stay generic
  fi
fi # if not upgrade

# ***********************************  SETUP BACKUP SERVICE AT SHUTDOWN FOR NON IDX-iuf/iuh farms  ****************************
# better to do this after setup as the dependency for services will exist
if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
  echo "specific instance name : setting up backup services for shutddow"
  if [ $SYSVER -eq "6" ]; then
    echo "running non systemd os , we wont add a custom service to terminate"
  else
    echo "running systemd os , adding backup terminate services"
    # this service is ran at stop when a instance is terminated cleanly 
    # we dont want to run this each time the service stop for cases such as rolling restart or system reboot
    read -d '' SYSTERMINATE << EOF
[Unit]
Description=splunkconf-backup etc terminate helper Service
Before=poweroff.target shutdown.target halt.target
# so that it will stop before splunk systemd unit stop
Wants=splunk.target
Requires=network-online.target network.target sshd.service

[Service]
WorkingDirectory=$SPLUNK_HOME/etc/apps
KillMode=none
ExecStart=/bin/true
#ExecStop=/bin/bash -c "/usr/bin/su - splunk -s /bin/bash -c \'/usr/local/bin/splunkconf-aws-terminate-idx\'";true
ExecStop=/bin/bash $SPLUNK_HOME/etc/apps/splunkconf-backup/bin/splunkconf-backup-etc.sh
RemainAfterExit=yes
Type=oneshot
# stop after 15 min anyway as a safeguard, the shell script should use a timeout below that value
TimeoutStopSec=15min
User=splunk
Group=splunk

[Install]
WantedBy=multi-user.target

EOF
    echo "$SYSTERMINATE" > /etc/systemd/system/splunkconf-backup-etc-terminate-helper.service
    systemctl daemon-reload
    systemctl enable splunkconf-backup-etc-terminate-helper.service

    # here -> more stuff for other backups
  fi
fi

# ***********************************  ADDITIONAL POST SETUP ACTIONS   ****************************
# always download even in upgrade mode

# create script dir if not exist and give it to splunk user
mkdir -p ${localscriptdir}
chown ${usersplunk}. ${localscriptdir}
chmod 750 ${localscriptdir}


# script run as splunk
# this script is to be used on es sh , it will download ES installation files and script
get_object ${remoteinstalldir}/splunkconf-prepare-es-from-s3.sh  ${localscriptdir}/
if [ -e ${localscriptdir}/splunkconf-prepare-es-from-s3.sh ]; then
  chown ${usersplunk}. ${localscriptdir}/splunkconf-prepare-es-from-s3.sh
  chmod 700 ${localscriptdir}/splunkconf-prepare-es-from-s3.sh
else
  echo "${remoteinstalldir}/splunkconf-prepare-es-from-s3.sh not existing, please consider add it if willing to deploy ES" 
fi

# *********************************** WORKER ****************************************************
# on all hosts 
if [ $splunkconnectedmode == 1 ]; then
  pip install boto3
else 
  echo "INFO: boto3 deployment via pip disabled du to splunkconnectedmode=$splunkconnectedmode"
fi
# only on worker
if [[ $splunkenableworker == 1 ]]; then
  echo "INFO: worker role : getting ansible files"  
  get_object ${remoteinstalldir}/ansible/getmycredentials.sh ${localscriptdir}
  chown ${usersplunk}. ${localscriptdir}/getmycredentials.sh
  chmod 700 ${localscriptdir}/getmycredentials.sh
  remoteworkerdir=${remoteinstalldir}/ansible
  # ansible template deployed in scripts dir
  localworkerdir=${localscriptdir}
  FILELIST="ansible_deploysplunkansible_tf.yml"
  echo "Getting ${FILELIST} which is used to download Splunk ansible from github"
  for fi in $FILELIST
  do
    get_object ${remoteworkerdir}/${fi} ${localworkerdir}/${fi}
    if [ -e "${localworkerdir}/${fi}" ]; then
      echo "INFO: file ${localworkerdir}/${fi} deployed from ${remoteworkerdir}/${fi}" 
      chown ${usersplunk}. ${localworkerdir}/${fi}
      chmod 600 ${localworkerdir}/${fi}
    else 
      echo "WARNING : file ${localworkerdir}/${fi} not FOUND, please check as it should have been deployed via TF (remote location = ${remoteworkerdir}/${fi})"
    fi    
  done
  # ansible template deployed in ansible dir
  localworkerdir=${localscriptdir}/splunk-ansible-develop
  echo "INFO: creating ${localworkerdir} as needed and giving to ${usersplunk} user (we may not have yet deployed splunk ansible at his point so the dir would need to be created) "
  mkdir -p ${localworkerdir}
  chown ${usersplunk}. ${localworkerdir}
  FILELIST="ansible_jinja_tf.yml ansible_jinja_byhost_tf.yml splunk_ansible_inventory_create.yml"
  for fi in $FILELIST
  do
    get_object ${remoteworkerdir}/${fi} ${localworkerdir}/${fi}
    if [ -e "${localworkerdir}/${fi}" ]; then
      echo "INFO: file ${localworkerdir}/${fi} deployed from ${remoteworkerdir}/${fi}" 
      chown ${usersplunk}. ${localworkerdir}/${fi}
      chmod 600 ${localworkerdir}/${fi}
    else
      echo "WARNING : file ${localworkerdir}/${fi} not FOUND, please check as it should have been deployed via TF (remote location = ${remoteworkerdir}/${fi})"
    fi
  done
  # jinja j2 
  mkdir -p ${localscriptdir}/j2
  chown ${usersplunk}. ${localscriptdir}/j2
  localworkerdir=${localscriptdir}/j2
  remoteworkerdir=${remoteinstalldir}/ansible/j2
  FILELIST="splunk_ansible_inventory_template.j2"
  for fi in $FILELIST
  do
    get_object ${remoteworkerdir}/${fi} ${localworkerdir}
    if [ -e "${localworkerdir}/${fi}" ]; then
      echo "INFO: file ${localworkerdir}/${fi} deployed from ${remoteworkerdir}/${fi}" 
      chown ${usersplunk}. ${localworkerdir}/${fi}
      chmod 600 ${localworkerdir}/${fi}
    else
      echo "WARNING : file ${localworkerdir}/${fi} not FOUND, please check as it should have been deployed via TF (remote location = ${remoteworkerdir}/${fi})"
    fi
  done
  # workaround for AL2023 which not yet allow ansible via yum 
  if [ $splunkconnectedmode == 1 ]; then
    pip install ansible
  else 
    echo "not deploying ansible du to splunkconnectedmode setting ($splunkconnectedmode), make sure you have deployed it yourself or change setting"
  fi
  echo "building inventory file with ansible"
  su - ${usersplunk} -c "cd scripts/splunk-ansible-develop;ansible-playbook splunk_ansible_inventory_create.yml -i 127.0.0.1," 
  echo "deploying splunk ansible from github"
  # playbook is in scripts folder here
  su - ${usersplunk} -c "cd scripts;ansible-playbook ansible_deploysplunkansible_tf.yml -i 127.0.0.1," 
  # deploying runner
  su - ${usersplunk} -c "mkdir actions-runner && cd actions-runner;curl --silent --show-error -o actions-runner-linux-x64-2.305.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.305.0/actions-runner-linux-x64-2.305.0.tar.gz;tar xzf ./actions-runner-linux-x64-2.305.0.tar.gz"
  patrunner=`aws ssm get-parameter --name splunkpatjinjarunner --query "Parameter.Value" --output text --region $REGION`
  echo "DEBUG: patrunner=$patrunner"
  #su - ${usersplunk} -c "cd actions-runner;./config.sh --url https://${apprepo} --token ${patrunner} ;nohup ./run.sh &"
fi

# redo tag replacement as btool may not work before splunkconf-init du to splunk not yet initialized 
tag_replacement

if [ -z ${splunkpostextrasyncdir+x} ]; then 
  echo "splunkpostextrasyncdir is unset"
else
  echo "splunkpostextrasyncdir is set to ${splunkpostextrasyncdir}"
  mkdir /var/lib/postinstall
  cd /var/lib/postinstall
  # FIXME add cloudtype support here
  aws s3 sync --no-progress --no-paginate ${splunkpostextrasyncdir} .  
  if [ -z ${splunkpostextracommand+x} ]; then 
    echo "splunkpostextracommand is unset"
  else
    echo "splunkpostextracommand is set running to run command ${splunkpostextracommand} in directory /var/lib/postinstall"
    bash ./${splunkpostextracommand}
  fi
fi


TODAY=`date '+%Y%m%d-%H%M_%u'`;
#NOW=`(date "+%Y/%m/%d %H:%M:%S")`
echo "INFO: ${TODAY} splunkconf-cloud-recovery.sh (version=${VERSION}) end of script run" >> /var/log/splunkconf-cloud-recovery-info.log
echo "#************************************* END ***************************************"
