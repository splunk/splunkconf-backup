---
layout: default
title: Using terraform in cli mode
parent: Restoring Methods
nav_order: 2
---
# Introduction 

Using terraform cloud in VCS as explained in [ Configure-Terraform-cloud-in-VCS-mode ](./ Configure-Terraform-cloud-in-VCS-mode .md) allow to run without having to deploy terraform locally. However, some users may prefer to manually clone the content and run terraform from there. 
Instructions there document this path. There are multiple variations on this with remote state, use of enterprise feature that are outside this page scope but can be used in complement.

# Pre installation

- install terraform latest version 
- install git
- install AWS SDK and run AWS configure with your credentials and your default region

# Clone content

Run 
`git clone https://github.com/splunk/splunkconf-backup.git`
then cd into
`cd splunkconf-backup`

# Setup topology

This is corresponding to the configuration via [ Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection ](./ Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection .md) 

Alternatively, you could clone in your local github and use the GitHub Actions topology method instead then clone from your copy to your local instance where you will run terraform

`cd terraform;cp topology.txt topology-local.txt`
edit topology-local.txt with your instance list 
the possible choices are all the instances-xxx.tf files in terraform and terraform/instances-extra directories

return to top directory
`cd ..`

run `./helpers/tftopology.sh` , which will only select instances-xx.tf that you need in terraform directories and will move the others in instances-extra directories
Remember that you may need to run this again when you resync from original repo

# Initialize Terraform

return to terraform directory and initialize terraform (but dont apply yet !)
`cd terraform;terraform init`

Optionally configure remote state here (see terraform docs)

# Configure Terraform variables

create a file terraform.auto.tfvars in terraform directory

configure variables (read wiki and all the variables-xxx.tf files to have a better idea of the posibilities)

# Run validate

`terraform validate`

then correct any reported errors (for example, validation check in variables could report a issue or a typo would make syntax incorrect)

When everything ok, you have received `Success! The configuration is valid.` message

# Run Plan

`terraform plan`

Analyze output , check for errors, correct variables if needed and relaunch until satisfied

# Import state

if you already have existing content created outside terraform, you may import it at this point.
Example can be importing existing networks or existing route53 zone

# Run apply 

Run either `terraform apply` then approve by typing `yes` or directly `terraform apply -auto-approve`

Check results and outputs
Check cloud console , you should see instances, instances template, security groups, ASG, S3 buckets ,IAM ...
 being created as mentionned in Terraform output

# Get credentials

(see also [ Getting-credentials ](./ Getting-credentials .md) )

Either go in AWS Secret Manager via console + get urls from terraform output
(note if you enabled public ip , you may have 2 entries per host, please add -ext suffix to get public ip) (or look in route53 to see the names created)
This is enough to connect via UI

to connect by SSH, you will need additional steps
`cd ../helpers`
take values from terraform output and run something like
`./getmycredentials.sh us-east-1 arn:aws:secretsmanager:us-east-1:nnnnnnnnnnnn:secret:splunk_admin_pwdxxxxxxxxxxx-xxxxx arn:aws:secretsmanager:us-east-1:nnnnnnnnnnnn:secret:splunk_ssh_keyxxxxxxxxxxxxxxxxxxx-xxxxx`
use the output to connect to your instances

In both case, make sure you added the necessary source network IP(s) in the admin network variable

# Connect to your instances

you should have instances running with backup at this point but they probably still need to be provisioned

# Provisioning

Read and action on the provisioning part (see [ Provisioning ](./ Provisioning .md) )
