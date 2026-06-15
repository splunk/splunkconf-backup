---
layout: default
title: Backups-logs
---
---
layout: default
title: Backups-logs
---
There are 3 differents logs : 

* splunkconf-backup : log all operation relative to backups
* splunkconf-restore : log operation related to restoring kvdump backups at Splunk start (also rotate and purge splunkconf-backup log files)
* splunkconf-purgebackup : log all the purging activities

All these logs are searchable via index=_internal source=*splunkconf-backup.log* 

Most logs will be using these fields : 
* time
* function name
* FACILITY (INFO, FAIL,...)
* id (epoch time when the function started)
* action (backup, purge,...)
* type (local or remote)
* object (etc,state,kvstore or scripts)
* result (success, failure, warning)
* reason more context on result
* src backup source
* dest backup destination
* durationms duration in ms
* size backup size
* minfreespace minimal free space for backup to be launched (to reduce disk full risk)
* currentavailable current free space on backup location
* backuptype whether it is versioned or not
