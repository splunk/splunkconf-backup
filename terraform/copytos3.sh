#!/bin/bash

# Matthieu Araman , Splunk
# this script called by terraform


# first arg = bucket install
# second arg = bucket backup

s3_install=$1
s3_backup=$2
aws s3 sync ./packaged s3://${s3_install}/packaged/ --storage-class STANDARD_IA; 
aws s3 sync ./splunkconf-backup s3://${s3_backup}/splunkconf-backup/ --storage-class STANDARD_IA; 
aws s3 sync ./install s3://${s3_install}/install/ --storage-class STANDARD_IA
