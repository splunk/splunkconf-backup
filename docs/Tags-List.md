---
layout: default
title: Tags-List
---
---
layout: default
title: Tags-List
---
# Introduction

recovery script leverage tags which are either statically configured in terraform configuration files (.tf) or via variables
Please be aware not all these tags are currently defined via terraform variables and defined in instance template.
If you need and understand tag usage and context, you may customize your instances tags with more tags
Some of these tags are also mentioned elsewhere in wiki. In that case please refer to the specific page (example for disconnected mode customizing splunktargetbinary,....)
 


# Tags List 

tags are case sensitive

Tags correspondance with backup configuration settings (optional, app works with default settings in most case)
Tags values here will override value from configuration file (see [ Customizing-backup-settings ](./ Customizing-backup-settings .md) )
| Tag | Matching configuration setting | 
| --- | --- | 
| splunkbackup | BACKUP |
| splunkbackupkv | BACKUPKV |
| splunkbackupstate | BACKUPSTATE |
| splunkbackupscripts | BACKUPSCRIPTS (this is autodisabled if not used) |
| splunklocalbackupretentiondays | LOCALBACKUPRETENTIONDAYS | 
| splunklocalbackupkvretentiondays | LOCALBACKUPKVRETENTIONDAYS |
| splunklocalbackupscriptsretentiondays | LOCALBACKUPSCRIPTSRETENTIONDAYS |
| splunklocalbackupstateretentiondays | LOCALBACKUPSTATERETENTIONDAYS |
| splunklocalbackupdir | LOCALBACKUPDIR |
| splunklocalmaxsize | LOCALMAXSIZE |
| splunklocalmaxsizeauto | LOCALMAXSIZEAUTO |
| splunkminfreespace | MINFREESPACE |
| splunkdoremotebackup | DOREMOTEBACKUP |

Note : there are a few more settings via configuration file that may not make sense by tags. If you think there would be a need to add them here (and they are not present in the following sections on this page), please ask




| Tag | Description | Status |
| --- | --- | --- |
| splunkinstanceType | instance type. For a ASG with 1 instance, that become the instance name. Special type = idx (recovery script will automatically detect zone and adapt splunk site for cluster to match AZ) (or idx-site1, idx-site2, idx-site3 if you prefer) (there can be one ASG for all indexer so that cloud redistribute instances to other AZ automatically in case of AZ failure)| Required |
| Name | name that will appear in AWS console (usually same value as splunkinstanceType, do not set for idx) | Optional |
| splunks3backupbucket | cloud bucket (s3/gcs) where backups are stored | Required |
| splunks3installbucket | cloud bucket (s3/gcs) where install files are stored | Required |
| splunks3databucket | cloud SmartStore (s3/gcs) bucket | Optional |
| splunkorg | name used as prefix for base apps | optional but recommended |
| splunkdnszone | this is used to update instance name via dns API (route53,...) in order for the instance to be found by name | Required|
| splunkdnsmode | set this to disabled or lambda if running update via lambda function in AWS| optional, default to inline|
| spunkmode | set this to uf to deploy a uf instead of a full instance| optional |
| splunkacceptlicense | setting passed along to the Splunk initialisation script so Splunk software can start  (see Splunk license at https://www.splunk.com/en_us/legal/splunk-software-license-agreement-bah.html)| Required (yes|no) |

Tags for controlling how os hostname and splunk hostnames are managed
| Tag | Description | Status |
| --- | --- | --- |
| splunkhostmodeos| whether to set hostname at system level | set : we will change hostname (with the logic set via splunkhostmode) , vanilla, os or ami (default): let ami set it|
| splunkhostmode | which method to adapt host on splunk side | instance (default)  : we set it from splunkinstancetype (this is the key to be able to find backup the backup associated to this instance, make sure you understand what it does and are in the use case below if you go away from default as this will impact backup), prefix : we build a value with splunkinstancetype and os host (this is for intermediate farm usage, so each instance has a common name for serverclass but still a different one to not conflict on backups. However this assume instance is stateless and can get it config back via DS), os : we let Splunk set it from os host name (this will also impact backups)|

Please note that when instance is recovering with a backup, backup values may override splunkhostmode tag 



Tags to be used for lambda at ASG level (only needed if configured for lambda (AWS))
| Tag | Description | Status |
| --- | --- | --- |
| splunkdnszone | this is used to update instance name via dns API (route53,...) in order for the instance to be found by name | Required|
| splunkdnsnames | name(s) to update in the zone when a autoscaling event occur  | Required|
| splunkdnsprefix| prefix to add to each dns entry| Optional , default to 'lambda-' , set to empty or disabled if you dont want a prefix to be added|



Tags to use for upgrade scenarios and/or backup bootstrap between env (exemple : to restore and auto adapt a prod backup to a test env

| Tag | Description | Status |
| --- | --- | --- |
| splunktargetbinary | splunkxxxx.rpm You may use this to use a specific version on a instance. Use the upgrade script for upgrade scenario if you dont want to destroy/recreate the instance | Optional (recovery version and logic used instead) |
| splunktargetenv | prod, test, lab ….  + This will run the optional helper script appropriate to the ena if existing | Optional |
| splunktargetcm | short name of cluster master (set master_uri= https://$splunktargetcm.$splunkdnszone:8089  under search|indexer cluster app + in outputs for idx discovery)  | Optional but recommended (default to splunk-cm which will effectively set master_uri= https://splunk-cm.$splunkdnszone:8089 ) |
| splunktargetds | short name of deployment server (set targetUri= https://$splunktargetds.$splunkdnszone:8089  in deploymentclient.conf) | Optional |
| splunktargetlm | short name of license server (support only apps where name contain license (should be the case when using base apps), set master_uri= https://$splunktargetlm.$splunkdnszone:8089 in server.conf)| Optional|
| splunkcloudmode | 1 = send to splunkcloud only with provided configuration, 2 = clone to splunkcloud with provided configuration (partially implemeted -> behave like 1 at the moment, 3 = byol or manual config to splunkcloud(default) | Optional |


Tags for inventory and reporting (billing for example)
(not directly used, feel free to adapt to your cloud env inventory preferences)

| Tag | Description | Status |
| --- | --- | --- |
| Vendor | Splunk | Optional |
| Perimeter | Splunk | Optional |
| Type | Splunk | Optional |

GCP specific

| Tag | Description | Status |
| --- | --- | --- |
| splunkdnszoneid | id for dns zone | required if splunkdnszone used|
| numericprojectid | GCP numeric project id | set by GCP|
| projectid | GCP project id | set by GCP|

for dev purpose or if you understand the shortcomings , you can disable automatic os update (stability and security fixes) as it speed up instance start (avoiding a reboot)
| Tag | Description | Status |
| --- | --- | --- |
| splunkosupdatemode | default="updateandreboot" , other valid value is "disabled" | optional |

multi DS mode specific tags 
1) set the splunktargetbinary to be a tgz version (required to deploy splunk multiple times otherwise we prefer using the os packaging method 

| Tag | Description | Status |
| --- | --- | --- |
| splunkdsnb | number of ds instances to deploy | optional , default to 4 for multi ds|


Advanced, options to splunkconf-init , only set if you know what you do or for dev purposes 

| Tag | Description | Status |
| --- | --- | --- |
| splunksystemd | whether to enable or not systemd for Splunk (auto, systemd or init)  | optional , default to auto  ie autodetect and use when possible|
| splunksystemdservicefile | custom systemd service file  | optional |
| splunksystemdpolkit | 1=deploy inline packaged splunkconf-init version, 2=generate via boot-start (8.1 + required), 3=do not manage (will probably not work correctly as splunk restart will not work from splunk unless deployed via opther method (if using systemd) | optional , default to 1. 2 may break especially on multids case|
| splunkdisablewlm | 0=try to deploy if possible (systemd, version is the one inline at the moment)) 1=disabled | optional , default to 0 (enabled)|
| splunkuser | name of splunk user to use (non priviledge one) | optional , default to splunk (partial support in splunkconf-cloud-receovery at the moment) |
| splunkgroup | name of splunk group to use (non privileged one) | optional , default to splunk (partial support in splunkconf-cloud-receovery at the moment) |

Additional settings for running external install script after installaion

| Tag | Description | Status |
| --- | --- | --- |
| splunkpostextrasyncdir | S3 path to sync back| |
| splunkpostextracommand | command from this synced dir to run at installation end (after Splunk is deployed and started)|


Advanced settings (for automating tests in AWS, the settings are usually set via conf file on prem)

| Tag | Description | Status |
| --- | --- | --- |
| splunks3endpointurl | custom url for s3 endpoint url (http(s)://xxxxx) | Optional (default=auto)| 
| splunkrsyncmode | if 1 then try to work in rsync over ssh mode | Optional |
| splunkrsynclist | short dns name list (should be the 2 hosts that are declared via dns tags (space separated), this is not the instanceType as this one is the same on both hosts) | required if splunkrsyncmode set |
| splunkrsyncdnsshort | own instance dns short (should be one of the 2 above) | required if splunkrsyncmode set |
| splunkrsyncautorestore | set to 1 to enable autorestore | optional (default=1 ie enabled) |

In dev, partially implemented 

| Tag | Description | Status |
| --- | --- | --- |
| splunkconnectedmode | # 0 = auto (try to detect connectivity, currently fallback to connected) (default if not set) # 1 = connected (set it if auto fail and you think you are connected) # 2 = yum only (may be via proxy or local repo if yum configured correctly) # 3 = no connection, yum disabled | Optional (implemented, except for autodetection)|
