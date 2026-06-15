---
layout: default
title: Upgrade
---
---
layout: default
title: Upgrade
---
# Objective 


Upgrade Splunk software in a consistent way with recovery and backups
Please note this is not a rehydratation upgrade process as rehydration in that case would not be transparent and would not match [Splunk upgrade doc](https://docs.splunk.com/Documentation/Splunk/latest/Installation/HowtoupgradeSplunk)
However upgrade is done in a way that at every point of upgrade, if ever the instance fail , it would be recreated with the expected version.


# Requirements

recovery files have been updated
At the previous steps, updated files were pushed to bucket (mainly in install bucket under install prefix)
You should follow usual Splunk upgrade recommendations from documentation as this step just update the software but doesnt have any logic between instances nor any application check.


# Changing version from command line
Note : for this to work you need to change IAM permissions (not by default)
As root , cd /usr/local/bin then run [splunkconf-upgrade-local-setsplunktargetbinary.sh](https://github.com/splunk/splunkconf-backup/blob/main/src/splunkconf-upgrade-local-setsplunktargetbinary.sh) xxxx.rpm   where xxx.rpm is the version you want to target
This is not changing the version in template which should be changed via Terraform or AWS console (depending on the chosen method to deploy)


# Prechecks

as root, run /usr/local/bin/splunkconf-upgrade-local-precheck.sh
the script download and update all scripts.
## Versions previous to 20230622 (original version on host)
  At the last step, it also update itself (the update is done last as update itself for a shell script can have unexpected behavior)
  As so, it is safer to launch the script a second time 
## Versions from 20230622
  Script autoupdate itself by using a helper script so will always run the latest downloaded version (from bucket). it is no longer needed to relaunch it a second time (script is telling at the end "_updated version=xxxxx, no need to rerun it_" )

# Upgrade

as root, launch /usr/local/bin/splunkconf-upgrade-local.sh
This launch recovery in upgrade mode 
You can follow upgrade process via tailing /var/log/splunkconf-cloud-recovery-debug.log
