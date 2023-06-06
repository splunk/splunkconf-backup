#!/bin/bash

# Matthieu Araman , Splunk
# this script called by terraform
# 20210111 change paths to ref new buckets dirstructure
# 20210113 path change
# 20230314 version just for ansible playbook for worker
# 20230521 split ansible into 2 files
# 20230521 general form + subdir + sync
# 20230522 fallback to cp version
# 20230529 add playbook for inventory creation
# 20230606 add splunk ansible deploy playbook

VERSION="20230606a"

# first arg = bucket install
# second arg = bucket backup

s3_install=$1
s3_backup=$2
#aws s3 sync ../buckets/bucket-backup/splunkconf-backup s3://${s3_backup}/splunkconf-backup/ --storage-class STANDARD_IA; 
#aws s3 sync ../buckets/bucket-install/packaged s3://${s3_install}/packaged/ --storage-class STANDARD_IA; 
#aws s3 sync ../buckets/bucket-install/install s3://${s3_install}/install/ --storage-class STANDARD_IA
# not working version aws s3 cp ./ansible* s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
aws s3 cp ../helpers/getmycredentials.sh s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
aws s3 cp ./inventory.yaml s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
aws s3 cp ./ansible_jinja_tf.yml s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
aws s3 cp ./ansible_deploysplunkansible_tf.yml s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
aws s3 cp ./ansible_jinja_byhost_tf.yml s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
aws s3 cp ./splunk_ansible_inventory_create.yml s3://${s3_install}/install/ansible/ --storage-class STANDARD_IA
# j2
aws s3 cp ./j2/splunk_ansible_inventory_template.j2 s3://${s3_install}/install/ansible/j2/ --storage-class STANDARD_IA
