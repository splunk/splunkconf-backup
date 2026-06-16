---
layout: default
title: OS Image
parent: Customizing Terraform
nav_order: 3
---
# OS Image


## GCP

Latest GCP OS Image will be used (linux rh like)

## AWS

The following AMI are selectable with these settings : 

| Variable | Default | Description |
| --- | --- | --- |
| `enable-al2023` | yes | use newer AMI AL2023 (Amazon Linux 2023) otherwise use AWS2|
| `enable-customami` | no | dont use AWS AMI but a custom one (that should be RH like) |
| `ssmamicustompath` | notset | full SSM path to the AMI in the region |


Note the following images were tested at some point : 
| Image | Status | Description |
| --- | --- | --- |
| `AWS1` | Highly deprecated (please stop using this !) | legacy AWS AMI , rh6 like , no systemd or wlm ! |
| `RH/Centos 7`| Deprecated | No longer supported , yum update is so slow..... |
| `RH/Centos 8`| Deprecated (*) | works fine but you need a version with os updates/support !|
| `RH/Centos stream 9`| ok but slightly tested| systemd support and cgroup logic for AL2023 should handle all cases but not all versions tested |
| `AWS2` | OK |Highly tested but you may want to migrate before support end, see https://aws.amazon.com/amazon-linux-2/faqs/ |
| `AL2023` | OK | newer and latest, cgroup automatically downgraded to v1 at the moment|
