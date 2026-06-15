---
layout: default
title: Getting-credentials
parent: Restoring Backups
nav_order: 3
---
# Context

so you create a new env , it looks up from AWS console but how do you connect on it ?
You are at the right place

# Preparation

Get the following elements 
* AWS primary region (that is the same as TF(Terraform) variable)
* Secrets Manager  splunk_admin arn (that is a output of Terraform apply)
* Secrets Manager splunk_ssh_key arn (also output from Terraform)
* Get credentials from AWS admin that will allow you to fetch these elements
* clone repo locally or at least download getmycredentials.sh from

# Getting them example


./getmycredentials.sh us-east-1 arn:aws:secretsmanager:us-east-1:nnnnnnnnnxxx:secret:splunk_admin_pwd20230211111111111111-XXXXX arn:aws:secretsmanager:us-east-1:nnnnnnnnxxx:secret:splunk_ssh_key202302111111111111111-XXXXX




# Limitation

if you created the environment manually or by important a backup, then some or all of the secrets will either be not existing or empty 
