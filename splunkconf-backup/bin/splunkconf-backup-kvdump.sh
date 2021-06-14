#!/bin/bash

# pwd > /tmp/debugkvd.txt
# env > /tmp/debug.txt

`${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-backup.sh kvdump`

