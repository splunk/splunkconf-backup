#!/bin/bash

pwd > /tmp/debug-state.txt
#env >> /tmp/debug.txt
`${SPLUNK_HOME}/etc/apps/splunkconf-backup/bin/splunkconf-backup.sh state`

