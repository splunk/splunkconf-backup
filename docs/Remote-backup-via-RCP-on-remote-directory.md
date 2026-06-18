---
layout: default
title: Remote backup via RCP on remote directory
parent: Backups
nav_order: 3.6
---
![RCP schema](https://github.com/splunk/splunkconf-backup/blob/main/docs/images/splunkconf-backup-rcp.png)


In this mode, local backups are copied via RCP (ie over SSH) to a remote host 
For this to be enable you may want to : 
- Set up ssh keys for passwordless connections
- set up the following settings 
  - REMOTETECHNO=3
  - REMOTEBACKUPDIR="remotedirectory"
  - RCPHOST
  - RCPREMOTEUSER if different from splunk user

Please note splunkconf-backup will also manage purging remote files according to remote retention setting and max remote size

You will also need splunkconf-backup v1.6 minimum for this feature
