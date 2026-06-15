---
layout: default
title: Plan-and-Apply-Terraform-content
---
---
layout: default
title: Plan-and-Apply-Terraform-content
---
# Introduction

Exact steps may depend on specific integration used, ie how you manage your terraform and content
You may need to adapt below steps if your deployment type differ from the proposed ones


# Terraform Cloud

login to Terraforn Cloud
go into your organization and workspace as needed
Choose Runs menu
if you just resync repo and tbere a was a automatic topology change update, you will have 2 entries stacked together. 
This is because Terraform is detecting git repo update before GitHub Action can react and redo the correct topology update (which happen just a few ms after) (this is only the case when instance-xxx.tf are updated)
The git changelog tell you in that case to discard the first plan 
discard it as needed then run plan in the most recent one. You may add a comment to improve history
Once the plan is completed, please make sure the proposed changes make sense (if the plan ask to destroy lots of asg, then you probably didnt read the above correctly !)
If ok, add a comment and do a apply

# Terraform cli

Once you have updated terraform files, make sure you kept the sane instance-xxx.tf files in terraform directory as previously (see topology)
Run terraform plan then terraform apply  
Optionally you could run terraform apply in one step if you prefer and analyze results before confirming apply
