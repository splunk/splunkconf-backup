---
layout: default
title: Home
nav_order: 1
---
Welcome to the splunkconf-backup wiki!


## Who is this app for

This app is for Splunk admins (on prem or BYOL iaas) 

## Purpose

This git repository contain 
* splunkconf-backup application that is used to Splunk configuration files , kvstore, state and additional scripts if used.
* terraform and recovery script for AWS/GCP iaas context that build cloud configuration that will leverage backups to restore configurations up to the initial state before failure happened.(and that the backup app will automatically detect and use to know where to backup)

## Topology support

The following topologies are supported :
* local only backups (will always do by default)
* remote on a object store (s3 or GCS) via automatic tag/metadata detection in AWS/GCP (will automatically discover bases on instance tag)
* remote on object store statically configured
* remote on a mounted point (need configuration, use for on prem deployment)
