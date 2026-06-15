---
layout: default
title: Debugging-backups
---
---
layout: default
title: Debugging-backups
---
Or when things go wrong....

So backups dont run, you try to leverage app logs and that didnt help, here are some guidelines to help run the app in debug mode

In apps directory, as splunk user, run 
> bash -x splunkconf-backup/bin/splunkconf-backup.sh etc

This will logs every steps in /tmp/splunkconf-backup-debug.log

Note : you can do the same with scripts and state but not kvstore as kvdump require a token to be passed on via input in order to call kvdump rest api
if you think you absolutely need to debug this part , add -x to script start

You could also uncomment 
> #DEBUG=1 

in script(s) which will make all the debug_log entries log (warning this is very verbose, dont let this on)

if the issue is related to copy to remote location, then take the command from debug log that write to destination, remove the batch option if applicable and run it manually from command line (as splunk user so you dont break permissions) . If that fail at that point, there is probably a permission issue outside the app.(check iam permissions for example in AWS)

still stuck or found a issue / bug -> contact me via usergroup slack or maraman at splunk
