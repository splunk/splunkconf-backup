#!/bin/bash


# This script create the local bucket structure to be pushed in cloud bucket via terraform
# from the git structure
# do not try to run the terraform as is without creating the structure, it would not work correctly

# checking git command
if command -v git &> /dev/null
then
  echo "OK command git already present"
else
  # asking to install git if not here via package manager
  if ! command -v yum &> /dev/null
    echo "not on a RH like system, command yum not found, please install git and terraform and relaunch script (mac brew install git and brew install terraform)"
    exit 1
  else
    echo "installing git via package manager if needed"
    sudo yum install -y git 
  fi
fi
if ! command -v git &> /dev/null
then
  echo "FAIL command git could not be installed"
  exit 1
fi

if command -v terraform &> /dev/null
then
  echo "OK command terraform already present"
else
  echo "installing terraform via package manager"
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
  # on AWS2 , the release is 2 which confuse the hashicorp.repo -> forcing version 7
  sed -i -e 's%$releasever%7%' /etc/yum.repos.d/hashicorp.repo
  sudo yum -y install terraform


if ! command -v terraform &> /dev/null
then
  echo "FAIL command terraform could not be installed"
  exit 1
fi


# cloning repo to local dir
git clone https://github.com/splunk/splunkconf-backup.git

cd splunkconf-backup


#createbuckets:
i=buckets
mkdir -p $i/bucket-install/install/apps
mkdir -p $i/bucket-install/packaged
# copying apps for bucket install
# Event Timeline is to be downloaded from https://splunkbase.splunk.com/app/4370/#/details
# SHA256 checksum (event-timeline-viz_160.tgz) 8dc7a5cf1faf5d2a64cb2ceae17049070d24f74c381b83f831d0c51ea15a2ffe
# SHA256 checksum (event-timeline-viz_171.tgz) 7d110b3adbcdb5342d01a42b950f0c10b55dbadc561111fce14afcee16070755
# you need this on the MC to have the dashboard viz running 
for j in splunkconf-backup.tar.gz event-timeline-viz_171.tgz
do
  if [ -e ./install/apps/$j ]; then 
    \cp -p ./install/apps/$j "$i/bucket-install/install/apps/"
  else
    echo "ERROR : missing file ./install/apps/$j, please add it and relaunch"
  fi
done
SOURCE="src"
# copying files for bucket install in install
# splunk.secret -> you need to provide it from a splunk deployment (unique to that env)
# user-seed.conf -> to initiate splunk password, you can use splunkconf-init.pl to create it or follow splunk doc 
# splunkconf-aws-recovery.sh is renamed to splunkconf-cloud-recovery.sh, you dont need it unless you rely on user data that reference the old file name
# splunktargetenv are optional script to have custom actions on a specific env when moving between prod and test env (like disabling sending emails or alerts)
for j in splunk.secret user-seed.conf splunkconf-cloud-recovery.sh splunkconf-upgrade-local.sh splunkconf-swapme.pl splunkconf-upgrade-local-precheck.sh splunkconf-upgrade-local-setsplunktargetbinary.sh splunkconf-prepare-es-from-s3.sh user-data.txt user-data-gcp.txt splunkconf-init.pl installes.sh splunktargetenv-for*.sh splunkconf-ds-lb.sh
do
  if [ -e ./$SOURCE/$j ]; then 
    \cp -p ./$SOURCE/$j  "$i/bucket-install/install/"
   else
    echo "ERROR : missing file ./$SOURCE/$j, please read comment in script and evaluate if you need it then relaunch if necessary"
  fi
done
# same for system files
SOURCE="system"
for j in package-systemaws1-for-splunk.tar.gz package-system7-for-splunk.tar.gz package-systemdebian-for-splunk.tar.gz 
do
  if [ -e ./$SOURCE/$j ]; then 
    \cp -p ./$SOURCE/$j  "$i/bucket-install/install/"
   else
    echo "ERROR : missing file ./$SOURCE/$j, please read comment in script and evaluate if you need it then relaunch if necessary"
  fi
done
# same for system files
# creating structure for backup bucket
mkdir -p $i/bucket-backup/splunkconf-backup
# creating structure for terraform files
mkdir -p $i/terraform/policy-aws
mkdir -p $i/terraform/scripts-template
mkdir -p $i/terraform-gcp/scripts-template
# scripts template
\cp -fp ../src/splunkconf-aws-terminate-idx.sh $i/terraform/scripts-template/
\cp -fp ../src/splunkconf-aws-terminate-idx.sh $i/terraform-gcp/scripts-template/
# inlined \cp -fp ../splunkconf-backup/aws-update-dns.sh $i/terraform/scripts-template/
# inlined \cp -fp ../splunkconf-backup/gcp-update-dns.sh $i/terraform-gcp/scripts-template/
# terraform tf
chmod a+x terraform/*.sh
chmod a+x terraform-gcp/*.sh
\cp -p ./terraform/*.tf terraform/build-idx-scripts.sh terraform/build-nonidx-scripts.sh terraform/debugtf.sh  "$i/terraform/"
\cp -p ./terraform-gcp/*.tf terraform-gcp/build-idx-scripts.sh terraform-gcp/build-nonidx-scripts.sh terraform-gcp/debugtf.sh  "$i/terraform-gcp/"
#rm "$i/terraform/gitlabsplunk.tf"
#rm "$i/terraform-gcp/gitlabsplunk.tf"
# policy templates
\cp -rp ./terraform/policy-aws  "$i/terraform/"

echo "Please go in splunkconf-backup/terraform to continue"
echo "Please also make sure you set up cloud credentials and customize variables"
echo "you may also want to use a remote tfstate"

