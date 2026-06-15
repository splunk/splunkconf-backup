---
layout: default
title: Known-issues
---
---
layout: default
title: Known-issues
---
Backup dont run when Splunk is running as root -> This is by design, please configure your Splunk to work with a non root user (or edit scripts to remove check if you are brave enough)

Backup are not launched if app is renamed -> Du to the way scripts are launched, it is necessary to hardcode app name inside script wrapper (unless complex workaround) , please do not rename app or edit app name inside wrappers in bin directory (but that would increase maintenance cost) 
