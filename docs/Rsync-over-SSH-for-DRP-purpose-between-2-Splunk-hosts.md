---
layout: default
title: Rsync over SSH for DRP purpose between 2 Splunk hosts
parent: Backups
nav_order: 3.7
---
# Introduction
In this mode, you have 2 running Linux instances with Splunk deployed
Only one instance is started from a Splunk point of view
On the running instance, backups are rsynced to remote hosts backups directories.

![rsync over SSH schema](https://github.com/splunk/splunkconf-backup/blob/main/docs/images/splunkconf-backup-rsync.png)

# Requirements
- splunkconf-backup app version 1.6 minimal (1.8+ to get autobackup at start and autorestore)
- SSH keys set up between 2 hosts
- Splunk deployed with identical versions on both hosts
- systemd configuration set (via policykit) so splunk user can start/stop its own service from splunk user (used to reduce risk of 2 active instances, the active instance try to stop the remote one just in case)
- disk space for backups on both hosts with extended retention (please tune up splunkconf-backup max disk space setting accordingly) 
- same flows opening 
- external ability to switch over to the backup host (for example by updating DNS or by using a LB if applicable) 

# Handover/Recovery

Note : For manual failover, please stop splunk service on active host before activating failover host (even if the second host will check and try stop the other instance to avoid a conflict, this should be considered a fallback mechanism)


In case of first host failure, you need to :
Version <1.8 or autorestore disabled : 
- restore latest splunkconf-etc and state backups
- copy/rename latest kvdump with the -toberestored extension (see wiki page)

Starting with 1.8, backup are automatically restored after being rsynced so the second instance is ready to start (kvdump will be injected at first start automatically)

For all versions 
- start Splunk on secondary host



# Recovery and Split Brain situation
In case you loose first node (for example by electrical power), you may have both nodes start at the same time , creating a conflict (as they are the same Splunk) 
There is no technical way to solve this 100% , the only way to solve it is to take a human decision and stop the instance that is not supposed to be on. 
In case you didnt react (ie choose) in time, the 2 instances will try to stop the other side, leading to unexpected situation

# Manual or automated switchover
The simplest mode is to manually (or via script) switchover (decided by a human who has a view on operational situation)
It is also possible to partially or completely automate the process by adding a layer at Linux level that will : 
* Make sure only one splunk instance is started
* Has the ability to call a recovery script that redeploy backups before starting splunk service
* Either take a human decision to switchover or automatically (but beware of above point on split brain situation) 
They are a number of existing solutions that can help for this (like pacemaker/corosync). Choice to implement or not such a solution will also depend on operational constraints and existing skills on these technologies which are very environment dependent.

# Difference between backup rsync and file rsync
This feature rsync backup files but does NOT do a continuous rsync of files to remote host as doing things has lots of challenges which are already what Splunk Search Head Cluster functionality provides. 
For reference (see Splunk docs) , SHC need at least 3 nodes either in one site or in 3 sites to solve quorum/split brain issue in a automatic way. (see https://docs.splunk.com/Documentation/Splunk/latest/DistSearch/DeploymultisiteSHC )

# Testing mode

you can use instance-hfab.tf instance template to simulate 2 hosts that are configured to do rsync over ssh 
the terraform template will setup the 2 instances, open flows, setup ssh keys and deploy splunk on both nodes.
You will have to configure Splunkconf-backup with the following settings : REMOTETECHNO=4 and SYNCHOST="the other host name from terraform output".
Note this is just for testing purpose as this mode is mainly for on prem 2 DC use cases. (the S3 + ASG mode is the preferred one in AWS iaas mode which is the default)
