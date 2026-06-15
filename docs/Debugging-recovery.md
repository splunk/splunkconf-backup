---
layout: default
title: Debugging-recovery
---
---
layout: default
title: Debugging-recovery
---
# Context

There are 2 parts in recovery :
1. Up to the point Splunk software will start first
2. At first Splunk start, splunkconf-backup app will detect recovery mode and initiate a kvdump recovery if needed 

Note that instructions for first part only apply if you leverage included recovery scripts inside iaas context. 
You may junp directly to last part if applicable

## Instance Recovery

1. Instance start

First issue could be that new instance is not started by cloud provider.
In that case either look at cloud logs or go in cloud console in the autoscaling group UI to look for the reason
Possible reasons may be : 
- connection draining -> it could take a few seconds/minutes to drain out open connections when a instance shutdown , preventing a new one to be started initially (just wait or for the impatient you may look at tuning the ASG advanced settings)
- instance type requested is not available in the specific region/az requested (if that is temporary, it should retry automatically) -> change instance type or check/discuss with cloud provider 
- cloud limit reached (like number of ressources allowed for your account) -> ask for increased limit 
- insufficient network ressources (ip) in the specified network -> check and increase network size if applicable
- unsupported combination in template (like type of boot disk for a specific instance) -> It is usually corrected by setting the correct value in terraform variables

2. Instance initialization

the first thing a instance does is execute cloud init (after starting image)
this script try to do minimal stuff and load+launch recovery script from cloud storage
logs are in /var/log/cloud-init.log

If the instance is unable to reach cloud storage to get recovery and permissions (IAM) + tags looks correct then one of the common reason is a network misconfiguration preventing to reach cloud storage. (a instance in a private network will need a nat gateway for example)

3. Cloud Recovery

Recovery is logged into /var/log/splunkconf-cloud-recovery-debug.log
Every big steps is prefixed with * to ease reading log files by identifying steps

If the recovery breaks on update or finding Splunk software to download , you may have to follow instructions related to working in disconnected mode. 

Other possible errors may be :
- disk space too short -> increase to reasonnable disk space
- instance spec much too low -> trying to recover on a single shared vcpu with CPU credit may be challenging, please make sure you enough ressources 
- OS image not currently supported by recovery -> change image to a supported one (ie rpm based)
- cloud provider not properly detected -> this could happen for newer image/kernel -> make sure you use latest recovery or report bug so support can be updated. 
- Splunk initialization failure or version detection mismatch -> if you upgrade Splunk on a version that was not existing at time your recovery version was released, you may have to update to a newer version or report bug (in general newer versions should work)  

4. Splunk software failures to start
if something got wrong during recovery, it may only fail at that time (like permissions issues)
you may find the reason in SPLUNK_HOME/var/log/splunk/ directory (either in splunkd.log or the more recent log file in general found there)

## KVDUMP recovery failures

logs are in SPLUNK_HOME/var/log/splunk/splunkconf-backup.log
you may want to check backup exist in cloud storage backup bucket + has also being copied to the right place expected by recovery
For remind, collections should exist or recovery wont work and collection definitions should have been restored as part of etc targeted backup recovery above.
