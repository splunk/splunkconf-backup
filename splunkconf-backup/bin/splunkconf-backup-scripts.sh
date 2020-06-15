#!/bin/bash

pwd > /tmp/debug.txt
env >> /tmp/debug.txt
`${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-backup.sh scripts`

