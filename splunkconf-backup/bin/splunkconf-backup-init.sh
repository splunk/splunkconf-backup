#!/bin/bash

# pwd > /tmp/debuginit.txt
# env > /tmp/debuginit.txt
# `date` > /tmp/debuginit.txt

# init is when started at splunk start in one time mode to do a first ful backup
# by using init as param , we know we are running in this mode

`${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-backup.sh init`

