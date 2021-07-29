Copyright 2021 Splunk Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


Contributor :

Matthieu Araman, Splunk


This app backups Splunk configuration files, kvstore, state + additional scripts if used

- locally

Optionally on a remote location 
- via a remote mount 
- on a cloud bucket (static or automatically via instances tags) (currently implemented AWS and GCP)

The dashboard part is to be used on Monitoring Console
Monitoring Console check to be runned on Monitoring Console

You need to edit the lookup with your expected device backups for the dashboard to be effective

You can customize the app in splunkconf-backup.conf file
Please use a local copy (do not edit the default) in splunkconf-backup/local/splunkconf-backup.conf and only override what you need to change (do not copy the whole)

The settings control various limits about :
- backup location (local default is $SPLUNK_HOME/var/backups)
- min free space for backups to be run
- max backup size
- local and remote backup purge policy (not for cloud cases, cloud lifecycle is what purge old backups)
- naming convention for backups (locally they should be versionned, on a versionned storage like S3 or GCS, we use a non versimed naming convention)

- Restoration is done outside the app except for kvdump as it need to be authenticated withing Splunk

for this purpose at first start, the restore kvdump script check for a toberestored kvdump file and if successfully restored rename it afterwards)

Please note the backup can be launched from outside Splunk except for the kvdump backup (to avoid storing credentials, this need to be run inside Splunk)

To launch it as splunk user 
cd $SPLUNK_HOME/etc/apps
./splunkconf-backup/bin/splunkconf-backup.sh etc 
(for example to backup etc)

Note on Splunk version 
This app works also on pre7.1 version where kvdump is not available
In that case a tar.gz kvstore backup is done (by default without restarting splunkd)
-> this method is not safe especially with heavy moving kvstore
the script will then try several times and use the latest one

Automatically after the version is higher than 7.1, it will switch to kvdump which is safer

Note that for reusing kvdump, there are product fixes that much improve the time and performance, especially with huge kvstore
If the restore take ages, it may be upgrade time !

Note on default backup schedule
- backup purge by default are scheduled every 10 min
This is important to free up space before doing new backup in low disk conditions (you DID provisionned space for backups ?)
Note the purge will always keep at least one backup of each type and try to avoid backup starving conditions (but there are low disks conditions where that can become impossible so be sure to check backup states)


By default backups run at the following pace :

hours 2AM, 6 to 20 and 23h

minute 11 -> scripts
minute 12 -> etc 
minute 14 -> state
minute 20 -> kvstore in auto mode (ie kvdump on recent splunk versions) 

You can custonize the frequency by changing inputs.conf
(in local)

App deployment :
App can be deployed through Deployment Server

App is to be used on all central components except indexers (as it should be very easy to rebuild a indexer that get apps from CM and resync data via clustering + smartstore if used)


Logs :
app is logging to _internal Splunk index
source is splunkconf-backup.log
you can use the dashboards to visualize state centrally from the monitoring console

you may need to edit the splunkconf-expect lookup giving your host list (it is just for the dashboard not to have to search in all the internal logs but just the one you are expecting a backup from)
you will need event timeline visualization app from splunkbase on the monitoring console to light up the dashboard ( https://splunkbase.splunk.com/app/4370/#/overview) 

Cloud integration :
in a cloud env, to avoid hardcoding backup bucket name (as the bucket names are unique so that make moving betwen different instances like test and prod problematic with hardcoded values), instance tags are used
Script will try to use information in this order :
- configuration file (not recommended)
- dynamic by querying instance tags (detecting cloud provider)
- by using /etc/instance-tags file which has been prepared by cloud recovery script (outside this app) 

Terraform scripts to create buckets with lifecycle policy and IAM for GCP and AWS are available in the git repository below 


Common problems :
- Low disk conditions -> increase disk allocated for backups
- backups that get bigger than the max backup size -> increase max allowed size (and check you have also allocated the disk space)
- Permissions issues to write backups -> check and fix permissions
- files changing as we read for state -> this get reported back and retried multiple times but some files like fishbucket are quite challenging to backup correctly as sometimes constantly change) 

Repository + additional stuff that include reusing the backups in a byol cloud env available at 
https://github.com/splunk/splunkconf-backup





