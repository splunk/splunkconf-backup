#!/bin/bash

# this is used to import a existing zone so terraform knows it

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone

# you need to find the zone ID for example via AWS Console

ZONEID=ZNUHAFPJTC6LL


terraform import aws_route53_zone.dnszone ${ZONEID}
