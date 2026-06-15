---
layout: default
title: Local-backups
parent: Backups
nav_order: 1
---
# Fire and forget mode

Pro
* Easy to deploy, you may just install the application via usual mechanisms and let it run
* Nothing to configure for externalizing backups

Con 
* In this mode, backups stay local so they only allow to get back to a previous state after a local issue but obviously if the underlying host fail, backups are also lost in this mode
* If you havent provisionned enough space for backups, starving situation may occur preventing backups to run 
