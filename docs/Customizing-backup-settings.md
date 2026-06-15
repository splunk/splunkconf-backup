---
layout: default
title: Customizing-backup-settings
parent: Backups
nav_order: 1.5
---
# Making local customizations

Please do not modify configuration file in default directory as it belong to the app and will be overwritten when upgrading
Create local directory with _splunkconf-backup.conf_ file and only add lines that you want to change
Your local changes will take over default configuration

App can be distributed via Deployment Server as it is DS compatible. 

Please note this is also possible to overwrite a setting by creating _splunkconf-backup.conf_ file in system/local directory but this is not considered a good practise in general

# Format specificity (version < 1.9)

As the configuration files are to be imported directly within backup scripts, they don't include a usual [settings] stanza as this would break shell script (or would require additional logic to parse file)
Du to shell constraint do NOT add spaces around =
ie use key=value

# Format specificity (version >= 1.9)

Configuration loading has been changed to parse configuration file which include support for spaces around = . You should now also set things under [settings] stanza even this is not yet enforced. Configuration files from older versions can be used without modifications at this time. 

# Settings

the following settings are configurable 

| setting | default | possible values |
| ------------- | ------------- | ------------- |
| BACKUPTYPE |  1 | 1=targeted etc (highly recommended) 2= full etc (much bigger)|
| DEBUG |  0 | 0 =disabled, 1 = log in debug mode (very verbose)|
| LOCALTYPE |  1 | 1=date versioned backup (highly recommended for local backups) 2= only one with instance name in it 3=one one without instance name |
| LOCALBACKUPDIR  |  ${SPLUNK_HOME}/var/backups |  splunk user should have read/write access to this directory|
| HOSTSEXCLUDELIST | "testhost1,testhost2" | comma separated list of host where you want to disable backups completely , do not add spaces|
| DOREMOTEBACKUP | 1 | 0 = disabled , 1 = enabled if possible either by autodetecting configuration or because configured for|
| REMOTEBACKUPDIR | either automatic discover by tags in AWS/GCP context or to be configured | directory (usually remote via NFS or for rcp mode) for traditional backups, s3/gcs uri otherwise|
| REMOTETECHNO | 2 | 1 = nas (use cp), 2 = S3/GCS (use aws s3 cp or GCS equivalent), 3= remote directory via scp, 4 = rsync over ssh for dr purpose between 2 splunk instances |
| REMOTEOBJECTSTOREBUCKET | auto | bucket name , you dont need to set this unless doing backup to object store on prem. It is better to use tag on instance metadata so the app config is the same between different env |
| REMOTEOBJECTSTOREPREFIX | splunkconf-backup | only change this is the default prefix doesnt work for you |
| REMOTETYPE | 0 | 0=auto, 1=date versioned backup (nas choice) , 2=only one backup file with instance name (need versioned FS), 3= sane as 2 without instance name |
| REMOTES3ENDPOINTURL | auto |for on prem s3, specify the endpoint url as http(s)://mys3endpoint. When set, this will add  --endpoint-url $REMOTES3ENDPOINTURL to aws commands |
| REMOTES3STORAGECLASS | auto(STANDARD_IA) | S3 Storage class to use when storing backup to S3, see https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html for valid values and https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html for class descriptions |
| REMOTES3STORAGECLASSHOURLY | auto(STANDARD) | |
| REMOTES3STORAGECLASSDAILY | auto(STANDARD_IA) | |
| REMOTES3STORAGECLASSWEEKLY | auto(STANDARD_IA) | |
| REMOTES3STORAGECLASSMONTHLY | auto(STANDARD_IA) | | 
| REMOTEOBJECTSTORETAGS3 | 1 | by default we will tag objects send to s3, set this to 0 to disable it |
| AWSS3COPYMODE |  0 = auto (1 at the moment) |  1 = use aws s3 cp (no support for tags but tag command is called in sequential mode), 2 = use aws s3-apui copy-object (support tags but will fail if iam not correctly set) (advanced setting)|
| BACKUP | 1 | 0=disabled  1=backup etc
| BACKUPKV | 1 | 0=disabled 1=backup kvstore (will autodisable if no kvstore) |
| BACKUPSTATE | 1 | 0=disabled 1=backup state |
| BACKUPSCRIPTS | 1 | 0=disabled 1=backup scripts (will autodisabled if not used) |
| MINFREESPACE | 6000000 | under this limit backup will not start (this limit should be over the splunk limit (5G by default) where Splunk goes in detention mode) This should not be reached if appropriate space has been provisionned for backups |
| LOCALBACKUPRETENTIONDAYS | 20 | number of days after which we remove local backups (etc)|
| LOCALBACKUPKVRETENTIONDAYS | 20 | same for kvstore/kvdump |
| LOCALBACKUPSTATERETENTIONDAYS | 7 | same for state |
| LOCALBACKUPSCRIPTSRETENTIONDAYS | 100 | same for scripts |
| LOCALMAXSIZE | 7200000000 | This is 7.2G , please increase if you get space and depending on backup space, you can use special value auto to let app automatically set it |
| LOCALMAXSIZEDEFAULT | 7200000000 | This value can be used as reference when LOCALMAXSIZE set to auto (from version 1.9)  |
| REMOTEBACKUPRETENTIONDAYS | 180 | remote setting for etc purge (only for remote mounted backups)  |
| REMOTEBACKUPKVRETENTIONDAYS | 60 | same for kvstore |  
| REMOTEBACKUPSTATERETENTIONDAYS | 7 | same for state |
| REMOTEBACKUPSCRIPTSRETENTIONDAYS | 200 | same for scripts |
| REMOTEMAXSIZE | 100000000000 (100G) | purge remote on size |
| RCPHOST | notset |hostname of target host to use for remote backups | 
| RCPREMOTEUSER | splunk | target user for remote for rcp usage |
| RSYNCHOST | notset | hostname of targethost (the other one) |
| RSYNCREMOTEUSER | splunk | target user for rsync over ssh | 
| RSYNCREMOTEDELETE | 2 | 0 = do nothing, 1 = remote delete via rsync , 2 = leverage remote splunkconf-backup-purge |
| RSYNCDISABLEREMOTE | 1 | 0 = do nothing, 1 = ask remote splunk to stop (to avoid collision) |
| RSYNCAUTORESTORE | 1 | 0=disabled, 1 = enabled, use autorestore via rsync over ssh |
| KVSTOREREADYINIT | 100 | number of 10s loop to wait for KVSTORE to be in ready state before launching a backup (or restore)|
| KVSTOREREADYBACKUP | 100 | number of 10s loop to wait for KVDUMP to finish (protect for infinite wait situation but increase if your kvdump take longer so the remote kvdump backup can work|
| KVSTOREPOINTINTIMEMODE | 0 | 0=auto (default, currently legacy mode), 1=use legacy mode, 2=use point in time method |
