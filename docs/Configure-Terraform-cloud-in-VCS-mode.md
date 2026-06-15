---
layout: default
title: Configure-Terraform-cloud-in-VCS-mode
---
---
layout: default
title: Configure-Terraform-cloud-in-VCS-mode
---
# Objective 

Connect terraform cloud to cloned repository via VCS mode , customize variable and environnement variables in order to make apply run succesfully

## Preparation

You will need at least : 
* github account 
* associated cloned github repository configured vith topology variable 
* terraform cloud account (free account is enough to start with, you may need /want a different one for access to other enterprise features)
* access to AWS account 
* AWS_ACCESS_KEY and secret created into this account with appropriate permissions needed for terraform to create ressources 
* choice of AWS primary region (AWS secondary region if you want to sync backups to a secondary)
* acl list (ip networks and/or ip) to authorize for admin access (ie at least your ip, use 0.0.0.0/0 for open access)
* existing public zone name that belong to you
* name for a subzone to be created by terraform (that will be created automatically inside this parent zone if the parent zone is inside AWS or you will have to add NS record yourself)
* instance type you wish (if you want to change default)

## Terraform Cloud preparation

* create a organization if needed (or use a existing one)
* create a workspace

### Workspace creation

* choose VCS mode then github 
* you will be redirected to github in another tab in order to install Terraform Cloud app inside your github
Note you may restrict the github app to just the cloned repo or use All repositories
* clic install , select cloned repo when necesary
* go back to terraform cloud, you should see repo in the proposed list (or the previous step didnt worked correctly)
* select it and clic create workspace

Do NOT run a plan now, we need to set variables before

### Global variables setup

go in settings then variable, create a variable set named splunkconf-backup

create as ENV the following : 
* AWS_DEFAULT_REGION   (value is your primary region)
* AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY, sensitive with the value from the AWS account provided previously

create as variables the following : 
* region-primary with same value as configured above for env 
* splunkacceptlicense with yes value (after reading and accepting Splunk license at https://www.splunk.com/en_us/legal/splunk-software-* license-agreement-bah.html , that value is forwarded to Splunk binary in order to allow recovery to work without human intervention) 
* splunkadmin-networks, HCL type format such as ["10.0.0.0/8","172.16.1.1/32"]  with the values of your admin networks/ip 

Then go back to workspace and apply variable set

configure at least the following variables (look into variables*tf files for the full possibilities with description)
* dns-zone-name-top existing parent zone
* dns-zone-name sub zone that will be created by TF and used by route53 
you may want to customize instance size, number when applicable and various acl here

then go in workspace general settings and set Terraform Working Directory to terraform (or terraform will complain it doesn see any tf files)
Save settings then clic on Start a new run
Verify plan 
if it looks ok then apply it

then go in AWS console and verify the associated ressources were created (iam, sg, asg, instance templates, ...)
