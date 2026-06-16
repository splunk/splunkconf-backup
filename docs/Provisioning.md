---
layout: default
title: Provisioning Splunk configurations
parent: Restoring Backups
nav_order: 7
---
# Introduction

while doing backup and recovery restore instance to last state and terraform create all the glue to have recovery work, provisioning initialize the instance for either first usage, backup reuse for upgrade testing in another env or continous provisioning with CI/CD integration. Manual provisioning is also possible with multiple variations.


# Provisioning and base apps config

There are multiple ways to configure a Splunk instance. By cli, API, UI and configuration files (for most operations)
In order to make easily reproducible deployment, use of configuration files packaged into apps ease create reproducible environments. This is known as base configs.
While not mandatory for backups and recovery, automatic configuration adaptation that is optionally done at recovery time assume use of these base config apps. Training on these can be obtained part of [Core Consultant Labs](https://www.splunk.com/en_us/training/core-consultant-labs.html)

## Manual base apps provisioning

base apps need to be selected for each instance roles and values customized (for example name of instances and keys used to communicate between instances). This process can be prepared manually and the results packaged into initialapps that will be used at recovery time to provision instances (or the content can be pushed directly onto the instances as it will be saved next time backup will run)

## backup reuse for upgrade testing

in case of upgrade testing, it is possible to recreate a second environment , most of the time completely isolated from the original env then bootstrap the env with the backups from the original env. As the domain name may be different for that env , domain variable can be customized and tags used to automatically update settings at recovery time without manual configuration editing. Then upgrade can be simulated with exact same configurations as original env. This method should only be used for upgrade testing, not for normal provisionning.
Please also note, instances restored like this will think they are the original one so be sure to block any outbound connectivity to external tools (including emails) if you dont want to be confused.

## Continuous provisioning (ci/cd)

This method is more automated but require use of a external github repo + customized base apps that have been modified to be jinja compatible. In that case, at each modification, ansible + jinja automatically adapt then select base app subset for each instance role then push content via combination of s3 + worker instance. The worker instance role is to be selected in topology for this use case. While worker instance and ansible configuration is created by terraform in this repo, the external repo need be created and populated with jinjaified base apps for this setup to be effective.   



 
 
