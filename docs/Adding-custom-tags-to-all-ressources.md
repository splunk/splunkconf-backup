---
layout: default
title: Adding custom tags to all ressources
parent: Customizing Terraform
nav_order: 6
---
#Introduction

Adding custom tags to all resources is useful for multiple usages including billing and tracking ressource usage

## Limitation

This is currently implemented only for the AWS provider
For GCP provider, resources are attached to a project which could be used for similar purposes

## Configuring

You may add extra default tags by configuring the following terraform variable

| Variable | Description |
| --- | --- |
| extra_default_tags | contain a map such as {Type="Splunk",Project="Splunk"} |

 2 default tags are added
Type="Splunk"
Env= splunktargetenv variable content

default tags and extra tags are automatically merged (which deduplicate)
