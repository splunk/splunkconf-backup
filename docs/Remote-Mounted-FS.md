---
layout: default
title: Remote-Mounted-FS
---
---
layout: default
title: Remote-Mounted-FS
---
In this mode, once local backups run, they are copied to a mounted directory so that in case of host failure, you have the ability to use backups from the remote location.
As the remote location is supposed to be a traditional FS with no versioning at FS level, splunkconf-backup will include date inside backup names.
Additionally the purging part will also clean up remote backups based on a combination of number of days and maximum size.
