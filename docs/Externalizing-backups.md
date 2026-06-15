---
layout: default
title: Externalizing-backups
parent: Backups
nav_order: 2
---
# Remote Mounted FS
  Mount remote directory under filesystem via NFS
  Configure remote directory in splunkconf-backup.conf local version
  see - [Remote-Mounted-FS](./Remote-Mounted-FS.md)
# Remote fetch 
  From remote host, scp to hosts to fetch backup and store them locally
# Remote object Store (manual)
  Note this is only for cases where you cant use tags in AWS (for exemple to backup to on prem S3 storage)
  configure remote s3 location in splunkconf-backup.conf local version
# Remote object store (automatic) 
  Please see the terraform part on how to do this. This will configure tags on the instance that will be automatically discovered by app
  - [Configure-Terraform-cloud-in-VCS-mode](./Configure-Terraform-cloud-in-VCS-mode.md)
