---
layout: default
title: Design architecture
nav_order: 1.5
---
splunkconf-backup app design : 

* minimize backup size by excluding data that can be either rebuilt or redownloaded from other source + leveraging compression
* maximize backup consistency by either using API or trying to detect data changing during backups (and use retry + warm logic)
* minimize ressource impact on host and on Splunk service
* each backup is independant from the previous, no database , purge mean just deleting backup file.
* purge by removing older backups while keeping global backup size under configured limit + protecting latest backup
* default app with no config should just start automatically doing backups over the next hour with no specific configuration
* ability to copy backups externally either to remote FS (mounted FS, network transfer over scp/rsync) or object store (leveraging versioning in that case)
* autoconfiguration for remote object store in AWS/GCP via tags/metadata + leverage IAM permissions to not have to hardcode any credentials in configuration files
* ability to restore to the same recovery point as time where backups were done should work with minimal effort
* optimized logging of backup operation so that they can be searched easily via SPL
* monitoring console checks to warm on failures (error and disk starvation issues) and allow integration with alerting systems via alert_action framework (things may/will break...)
* dashboard to give consolidated view in a distributed env 

![backup lifecycle](https://github.com/splunk/splunkconf-backup/blob/main/docs/images/backup-lifecycle.png)

As a side effect of theses design decision, backups were not stored in a git repo because even if that would allow leveraging some nice feature of git, that would also increase risk of backups completely failing, notably du to disk size increase and cleanup challenges  

When recovering in a env with API and managed services that can be leverated (such as AWS/GCP): 
* no dependence on a central host (ie a provisionning host)
* use of autoscaling functionality to automatically initiate recovery to the last recovery point (ie minimize downtime) and allow instance to be recreated in a different zone in case of zone failure (number of target instance will always stay at one if the role is supposed to be unique)
* same autodiscovery mechanisms (via tags/metadata...) as for backups (to discover S3 bucket location for example) so that generic recovery script can autoadapt
* leverage DNS API so that ip changes (which are to be expected for example between 2 AZs in AWS) are transparent and dont require configuration change at Splunk level 
* ability to reinject a backup from a older version in the right order so to prevent conflict (but that wont save you from reading upgrade notes and releases notes)
* in place upgrade in a consistent way so that instance would be recreated with same version in case of failure
* ability to reuse backup from a different env by autoadapting configuration (useful to take backups from a prod env to a distinct test env simulate a upgrade with no manual change) 

Note : objective is not to backup any indexed data , please leverage object storage functionalities (versioning, object lock,..)  or traditional backups if needed for this purpose


## recovery principle

the idea is to combine backups with cloud mechanisms to restore to the last recovery point and leverage DNS API so other components can still find the component(s) 

![recovery cloud ASG principle](https://github.com/splunk/splunkconf-backup/blob/main/docs/images/recovery-cloud-asg-principle.png)

![Single instance ASG example ASG events with DNS updates](https://github.com/splunk/splunkconf-backup/blob/main/docs/images/singleinstance-asg.png)

![Multi instance ASG example ASG events with DNS updates](https://github.com/splunk/splunkconf-backup/blob/main/docs/images/multiinstance-asg.png)
