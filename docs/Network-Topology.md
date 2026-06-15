---
layout: default
title: Network-Topology
---
---
layout: default
title: Network-Topology
---
# Introduction


network topology will vary depending on ha, cost, target usage , compliance needs,...
The default setup is meant to work by default for most cases in a non production env with limited cost (and so the terraform is self usable)
Other topologies are possibles either by setting terraform variable or by completely replacing the network part 

# Public or private networks

if your instance(s) are supposed to be directly reachable from Internet , then use public network type. 
Otherwise using private network type reduce surface attack (ie even if mistake is done on security groups, instance isnt directly reachable)

use associate_public_ip variable to control this setting

when you use private network, nat gateway will be needed (unless you are routing to another vpc that provide such feature)
As AWS charge per hour for a nat gateway, this become a big cost in a test env.
As such , the default only start one nat gateway.
Alternatively, the bastion host (if used) can be used as a nat instance (which is even cheaper for testing) with a additional routing configuration (that is not yet automated so that is why it doesnt default to this)
In a production setup, it is obviously required to have a nat gateway per AZ in AWS VPC (as recommended by AWS)


# Multi zone

in a region, 3 zones are supposed to be used
As such, you will find 3 existing networks definition for AWS (in GCP, this is not needed as networks are extended in a region)

 
# S3 and VPC Endpoint

if using private network, if you use a nat gateway to reach S3 in same region, that will be seen as a outbound traffic and behind charged like this. To optimize cost, you probably want to use a VPC endpoint for S3 in that case

# Customizing network ranges

See variables-network.tf for most network variable and to change default ip
Please make sure network size in a single AZ is big enough (after reserved addresses are taken into account) for all the instances that could be in that zone (ie if the 2 other zones failed, autoscaling will ask for IPs in the remaining network)

# Segregation inside networks

Contrary to a on prem setup where the firewall is between networks, the security is applied at host level in iaas env.
As the security groups are using dynamic references, there is no downside to share on same network different instances that would have been traditionally segregated on prem. 

# Using provided bastion

In order to reach instances on private network, you may use the provided bastion instance type. For this please add bastion instance name to topology (see [Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection](./Cloning-repository-and-leveraging-GitHub-Actions-for-instance-selection.md))

# Using existing bastion 

If you have a existing bastion (for example connected via transit gateway) and you wish to force admins to leverage it to connect to instance, you just have to add bastion ip(s)/network to admin_networks ACL in Terraform variables. 
