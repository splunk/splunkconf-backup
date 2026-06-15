---
layout: default
title:  Cost Optimisation with tags on S3
parent: Backups
nav_order: 2.5
---
# Introduction

Cost will vary depending on : 
- AWS region
- your AWS discount
- backup frequency
- storage class (by default STD is used for hourly then IA for other backups)
- number of instances to backup
- role and content on each instance

# Cost simulation

This cost simulation is done on a test environment with : 
- one SH with ES app on it and multiple addons plus a few apps 
- one DS
- one MC
- one CM (which also push ML librairies to idx layer)
- idx cluster 

## backup sizes in MB

| instance type | State backup in MB | etc targeted backup in MB | kvdump backup in MB |
| ------------- | ------------------ | ------------------------- | ------------------- |
| CM | 267 | 15.8 | 0.018 |
| MC | 1.3 | 44.3 | 0.020 |
| SH | 292 | 2500 | 6000 |
| DS | 4.3 | 20.5 | .001 |

## backup frequency 

backup frequency is the one from [default terraform values](https://github.com/splunk/splunkconf-backup/blob/11f9c8e1e745e48b9ae87e9dc1a299604ef42502/terraform/variables.tf#L435) 

| instance type | nb hourly STD | nb daily IA | nb weekly IA | nb monthly IA |
| ------------- | ------------- | ----------- | ------------ | ------------- |
| CM | 60 | 60 | 10 | 12 |
| MC | 60 | 60 | 10 | 12 |
| SH | 60 | 60 | 10 | 12 |
| DS | 60 | 60 | 10 | 12 |

This is 2880 STD PUT per month and 144 IA PUT per month 

## Amount of data to store (GB per month)

| instance type | STD | IA | 
| ------------- | ------- | ------- |
| CM | 16.57 | 22.65 |
| MC | 2.67 | 3.65 | 
| SH | 163.94 | 224.05 |
| DS | 1.45 | 1.99 |
| Total | 184.63 | 252.33 |

## Estimated price

region : eu-west-1
public price

| Category | Cost per month ($) |
| -------- | -------- |
| STD | 4.25 |
| IA | 3.15 |
| Total | 7.40 |

[Cost link](https://calculator.aws/#/estimate?id=231cd4a701343bb8d1dbcb9a3df9f7eeabfdd2b8)
