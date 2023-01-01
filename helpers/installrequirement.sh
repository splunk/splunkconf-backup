#!/bin/bash

# 20221231a

# This script create the local bucket structure to be pushed in cloud bucket via terraform
# from the git structure
# do not try to run the terraform as is without creating the structure, it would not work correctly

# just the install requirement part

echo "************************** git and terraform installation (if needeed)   "


# checking git command
if command -v git &> /dev/null
then
  echo "OK command git already present"
else
  # asking to install git if not here via package manager
  if ! command -v yum &> /dev/null
  then
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
  sudo sed -i -e 's%$releasever%7%' /etc/yum.repos.d/hashicorp.repo
  sudo yum -y install terraform
fi

if ! command -v terraform &> /dev/null
then
  echo "FAIL command terraform could not be installed"
  exit 1
fi


