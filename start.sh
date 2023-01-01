#!/bin/bash

# 20221231a

# This script create the local bucket structure to be pushed in cloud bucket via terraform
# from the git structure
# do not try to run the terraform as is without creating the structure, it would not work correctly


# 20221231 split into multiple files, remove step to create buckets as now automatically done via terraform


./helpers/installrequirement.sh


echo "************************** SSH key check "

if [ ! -e "~/.ssh/id_rsa" ]; then
  echo "no ssh key , creating one for access to basrtion host"
  echo -ne '\n' | ssh-keygen -q -t rsa -f ~/.ssh/id_rsa
else
  echo "ssh key exist"
fi

echo "************************** GIT CLONE "
# cloning repo to local dir
git clone https://github.com/splunk/splunkconf-backup.git

# temp solution 
pip3 install passlib


cd splunkconf-backup


# inlined \cp -fp ../splunkconf-backup/aws-update-dns.sh $i/terraform/scripts-template/
# inlined \cp -fp ../splunkconf-backup/gcp-update-dns.sh $i/terraform-gcp/scripts-template/
# terraform tf
#chmod a+x terraform/*.sh
#chmod a+x terraform-gcp/*.sh
#\cp -p ./terraform/*.tf terraform/build-idx-scripts.sh terraform/build-nonidx-scripts.sh terraform/debugtf.sh  "$i/terraform/"
#\cp -p ./terraform-gcp/*.tf terraform-gcp/build-idx-scripts.sh terraform-gcp/build-nonidx-scripts.sh terraform-gcp/debugtf.sh  "$i/terraform-gcp/"
# policy templates
#\cp -rp ./terraform/policy-aws  "$i/terraform/"

#echo "Please go in splunkconf-backup/terraform to continue"
#echo "Please also make sure you set up cloud credentials and customize variables"
#echo "you may also want to use a remote tfstate"


# 2 options here 
# either normal modules then use loca-preparation-withmodules.tf
# either with remotestate (as below) so we can partially destroy without destroying bastion, ssh key declaration (AWS API is limited on this part, which doesnt help terraform knows what to do) and kms (if we want to reusae data in bucket later on)   (file local-preparation-withremotestate.tf)
# at the moment , below logic is with remotestate which match files in git

#for i in kms network ssh 
#do
#  echo "initializing module in  ~/splunkconf-backup/terraform/modules/$i "
#  echo "WARNING : you need to run the modules (after setting variables before the main terraform ir that will fail"
#  cd ~/splunkconf-backup/terraform/modules/$i
#  terraform init
#  terraform validate
#  # terraform plan
#  # terraform apply
#done

#echo "initializing terraform in  ~/splunkconf-backup/terraform "
#cd ~/splunkconf-backup/terraform
#terraform init
#terraform validate
# terraform plan
# terraform apply

echo " Please try to use VCS mode by cloning repository in github and then attaching it to a terraform cloud env. If not possible, you can still run traditional terraform"
echo " Also make sure, you have configure AWS access wherever you choose to run terraform (via aws configure or env variable in terraform cloud)"
echo " you will also need to customize variables"



