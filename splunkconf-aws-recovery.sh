#!/bin/bash -x 
exec > /var/log/splunkconf-aws-recovery-error.log 2>&1

# Matthieu Araman
# Splunk
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
# 20191001 add tuned isntallation for aws2 case (to be more rh like)
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

VERSION="20201010b"

TODAY=`date '+%Y%m%d-%H%M_%u'`;
echo "${TODAY} running splunkconf-aws-recovery.sh with ${VERSION} version" >> /var/log/splunkconf-aws-recovery-info.log

# dont break script on error as we rely on tests for this
set +e

# commented as in user data
#yum update -y



if [ $# -eq 1 ]; then
  MODE=$1
  echo "Your command line contains 1 argument $MODE" >> /var/log/splunkconf-aws-recovery-info.log
  if [ "$MODE" == "upgrade" ]; then 
    echo "upgrade mode" >> /var/log/splunkconf-aws-recovery-info.log
  else
    echo "unknown parameter, ignoring" >> /var/log/splunkconf-aws-recovery-info.log
    MODE="0"
  fi
elif [ $# -gt 1 ]; then
  echo "Your command line contains too many ($#) arguments. Ignoring the extra data" >> /var/log/splunkconf-aws-recovery-info.log
  MODE=$1
  if [ "$MODE" == "upgrade" ]; then 
    echo "upgrade mode" >> /var/log/splunkconf-aws-recovery-info.log
  else
    echo "unknown parameter, ignoring" >> /var/log/splunkconf-aws-recovery-info.log
    MODE="0"
  fi
else
  echo "No arguments given, assuming launched by user data" >> /var/log/splunkconf-aws-recovery-info.log
  MODE="0"
fi

echo "running with MODE=${MODE}" >> /var/log/splunkconf-aws-recovery-info.log

# setting variables

SPLUNK_HOME="/opt/splunk"
# we get most var dynamically from ec2 tags associated to instance

# getting tokens and writting to /etc/instance-tags

# setting up token (IMDSv2)
TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
# lets get the s3splunkinstall from instance tags
INSTANCE_ID=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id `
REGION=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//' `

# we put store tags in /etc/instance-tags -> we will use this later on
aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/' | grep -E "^splunk" > /etc/instance-tags
if grep -qi splunkinstanceType /etc/instance-tags
then
  # note : filtering by splunk prefix allow to avoid import extra customers tags that could impact scripts
  echo "filtering tags with splunk prefix for instance tags" >> /var/log/splunkconf-aws-recovery-info.log
else
  echo "splunk prefixed tags not found, reverting to full tag inclusion" >> /var/log/splunkconf-aws-recovery-info.log
  aws ec2 describe-tags --region $REGION --filter "Name=resource-id,Values=$INSTANCE_ID" --output=text | sed -r 's/TAGS\t(.*)\t.*\t.*\t(.*)/\1="\2"/'  > /etc/instance-tags
fi
chmod 644 /etc/instance-tags

# including the tags for use in this script
. /etc/instance-tags

# instance type
if [ -z ${splunkinstanceType+x} ]; then 
  if [ -z ${instanceType+x} ]; then
    echo "instance tags are not correctly set (splunkinstanceType). I dont know what kind of instance I am ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-aws-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunkinstanceType)" >> /var/log/splunkconf-aws-recovery-info.log
    splunkinstanceType=$instanceType
  fi
else 
  echo "using splunkinstanceType from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
# will become the name when not a indexer, see below
instancename=$splunkinstanceType 
echo "instance type is ${instancename}" >> /var/log/splunkconf-aws-recovery-info.log

echo "SPLUNK_HOME is ${SPLUNK_HOME}" >> /var/log/splunkconf-aws-recovery-info.log

# splunk s3 install bucket
if [ -z ${splunks3installbucket+x} ]; then 
  if [ -z ${s3installbucket+x} ]; then
    echo "instance tags are not correctly set (splunks3installbucket). I dont know where to get the installation files ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-aws-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunks3installbucket)" >> /var/log/splunkconf-aws-recovery-info.log
    splunks3installbucket=$s3installbucket
  fi
else 
  echo "using splunks3installbucket from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
echo "splunks3installbucket is ${splunks3installbucket}" >> /var/log/splunkconf-aws-recovery-info.log

# splunk s3 backup bucket
if [ -z ${splunks3backupbucket+x} ]; then 
  if [ -z ${s3backupbucket+x} ]; then
    echo "instance tags are not correctly set (splunks3backupbucket). I dont know where to get the backup files ! Please correct and relaunch. Exiting" >> /var/log/splunkconf-aws-recovery-info.log
    exit 1
  else
    echo "legacy tags used, please update instance tags to use splunk prefix (splunks3backupbucket)" >> /var/log/splunkconf-aws-recovery-info.log
    splunks3backupbucket=$s3backupbucket
  fi
else 
  echo "using splunks3backupbucket from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
echo "splunks3backupbucket is ${splunks3backupbucket}" >> /var/log/splunkconf-aws-recovery-info.log

# splunk org prefix for base apps
if [ -z ${splunkorg+x} ]; then 
    echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps ! Please add splunkorg tag" >> /var/log/splunkconf-aws-recovery-info.log
    #we can continue as we will just do nothing, ok for legacy mode  
    #exit 1
else 
  echo "using splunkorg from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
echo "splunkorg is ${splunkorg}" >> /var/log/splunkconf-aws-recovery-info.log

# splunkawsdnszone used for updating route53 when apropriate
if [ -z ${splunkawsdnszone+x} ]; then 
    echo "instance tags are not correctly set (splunkawsdnszone). I dont know splunkawsdnszone to use for route53 ! Please add splunkawsdnszone tag" >> /var/log/splunkconf-aws-recovery-info.log
    #we can continue as we will just do nothing but obviously route53 update will fail if this is needed for this instance
    #exit 1
else 
  echo "using splunkawsdnszone from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
echo "splunkawsdnszone is ${splunkawsdnszone}" >> /var/log/splunkconf-aws-recovery-info.log

remotebackupdir="s3://${splunks3backupbucket}/splunkconf-backup/${instancename}"
localbackupdir="${SPLUNK_HOME}/var/backups"
SPLUNK_DB="${SPLUNK_HOME}/var/lib/splunk"
localkvdumpbackupdir="${SPLUNK_DB}/kvstorebackup/"
remoteinstalldir="s3://${splunks3installbucket}/install"
remoteinstallsplunkconfbackup="${remoteinstalldir}/apps/splunkconf-backup.tar.gz"
localinstalldir="${SPLUNK_HOME}/var/install"
remotepackagedir="s3://${splunks3installbucket}/packaged/${instancename}"
localrootscriptdir="/usr/local/bin"
# by default try to restore backups
# we will disable if indexer detected as not needed
RESTORECONFBACKUP=1

# manually create the splunk user so that it will exist for next step   
useradd --home-dir ${SPLUNK_HOME} --comment "Splunk Server" splunk --shell /bin/bash 

# localbackupdir creation
mkdir -p ${localbackupdir}
chown splunk. ${localbackupdir}

mkdir -p ${localinstalldir}
chown splunk. ${localinstalldir}

if [ "$MODE" != "upgrade" ]; then 


  # swap partition creation
  # IMPORTAMT : please emake sure we have really swap available so we can resist peak and reduce OOM risk
  # need at least on sh, idx but also good idea on other roles such as cm
  # safe and arbitrary figure 100G (0.1T) but you can adapt it to your spec and workload
  # obviously this is just a part of strategy about ressource management
  # and you should not swap all time
  #mkswap /dev/sdc
  #echo "/dev/sdc       none    swap    sw  0       0" >> /etc/fstab
  #swapon /dev/sdc
  # end of swap creation
  # if idx
  if [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    #****************************FIXME : REPLACE HERE OR CALL THE NEW PARTITION CODE*********************
    echo "indexer -> configuring additional partition(s)" >> /var/log/splunkconf-aws-recovery-info.log
    RESTORECONFBACKUP=0
    DEVNUM=1

    yum install -y nvme-cli lvm2 >> /var/log/splunkconf-aws-recovery-info.log

    # let try to find if we have ephemeral storage
    INSTANCELIST=`nvme list | grep "Instance Storage" | cut -f 1 -d" "`
    echo "instance storage=$INSTANCELIST" >> /var/log/splunkconf-aws-recovery-info.log

    if [ ${#INSTANCELIST} -lt 5 ]; then
      echo "instance storage not detected" >> /var/log/splunkconf-aws-recovery-info.log
      INSTANCELIST=`nvme list | grep "Amazon Elastic Block Store" | cut -f 1 -d" "`
      OSDEVICE=$INSTANCELIST
      echo "OSDEVICE=${OSDEVICE}" >> /var/log/splunkconf-aws-recovery-info.log
      NBDISK=0
      for e in ${OSDEVICE}; do
        echo "checking EBS volume $e" >> /var/log/splunkconf-aws-recovery-info.log
        RES=`mount | grep $e `
        if [ -z "${RES}" ]; then
          echo "$e not found in mounted devices" >> /var/log/splunkconf-aws-recovery-info.log

          pvcreate $e >> /var/log/splunkconf-aws-recovery-info.log
          # extend or create vg
          echo "adding $e to vgsplunkstorage${DEVNUM} " >> /var/log/splunkconf-aws-recovery-info.log
          vgextend vgsplunkstorage${DEVNUM} $e || vgcreate vgsplunkstorage${DEVNUM} $e >> /var/log/splunkconf-aws-recovery-info.log
          LIST="$LIST $e"
          #pvdisplay
          ((NBDISK=NBDISK+1))
        else
          echo "$e is already mounted, doing nothing" >> /var/log/splunkconf-aws-recovery-info.log
        fi
      done
      echo "LIST=$LIST NBDISK=$NBDISK" >> /var/log/splunkconf-aws-recovery-info.log
      if [ $NBDISK -gt 0 ]; then
        echo "we have $NBDISK disk(s) to configure" >> /var/log/splunkconf-aws-recovery-info.log
        lvcreate --name lvsplunkstorage${DEVNUM} -l100%FREE vgsplunkstorage${DEVNUM} >> /var/log/splunkconf-aws-recovery-info.log
        pvdisplay >> /var/log/splunkconf-aws-recovery-info.log
        vgdisplay >> /var/log/splunkconf-aws-recovery-info.log
        lvdisplay >> /var/log/splunkconf-aws-recovery-info.log
        # note mkfs wont format if the FS is already mounted -> no need to check here
        mkfs.ext4 -L storage1 /dev/vgsplunkstorage1/lvsplunkstorage1 >> /var/log/splunkconf-aws-recovery-info.log
        mkdir -p /data/vol1
        RES=`grep /data/vol1 /etc/fstab`
        #echo " debug F=$RES."
        if [ -z "${RES}" ]; then
          #mount /dev/vgsplunkephemeral1/lvsplunkephemeral1 /data/vol1 && mkdir -p /data/vol1/indexes
          echo "/data/vol1 not found in /etc/fstab, adding it" >> /var/log/splunkconf-aws-recovery-info.log
          echo "/dev/vgsplunkstorage${DEVNUM}//lvsplunkstorage${DEVNUM} /data/vol1 ext4 defaults,nofail 0 2" >> /etc/fstab
          mount /data/vol1
        else
          echo "/data/vol1 is already in /etc/fstab, doing nothing" >> /var/log/splunkconf-aws-recovery-info.log
        fi
      else
        echo "no EBS partition to configure" >> /var/log/splunkconf-aws-recovery-info.log
      fi
      # Note : in case there is just one partition , this will create the dir so that splunk will run
      # for volume management to work in classic mode, it is better to use a distinct partition to not mix manage and unmanaged on the same partition
      echo "creating /data/vol1/indexes and giving to splunk user" >> /var/log/splunkconf-aws-recovery-info.log
      mkdir -p /data/vol1/indexes
      chown -R splunk. /data/vol1/indexes
    else
      #OSDEVICE=$(lsblk -o NAME -n | grep -v '[[:digit:]]' | sed "s/^sd/xvd/g")
      #OSDEVICE=$(lsblk -o NAME -n --nodeps | grep nvme)
      #pvdisplay
      OSDEVICE=$INSTANCELIST
      echo "OSDEVICE=${OSDEVICE}" >> /var/log/splunkconf-aws-recovery-info.log
      for e in ${OSDEVICE}; do
        echo "creating physical volume $e" >> /var/log/splunkconf-aws-recovery-info.log
        pvcreate $e >> /var/log/splunkconf-aws-recovery-info.log
        # extend or create vg
        echo "adding $e to vgsplunkephemeral${DEVNUM}" >> /var/log/splunkconf-aws-recovery-info.log
        vgextend vgsplunkephemeral${DEVNUM} $e || vgcreate vgsplunkephemeral${DEVNUM} $e >> /var/log/splunkconf-aws-recovery-info.log
        LIST="$LIST $e"
        #pvdisplay
      done
      echo "LIST=$LIST" >> /var/log/splunkconf-aws-recovery-info.log
      #vgcreate vgephemeral1 $LIST
      lvcreate --name lvsplunkephemeral${DEVNUM} -l100%FREE vgsplunkephemeral${DEVNUM} >> /var/log/splunkconf-aws-recovery-info.log
      pvdisplay >> /var/log/splunkconf-aws-recovery-info.log
      vgdisplay >> /var/log/splunkconf-aws-recovery-info.log
      lvdisplay >> /var/log/splunkconf-aws-recovery-info.log
      # note mkfs wont format if the FS is already mounted -> no need to check here
      mkfs.ext4 -L ephemeral1 /dev/vgsplunkephemeral1/lvsplunkephemeral1  >> /var/log/splunkconf-aws-recovery-info.log
      mkdir -p /data/vol1
      RES=`grep /data/vol1 /etc/fstab`
      #echo " debug F=$RES."
      if [ -z "${RES}" ]; then
        #mount /dev/vgsplunkephemeral1/lvsplunkephemeral1 /data/vol1 && mkdir -p /data/vol1/indexes
        echo "/data/vol1 not found in /etc/fstab, adding it" >> /var/log/splunkconf-aws-recovery-info.log
        echo "/dev/vgsplunkephemeral${DEVNUM}/lvsplunkephemeral${DEVNUM} /data/vol1 ext4 defaults,nofail 0 2" >> /etc/fstab
        mount /data/vol1
        echo "creating /data/vol1/indexes and giving to splunk user" >> /var/log/splunkconf-aws-recovery-info.log
        mkdir -p /data/vol1/indexes
        chown -R splunk. /data/vol1/indexes
        echo "moving splunk home to ephemeral devices in data/vol1/splunk (smartstore scenario)" >> /var/log/splunkconf-aws-recovery-info.log
        (mv /opt/splunk /data/vol1/splunk;ln -s /data/vol1/splunk /opt/splunk;chown -R splunk. /opt/splunk) || mkdir -p /data/vol1/splunk
        SPLUNK_HOME="/data/vol1/splunk"
      else
        echo "/data/vol1 is already in /etc/fstab, doing nothing" >> /var/log/splunkconf-aws-recovery-info.log
      fi
    fi
  else
    echo "not a idx, no additional partition to configure" >> /var/log/splunkconf-aws-recovery-info.log
  fi # if idx
fi # if not upgrade


yum install curl -y

# Splunk installation
# note : if you update here, that could update at reinstanciation, make sure you know what you do !
#splbinary="splunk-8.0.5-a1a6394cc5ae-linux-2.6-x86_64.rpm"
splbinary="splunk-8.0.6-152fb4b2bb96-linux-2.6-x86_64.rpm"
if [ -z ${splunktargetbinary+x} ]; then 
  echo "splunktargetbinary not set in instance tags, falling back to use version ${splbinary} from aws recovery script" >> /var/log/splunkconf-aws-recovery-info.log
else 
  splbinary=${splunktargetbinary}
  echo "using splunktargetbinary ${splunktargetbinary} from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
echo "remote : ${remoteinstalldir}/${splbinary}" >> /var/log/splunkconf-aws-recovery-info.log
# aws s3 cp doesnt support unix globing
aws s3 cp ${remoteinstalldir}/${splbinary} ${localinstalldir} --quiet
ls ${localinstalldir}
if [ ! -f "${localinstalldir}/${splbinary}"  ]; then
  echo "ERROR FATAL : ${splbinary} is not present in s3 -> please verify the version specified is present in s3 install " >> /var/log/splunkconf-aws-recovery-info.log
  # better to exit now and have the admin fix the situation
  exit 1
fi


# creating dir as we may not have yet deployed RPM
mkdir -p ${SPLUNK_HOME}/etc/system/local/
mkdir -p ${SPLUNK_HOME}/etc/apps/
mkdir -p ${SPLUNK_HOME}/etc/auth/
chown -R splunk. ${SPLUNK_HOME}

# tuning system
# we will use SYSVER to store version type (used for packagesystem and hostname setting for example)
SYSVER=6
if ! command -v hostnamectl &> /dev/null
then
  echo "hostnamectl command could not be found -> Assuming RH6/AWS1 like distribution" >> /var/log/splunkconf-aws-recovery-info.log
  SYSVER=6
  echo "remote : ${remoteinstalldir}/package-systemaws1-for-splunk.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
  aws s3 cp ${remoteinstalldir}/package-systemaws1-for-splunk.tar.gz  ${localinstalldir} --quiet
  if [ -f "${localinstalldir}/package-systemaws1-for-splunk.tar.gz"  ]; then
    echo "deploying system tuning for Splunk, version for AWS1 like systems" >> /var/log/splunkconf-aws-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-systemaws1-for-splunk.tar.gz
  else
    echo "remote : ${remoteinstalldir}/package-system-for-splunk.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remoteinstalldir}/package-system-for-splunk.tar.gz  ${localinstalldir} --quiet
    echo "deploying system tuning for Splunk" >> /var/log/splunkconf-aws-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz
  fi
  # enable the system tuning 
  sysctl --system;/etc/rc.d/rc.local 
  # deploying splunk secrets
  yum install -y python36-pip
  pip install --upgrade pip
  pip-3.6 install splunksecrets
else
  echo "hostnamectl command detected, assuming RH7+ like distribution" >> /var/log/splunkconf-aws-recovery-info.log
  # note we treat RH8 like RH7 for the moment as systemd stuff that works for RH7 also work for RH8 
  SYSVER=7
  # issue on aws2 , polkit and tuned not there by default
  # in that case, restart from splunk user would return
  # Failed to restart splunk.service: The name org.freedesktop.PolicyKit1 was not provided by any .service files
  # See system logs and 'systemctl status splunk.service' for details.
  # despite the proper policy kit files deployed !
  yum install polkit tuned -y
  systemctl enable tuned.service
  systemctl start tuned.service
  echo "remote : ${remoteinstalldir}/package-system7-for-splunk.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
  aws s3 cp ${remoteinstalldir}/package-system7-for-splunk.tar.gz  ${localinstalldir} --quiet
  if [ -f "${localinstalldir}/package-system7-for-splunk.tar.gz"  ]; then
    echo "deploying system tuning for Splunk, version for RH7+ like systems" >> /var/log/splunkconf-aws-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system7-for-splunk.tar.gz
  else
    echo "remote : ${remoteinstalldir}/package-system-for-splunk.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remoteinstalldir}/package-system-for-splunk.tar.gz  ${localinstalldir} --quiet
    echo "deploying system tuning for Splunk" >> /var/log/splunkconf-aws-recovery-info.log
    # deploy system tuning (after Splunk rpm to be sure direcoty structure exist and splunk user also)
    tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz
  fi
  # enable the tuning done via rc.local and restart polkit so it takes into account new rules
  sysctl --system;sleep 1;chmod u+x /etc/rc.d/rc.local;systemctl start rc-local;systemctl restart polkit
  # deploying splunk secrets
  pip3 install splunksecrets
fi


if [ "$MODE" != "upgrade" ]; then
  # fetching files that we will use to initialize splunk
  # splunk.secret just in case we are on a new install (ie won't be in the backup)
  echo "remote : ${remoteinstalldir}/splunk.secret" >> /var/log/splunkconf-aws-recovery-info.log
  # FIXME : temp , logic is in splunkconf-init
  aws s3 cp ${remoteinstalldir}/splunk.secret ${SPLUNK_HOME}/etc/auth --quiet

  echo "remote : ${remotepackagedir} : copying initial apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-aws-recovery-info.log
  # copy to local
  aws s3 cp  ${remotepackagedir}/initialapps.tar.gz ${localinstalldir} --quiet >> /var/log/splunkconf-aws-recovery-info.log
  tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/initialapps.tar.gz >> /var/log/splunkconf-aws-recovery-info.log

  echo "remote : ${remotepackagedir} : copying initial TLS apps to ${localinstalldir} and untarring into ${SPLUNK_HOME}/etc/apps " >> /var/log/splunkconf-aws-recovery-info.log
  # to ease initial deployment, tls app is pushed separately (warning : once the backups run, backup would restore this also of course)
  aws s3 cp  ${remotepackagedir}/initialtlsapps.tar.gz ${localinstalldir} --quiet >> /var/log/splunkconf-aws-recovery-info.log
  tar -C "${SPLUNK_HOME}/etc/apps" -zxf ${localinstalldir}/initialtlsapps.tar.gz >> /var/log/splunkconf-aws-recovery-info.log
  echo "remote : ${remotepackagedir} : copying certs " >> /var/log/splunkconf-aws-recovery-info.log
  # copy to local
  aws s3 cp  ${remotepackagedir}/mycerts.tar.gz ${localinstalldir} --quiet
  tar -C "${SPLUNK_HOME}/etc/auth" -zxf ${localinstalldir}/mycerts.tar.gz 

  ## 7.0 no user seed with hashed passwd, first time we have no backup lets put directly passwd 
  #echo "remote : ${remoteinstalldir}/passwd" >> /var/log/splunkconf-aws-recovery-info.log
  #aws s3 cp ${remoteinstalldir}/passwd ${localinstalldir} --quiet
  ## copying to right place
  #cp ${localinstalldir}/passwd /opt/splunk/etc/
  #chown -R splunk. /opt/splunk

  # giving the index directory to splunk if they exist
  chown -R splunk. /data/vol1/indexes
  chown -R splunk. /data/vol2/indexes

  # deploy including for indexers
  echo "remote : ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
  aws s3 cp ${remotebackupdir}/backupconfsplunk-scripts-initial.tar.gz ${localbackupdir} --quiet
  # setting up permissions for backup
  chown splunk ${localbackupdir}/*.tar.gz
  chmod 500 ${localbackupdir}/*.tar.gz
  tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz


  if [ "$RESTORECONFBACKUP" -eq 1 ]; then
    # getting configuration backups if exist 
    # change here for kvstore 
    echo "remote : ${remotebackupdir}/backupconfsplunk-etc-targeted.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remotebackupdir}/backupconfsplunk-etc-targeted.tar.gz ${localbackupdir} --quiet
    # at first splunk install, need to recreate the dir and give it to splunk
    mkdir -p ${localkvdumpbackupdir};chown splunk. ${localkvdumpbackupdir}
    echo "remote : ${remotebackupdir}/backupconfsplunk-kvdump.tar.gz " >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remotebackupdir}/backupconfsplunk-kvdump.tar.gz ${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz --quiet
    # making sure splunk user can access the backup 
    chown splunk. ${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz
    # and only
    chmod 500 ${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz
    echo "remote : ${remotebackupdir}/backupconfsplunk-kvstore.tar.gz " >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remotebackupdir}/backupconfsplunk-kvstore.tar.gz ${localbackupdir} --quiet

    echo "remote : ${remotebackupdir}/backupconfsplunk-state.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remotebackupdir}/backupconfsplunk-state.tar.gz ${localbackupdir} --quiet

    echo "remote : ${remotebackupdir}/backupconfsplunk-scripts.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
    aws s3 cp ${remotebackupdir}/backupconfsplunk-scripts.tar.gz ${localbackupdir} --quiet

    # setting up permissions for backup
    chown splunk ${localbackupdir}/*.tar.gz
    chmod 500 ${localbackupdir}/*.tar.gz

    echo "localbackupdir ${localbackupdir}  contains" >> /var/log/splunkconf-aws-recovery-info.log
    ls -l ${localbackupdir} >> /var/log/splunkconf-aws-recovery-info.log

    echo "localkvdumpbackupdir ${localkvdumpbackupdir}  contains" >> /var/log/splunkconf-aws-recovery-info.log
    ls -l ${localkvdumpbackupdir} >> /var/log/splunkconf-aws-recovery-info.log

    # untarring backups  
    # configuration (will redefine collections as needed)
    tar -C "/" -xf ${localbackupdir}/backupconfsplunk-etc-targeted.tar.gz
    # if we updated certs, we want them to optionally replace the ones in backup
    tar -C "${SPLUNK_HOME}/etc/auth" -zxf ${localinstalldir}/mycerts.tar.gz 
    # restore kvstore ONLY if kvdump not present
    file="${localkvdumpbackupdir}/backupconfsplunk-kvdump-toberestored.tar.gz"
    if [ -e "$file" ]; then
      echo "kvdump exist" >> /var/log/splunkconf-aws-recovery-info.log
    else 
      echo "kvdump backup does not exist" >> /var/log/splunkconf-aws-recovery-info.log
      file="${localbackupdir}/backupconfsplunk-kvstore.tar.gz"
      if [ -e "$file" ]; then
         echo "kvstore backup exist and is restored" >> /var/log/splunkconf-aws-recovery-info.log
         tar -C "/" -xf ${localbackupdir}/backupconfsplunk-kvstore.tar.gz
      else
         echo "Neither kvdump or kvstore backup exist, doing nothing" >> /var/log/splunkconf-aws-recovery-info.log
      fi
    fi 
    # when needed kvdump will be restored later as it need to be done online
    tar -C "/" -xf ${localbackupdir}/backupconfsplunk-state.tar.gz
    # need to be done after others restore as the cron entry could fire another backup (if using system version)
    tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts-initial.tar.gz
    tar -C "/" --exclude opt/splunk/scripts/splunkconf-aws-recovery.sh --exclude usr/local/bin/splunkconf-aws-recovery.sh -xf ${localbackupdir}/backupconfsplunk-scripts.tar.gz
  # if restore
  fi

  # set the hostname except if this is auto or contain idx or generic name
  # below is the exception criteria (ie indexer, uf  we cant set the name for example as there can be multiple instance of the same type)
  if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then 
    echo "specific instance name : changing hostname to ${instancename} "
    # first time actions 
    # set instance names if splunk instance was already started (in the ami or from the backup...) 
    sed -i -e 's/ip\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}/${instancename}/g' ${SPLUNK_HOME}/etc/system/local/inputs.conf
    sed -i -e 's/ip\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}\-[0-9]\{1,3\}/${instancename}/g' ${SPLUNK_HOME}/etc/system/local/server.conf
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/inputs.conf"  ]; then
      # Splunk was never started  (ie we just deployed in the recovery above)
      echo "initializing inputs.conf with ${instancename}\n"
      echo "[default]" > ${SPLUNK_HOME}/etc/system/local/inputs.conf
      echo "host = ${instancename}" >> ${SPLUNK_HOME}/etc/system/local/inputs.conf
      chown splunk. ${SPLUNK_HOME}/etc/system/local/inputs.conf
    fi
    if [ ! -f "${SPLUNK_HOME}/etc/system/local/server.conf"  ]; then
      # Splunk was never started  (ie we just deployed in the recovery above)
      echo "initializing server.conf with ${instancename}\n"
      echo "[general]" > ${SPLUNK_HOME}/etc/system/local/server.conf
      echo "serverName = ${instancename}" >> ${SPLUNK_HOME}/etc/system/local/server.conf
      chown splunk. ${SPLUNK_HOME}/etc/system/local/server.conf
    fi
    echo "changing hostname at system level"
    if [ $SYSVER -eq "6" ]; then
      echo "Using legacy method" >> /var/log/splunkconf-aws-recovery-info.log
      # legacy ami type , rh6 like
      sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${instancename}/g" /etc/sysconfig/network
      # dynamic change on top in case correct hostname is needed further down in this script 
      hostname ${instancename}
      # we should call a command here to force hostname immediately as splunk commands are started after
    else     
      # new ami , rh7+,...
      echo "Using new hostnamectl method" >> /var/log/splunkconf-aws-recovery-info.log
      hostnamectl set-hostname ${instancename}
    fi
  elif [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
    if [ -z ${splunkorg+x} ]; then 
      echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-aws-recovery-info.log
      splunkorg="org"
    else 
      echo "using splunkorg=${splunkorg} from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
    fi
    AZONE=`curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone  `
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
    site="site${sitenum}"
    echo "Indexer detected setting site for availability zone $AZONE (letter=$ZONELETTER,sitenum=$sitenum, site=$site) " >> /var/log/splunkconf-aws-recovery-info.log
    # removing any conflicting app that could define site
    # giving back files to splunk user (this is required here as if the permissions are incorrect from tar file du to packaging issues, the delete from splunk below will fail here)
    chown -R splunk. $SPLUNK_HOME
    FORME="*site*base"
    # find app that match forn and deleting the app folder
    su - splunk -c "/usr/bin/find $SPLUNK_HOME/etc/apps/ -name \"${FORME}\" -exec rm -r {} \; "
    find $SPLUNK_HOME/etc/apps/ -name \"\*site\*base\" -delete -print >> /var/log/splunkconf-aws-recovery-info.log
    mkdir -p "$SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base/local"
    echo -e "#This configuration was automatically generated based on indexer location\n#This site should be defined on the CM\n[general] \nsite=$site" > $SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base/local/server.conf
    # giving back files to splunk user
    chown -R splunk. $SPLUNK_HOME/etc/apps/${splunkorg}_site${sitenum}_base
    echo "Setting Indexer on site: $site" >> /var/log/splunkconf-aws-recovery-info.log
    # this service is ran at stop when a instance is terminated cleanly (scaledown event)
    # if will run before the normal splunk service and run a script that use the splunk offline procedure 
    # in order to tell the CM to replicate before the instance is completely terminated
    # we dont want to run this each time the service stop for cases such as rolling restart or system reboot
    read -d '' SYSAWSTERMINATE << EOF
[Unit]
Description=AWS terminate helper Service
Before=poweroff.target shutdown.target halt.target
# so that it will stop before splunk systemd unit stop
Wants=splunk.target
Requires=network-online.target network.target

[Service]
KillMode=none
ExecStart=/bin/true
ExecStop=/usr/local/bin/splunkconf-aws-terminate-idx.sh
RemainAfterExit=yes
Type=oneshot
# stop after 15 min anyway as a safeguard, the shell script should use a tineout below that value
TimeoutStopSec=15min
User=splunk

[Install]
WantedBy=multi-user.target

EOF

    echo "$SYSAWSTERMINATE" > /etc/systemd/system/aws-terminate-helper.service
    systemctl daemon-reload
    systemctl enable aws-terminate-helper.service
    chown root.splunk ${localrootscriptdir}/splunkconf-aws-terminate-idx.sh
    chmod 550 ${localrootscriptdir}/splunkconf-aws-terminate-idx.sh
  else
    echo "other generic instance type( uf,...) , we wont change anything to avoid duplicate entries, using the name provided by aws"
  fi

  ## deploy or update the backup scripts
  #aws s3 cp ${remoteinstalldir}/install/splunkconf-backup-s3.tar.gz ${localbackupdir} --quiet
  #tar -C "/" -xzf ${localbackupdir}/splunkconf-backup-s3.tar.gz 

  # need user seed when 7.1

  # user-seed.config
  echo "remote : ${remoteinstalldir}/user-seed.conf" >> /var/log/splunkconf-aws-recovery-info.log
  aws s3 cp ${remoteinstalldir}/user-seed.conf ${localinstalldir} --quiet
  # copying to right place
  # FIXME : more  logic here
  cp ${localinstalldir}/user-seed.conf ${SPLUNK_HOME}/etc/system/local/
  chown -R splunk. ${SPLUNK_HOME}

fi # if not upgrade

# updating master_uri (needed when reusing backup from one env to another)
# this is for indexers, search heads, mc ,.... (we will detect if the conf is present)
if [ -z ${splunkorg+x} ]; then 
  echo "instance tags are not correctly set (splunkorg). I dont know prefix for splunk base apps, will use org ! Please add splunkorg tag" >> /var/log/splunkconf-aws-recovery-info.log
  splunkorg="org"
else 
  echo "using splunkorg=${splunkorg} from instance tags" >> /var/log/splunkconf-aws-recovery-info.log
fi
# splunkawsdnszone used for updating route53 when apropriate
if [ -z ${splunkawsdnszone+x} ]; then 
    echo "instance tags are not correctly set (splunkawsdnszone). I dont know splunkawsdnszone to use for updating master_uri in a cluster env ! Please add splunkawsdnszone tag" >> /var/log/splunkconf-aws-recovery-info.log
else 
  echo "using splunkawsdnszone ${splunkawsdnszone} from instance tags (master_uri) " >> /var/log/splunkconf-aws-recovery-info.log
  find ${SPLUNK_HOME} -wholename "*cluster*base/local/server.conf" -exec grep -l master_uri {} \; -exec sed -i -e "s%^.*master_uri.*=.*$%master_uri=https://splunk-cm.${splunkawsdnszone}:8089%" {} \; && echo "make sure you have a alias (cname) splunk-cm.${splunkawsdnszone} that point to the name used by the cm instance "
fi



## moved with complete logic to splunkconf-init
#${SPLUNK_HOME}/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user splunk -systemd-managed 0 || ${SPLUNK_HOME}/bin/splunk enable boot-start --accept-license --answer-yes --no-prompt -user splunk
##${SPLUNK_HOME}/bin/splunk enable boot-start -user splunk --accept-license
## if run first time, because we haven't started splunk yet, this risk writing some files as root so lets give them back to splunk
#chown -R splunk. ${SPLUNK_HOME}

## redeploy system tuning as enable boot start may have overwritten files
##tar -C "/" -zxf ${localinstalldir}/package-system-for-splunk.tar.gz

echo "installing/upgrading splunk via RPM using ${splbinary}" >> /var/log/splunkconf-aws-recovery-info.log
# install or upgrade
rpm -Uvh ${localinstalldir}/${splbinary}

# give back files (see RN)
chown -R splunk. ${SPLUNK_HOME}

## using updated init script with su - splunk
#echo "remote : ${remoteinstalldir}/splunkenterprise-init.tar.gz" >> /var/log/splunkconf-aws-recovery-info.log
#aws s3 cp ${remoteinstalldir}/splunkenterprise-init.tar.gz ${localinstalldir} --quiet
#tar -C "/" -xzf ${localinstalldir}/splunkenterprise-init.tar.gz 

# updating splunkconf-backup app from s3
# important : version on s3 should be up2date as it is prioritary over backups and other content
# only if it is not a indexer 
if ! [[ "${instancename}" =~ ^(auto|indexer|idx|idx1|idx2|idx3|hf|uf|ix-site1|ix-site2|ix-site3|idx-site1|idx-site2|idx-site3)$ ]]; then
  aws s3 cp ${remoteinstallsplunkconfbackup} ${localinstalldir} --quiet
  if [ -e "${localinstalldir}/splunkconf-backup.tar.gz" ]; then
    # backup old version just in case
    tar -C "${SPLUNK_HOME}/etc/apps/" -zcvf ${localinstalldir}/splunkconf-backup-${TODAY}.tar.gz ./splunkconf-backup
    # remove so we dont have leftover in local that could break app
    find "${SPLUNK_HOME}/etc/apps/splunkconf-backup" -delete
    tar -C "${SPLUNK_HOME}/etc/apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz ./splunkconf-backup
    # removing old version for upgrade case 
    if [ -e "/etc/crond.d/splunkbackup.cron" ]; then
      rm -f /etc/crond.d/splunkbackup.cron
    fi
    mv ${SPLUNK_HOME}/scripts/splunconf-backup ${SPLUNK_HOME}/scripts/splunconf-backup-disabled
    echo "splunkconfbackup found on s3 at ${remoteinstallsplunkconfbackup} and updated from it"
    # we may be on a DS then we need to also update it
    if [ -e "${SPLUNK_HOME}/etc/deployment-apps/splunkconf-backup" ]; then
      echo "updating splunkconf-backup on a DS"
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -zcvf ${localinstalldir}/splunkconf-backup-${TODAY}-fromdeploymentapps.tar.gz ./splunkconf-backup
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/deployment-apps/splunkconf-backup" -delete
      tar -C "${SPLUNK_HOME}/etc/deployment-apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz
    fi
    # we may be on a SHC deployer then we need to also update it
    if [ -e "${SPLUNK_HOME}/etc/shcluster/apps/splunkconf-backup" ]; then
      echo "updating splunkconf-backup on a SHC deployer"
      # backup old version just in case
      tar -C "${SPLUNK_HOME}/etc/shcluster/apps" -zcvf ${localinstalldir}/splunkconf-backup-${TODAY}-fromshclusterapps.tar.gz
      # remove so we dont have leftover in local that could break app
      find "${SPLUNK_HOME}/etc/shcluster/apps/splunkconf-backup" -delete
      tar -C "${SPLUNK_HOME}/etc/shcluster/apps" -xzf ${localinstalldir}/splunkconf-backup.tar.gz
    fi
  else 
    echo "splunkconf-backup not found on s3 so will not deploy it now. consider adding it at ${remoteinstallsplunkconfbackup} for autonatic deployment"
  fi
fi

# splunk initialization (first time or upgrade)
mkdir -p ${localrootscriptdir}
aws s3 cp ${remoteinstalldir}/splunkconf-init.pl ${localrootscriptdir}/ --quiet

# just in case
yum install perl -y >> /var/log/splunkconf-aws-recovery-info.log
# make it executable
chmod u+x ${localrootscriptdir}/splunkconf-init.pl
echo "setting up Splunk (boot-start, license, init tuning, upgrade prompt if applicable...) with splunkconf-init" >> /var/log/splunkconf-aws-recovery-info.log
# no need to pass option, it will default to systemd + /opt/splunk + splunk user
${localrootscriptdir}/splunkconf-init.pl --no-prompt

echo "localrootscriptdir ${localrootscriptdir}  contains" >> /var/log/splunkconf-aws-recovery-info.log
ls ${localrootscriptdir} >> /var/log/splunkconf-aws-recovery-info.log

echo "localinstalldir ${localinstalldir}  contains" >> /var/log/splunkconf-aws-recovery-info.log
ls ${localinstalldir} >> /var/log/splunkconf-aws-recovery-info.log

if [ "$MODE" != "upgrade" ]; then 
  # local upgrade script (we dont do this in upgrade mode as overwriting our own script already being run could be problematic)
  echo "remote : ${remoteinstalldir}/splunkconf-upgrade-local.sh" >> /var/log/splunkconf-aws-recovery-info.log
  aws s3 cp ${remoteinstalldir}/splunkconf-upgrade-local.sh  ${localrootscriptdir}/ --quiet
  # if there is a dns update to do , we have put the script and it has been redeployed as part of the restore above
  # so we can run it now
  # the content will be different depending on the instance
  #if [ -e /opt/splunk/scripts/aws_dns_update/dns_update.sh ]; then
  #  /opt/splunk/scripts/aws_dns_update/dns_update.sh
  #fi
  # this is restored by backup scriptsa (initial one) but only present if the admin decided it is necessary (ie for example to update dns for some instances)
  # if needed this is calling other scripts
  if [ -e ${localrootscriptdir}/aws-postinstall.sh ]; then
    echo "lauching aws-postinstall in ${localrootscriptdir}/aws-postinstall.sh" >> /var/log/splunkconf-aws-recovery-info.log
    chown root. ${localrootscriptdir}/aws-postinstall.sh
    chmod u+x ${localrootscriptdir}/aws-postinstall.sh
    ${localrootscriptdir}/aws-postinstall.sh
    # note if needed , this will transparently call other scripts deployed in the initial backup so that recevoery script can stay generic
  fi
fi # if not upgrade

# apply sessions workaround for 8.0 if needed
if [ -e "/opt/splunk/etc/apps/sessions.py" ]; then
  cp -p /opt/splunk/lib/python3.7/site-packages/splunk/appserver/mrsparkle/lib/sessions.py /opt/splunk/etc/apps/sessions.py.orig
  cp -p /opt/splunk/etc/apps/sessions.py /opt/splunk/lib/python3.7/site-packages/splunk/appserver/mrsparkle/lib/sessions.py 
fi
sleep 1

if [ "$MODE" != "upgrade" ]; then 
  TODAY=`date '+%Y%m%d-%H%M_%u'`;
  echo "${TODAY}  splunkconf-aws-recovery.sh checking if kvdump recovery running" >> /var/log/splunkconf-aws-recovery-info.log
  # prevent reboot in the middle of a kvdump restore
  counter=100
  # (30 min max should be enough for restoring a big kvdump)
  while [ $counter -gt 0 ]
  do
    counter=$(($counter-1))
    if [ -e /opt/splunk/var/run/splunkconf-kvrestore.lock ]; then 
      echo "splunkconf-restore is running at the moment, waiting before initiating reboot (step=30s, counter=$counter)" >> /var/log/splunkconf-aws-recovery-info.log
      sleep 30
    else
      # no need to loop
      break
    fi
  done
  # prevent stale lock 
  if [ -e /opt/splunk/var/run/splunkconf-kvrestore.lock ]; then 
    echo "Warning : Removing possible splunkconf kvstore lock" >> /var/log/splunkconf-aws-recovery-info.log 
    rm /opt/splunk/var/run/splunkconf-kvrestore.lock
  fi
fi # if not upgrade


TODAY=`date '+%Y%m%d-%H%M_%u'`;
#NOW=`(date "+%Y/%m/%d %H:%M:%S")`
if [ "$MODE" != "upgrade" ]; then 
  echo "${TODAY} splunkconf-aws-recovery.sh end of script, initiating reboot via init 6" >> /var/log/splunkconf-aws-recovery-info.log
  # reboot
  init 6
else
  echo "${TODAY} splunkconf-aws-recovery.sh end of script run in upgrade mode" >> /var/log/splunkconf-aws-recovery-info.log
fi # if not upgrade
