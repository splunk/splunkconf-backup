---
layout: default
title: Destroying-environment
parent: Restoring Backups
nav_order: 9
---
# Introduction

This page describe the steps to clean up a environment.
This mean both cleaning up what was created by terraform but also any content that was created while the environment was running.
If you create and destroy environment a lot of times in the same account/region/vpc (for exemple for testing purposes) . cleaning up correctly things is especially important.


## Terraform destroy

Either via cli or via terraform cloud UI

run `terraform destroy`

you will need to approve destruction

It is expected at this point that the following elements may not be deletable automatically
- route53 zones as the entries inside are not deleted automatically (theorically that would be possible by adding lots of dependencies in TF but that would complexify lot the configuration, this may be improved in future)\
- s3 bucket(s) that contain extra content that is marked protected. This is especially the case if you enable objectlock setting (this mostly need to be done at creation time du to the way objectlock works , cf AWS documentation)
- AWS SSM parameter with user-seed (if you dont deleted it and recreate later the same terraform, instances would used this seed but the secret manager content would be missing which is probably not what you want...)

## Route53 (sub)zone

- Go in AWS route53 console
- Go in the subzone
- Select all elements
- unselect ns and soa only
- delete records
- delete zone

# AWS SSM 

- go in system manager
- go in Params Store
- delete user-seed

# S3

if you enabled objectlock in non compliance mode, a AWS admin may unlock objects
if you enabled objectlock in compliance mode, then by design, you need to wait....
if not in objectlock and you still have objects that means you are supposed to review and clean up before deleting the bucket itself
