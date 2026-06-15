---
layout: default
title: Updating-Upgrading
---
---
layout: default
title: Updating-Upgrading
---
# Introduction


Updating recovery and terraform how to will depend on automation level used.
Please choose the appropriate content adapted (and consistent) to your usage

# updates and splunktargetbinary

Warning if you just want to update recovery without upgrading Splunk at next recovery time (which can lead to a inconsistent state if you are using multiple instances), you should have : 
- changed splunktargetbinary variable from auto to your version (that is usually rpm file name)
- downloaded then uploaded the corresponding rpm in the install bucket under install prefix

# Terraform in VCS mode

 
Use [ Resync-cloned-repository ](./ Resync-cloned-repository .md)
Then [ Plan-and-Apply-Terraform-content ](./ Plan-and-Apply-Terraform-content .md)


# Terraform standalone

update your local content from github repo 
Then use [Plan-and-Apply-Terraform-content#terraform-cli ](./Plan-and-Apply-Terraform-content#terraform-cli .md)

# Manual update 

Download updated recovery files from src directory
Upload them to install bucket in install prefix
