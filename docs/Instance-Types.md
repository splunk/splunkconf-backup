---
layout: default
title: Instance-Types
---
---
layout: default
title: Instance-Types
---
# Instances add/remove and numbers

You may customize number of instances per ASG

the terraform variables (see variables.tf) are in general xxxx-nb

## Removing a instance type

You may completely remove a instance type by removing the instance from topology definition (in GH action see [Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection](./Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection.md))
This will remove (almost) all the configuration associated with the instance including compute, autoscaling groups definition,.....

## Enabling a instance type

See [Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection](./Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection.md) for adding a new instance

you may for some instance have to set a enable variable in terraform (see variables.tf)


## Stopping a instance type
In order to save on cloud cost without completely removing instance definition, you may set nb variable (that match the instance) to 0
After applying, this will terminate all the instance in ASG group
Make sure backup ran before as the instance will restart with latest backup if applicable

## Multiple instances
Only specific instances type can have multiple instances. This is because they dont need to store a specific state via backups. Such instances can be intermediate forwarders farms or indexers. 
Do NOT set more than one instance number for single instance that have a backup by instance name (as 2 backups with same names would conflict) 

# Instance type

default instance types are meant to minimize cost while being big enough for testing purposes
You may want to customize instance type to match appropriate sizing matching your target usage.
Make sure you select a instance that exist or autoscaling creation will fail.
