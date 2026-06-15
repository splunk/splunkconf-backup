---
layout: default
title: Restoring-backups
---
---
layout: default
title: Restoring-backups
---
# Context


you can restore backups in multiple situations :
* full restoration
  * instance loss (hardware or software issue)
  * rollback to a previous situation 
  * reuse backups in another environnement (like to simulate a upgrade in a test env)
* partial restoration
  * recover a lookup that was overwritten by accident 
  * recover any knowledge object like a dashboard without having to recover the full env
  * recover a specific collection (kvstore)


# Methods

  * Manual restoration
  * Semi automated (for kvdump)
  * Automated restoration via Automatic scaling group and recovery script (see terraform part)(AWS or GCP)


# Finding backups
Depending on your environment , you may find backups either locally and/or remote backup storage (traditional FS for on prem or object store)

Unless you changed default configuration, you will find local backups under $SPLUNK_HOME/var/backups for non kvdump backups and kvdump backups under SPLUNK_HOME/var/lib/splunk/kvstorebackup/
However, you should have only recent backups present locallly, you probably have longer retention backups on remote location when applicable

For on prem remote backups, remote location is the one you configured
For object store context (AWS/GCP mainly), backup location is usually configured via instance tags 

In both case, backups are organized by instance type/name
In traditional FS, remote backups name contain the date by default
In object store context, remote backups are always named the same (which ease recovery) as the object store is versionning. As such, you may get a older backup by selecting show versions in UI (or similar)

# Viewing backup content

for kvdump, you may use tar tvf backupconfsplunk-kvdump-xxxxx.tar.gz to view backup content
Note that collections must exist before any restoration attempt

for etc, state and scripts, the compression method is zstd by default so you need to have zstd binary available and tell tar to use it 
Exemple : tar -I zstd -tvf backupconfsplunk-rel-etc-targeted-xxx.tar.zst

# Manually restore

* Stop Splunk if needed
* cd $SPLUNK_HOME
* Restore etc, state (and scripts if applicable) by tar -I zstd -xvf backupname.tar.zst
* Copy kvdump backup to this SPLUNK_HOME/var/lib/splunk/kvstorebackup/backupconfsplunk-kvdump-toberestored.tar.gz
* start Splunk service

Note the kvdump will be restored automatically at Splunk start (as it need to be done while Splunk is up in order to call the corresponding API)

Order of restoration , especially when redeploying Splunk binary at same time is very important, please look at splunkconf-cloud-recovery script for the full detailed logic
 
# Automatic restore

just use the terraform provided, which will setup all the glue so restore can work (AWS/GCP context) ( - [Configure-Terraform-cloud-in-VCS-mode](./Configure-Terraform-cloud-in-VCS-mode.md))
