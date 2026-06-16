---
layout: default
title: Disconnected mode
parent: Customizing Terraform
nav_order: 5
---
## Introduction

default configuration assume Internet connectivity (from instance to Internet) in order to : 
* update OS with latest packages for security and stability
* download and install additional packages 

While this is convenient, if your instances are not able to reach Internet directly , you may want to use alternate mechanisms, which will require setting a few terraform variables

## Connected mode

There are multiple choices :
- fully connected  
- yum only mode. Disconnected mode with only update at instance start (will use yum update in the background so if you have custom repo or custom proxy on the AMI , it should work transparently)
- disconnected (recovery will not try, it is up to you to make sure the appropriate packages are present)

## Splunk binary 

### Version
by default, recovery will try to use hardcoded version in script
You may want to specify a custom version by changing splunktargetbinary variable from auto to the target value 

### Download location
Recovery will try to find splunktargetbinary in the install prefix within the s3 install bucket.
Please [download](https://www.splunk.com/en_us/download/splunk-enterprise.html) and upload Splunk binaries that you need there.
If not provided and you are using default setting in connected mode, recovery may try to download binary automatically 

### Binary GPG check
the default method is using RPM version, which come signed with Splunk GPG key. As a additional check, recovery will check and fail if ever the signature would not match to protect from malicious attack or corruption during file transfer. 

### Splunkacceptlicense
In order to deploy Splunk as part of recovery, recovery script will pass over splunkacceptlicense variable to Splunk software. You should have read and accepted Splunk License at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html and set accordingly splunkacceptlicense variable in terraform (or recovery will not complete). You may also need to provide a license file, see type of licenses at https://docs.splunk.com/Documentation/Splunk/latest/Admin/TypesofSplunklicenses
 
