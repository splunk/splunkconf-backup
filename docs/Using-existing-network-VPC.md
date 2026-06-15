---
layout: default
title: Using-existing-network-VPC
---
---
layout: default
title: Using-existing-network-VPC
---
# Context

in order to have this terraform be self-usable, it include a simple topology, which is useful for easyly building test environments.
However, most people will already have existing VPC with networks already created.
This page is describing how to set variables in order to reuse existing network
Please read [ Network-Topology ](./ Network-Topology .md) as a prerequisite to this page

# Disabling auto creation of network ressources

As a remind, you are supposed to have 3 public networks and 3 private networks (one par AZ in a region/VPC) to maximize resiliency and minimize instance loss in case of AZ failure. 
Even when internal connectivity depend on specific AZ(s) , it may still be a good idea for the above reason and also because AZ name are logical per account by AWS design so in a multi account mode , AZa in 2 different accounts may not be the same.
As AWS control flow at instance level and security groups allow to use dynamic sg(Security Group) reference to open flows, the zoning logic is defined at functional level and doesn't need to be done at ip level (like it would be on a traditional on prem network where flow control rely on different subnets being used  

Please set the following terraform variables

| Tag | Description | Value |
| --- | --- | --- |
| create_network_module | disable vpc and network creation in network module | false |
| vpc_primary_id_import | existing VPC id | "vpc-xxxxxxxxxxxxxxx" |
| associate_public_ip | whether to deploy instance on public or private networks | true if instances supposed to be reached directly via public IP, false if you dont need direct access via public IP |
| cidr_subnet_priv_1_id_import | existing private network on AZa | "subnet-xxxxxxxxxxxxxx" |
| cidr_subnet_priv_2_id_import | existing private network on AZb | "subnet-xxxxxxxxxxxxxx" |
| cidr_subnet_priv_3_id_import | existing private network on AZc | "subnet-xxxxxxxxxxxxxx" |
| cidr_subnet_pub_1_id_import | existing public network on AZa | "subnet-xxxxxxxxxxxxxx" |
| cidr_subnet_pub_2_id_import | existing public network on AZb | "subnet-xxxxxxxxxxxxxx" |
| cidr_subnet_pub_3_id_import | existing public network on AZc | "subnet-xxxxxxxxxxxxxx" |
| enable-idx-hecelb | not currently supported when create_network_module=false | false |
