---
layout: default
title: Setting up ssh keys for rsync/rcp modes
parent: Backups
nav_order: 3.5
---
# Context

This is a reminder on a possible way to create keys between 2 hosts. There is lots of possible options on how to tune this (like which kind of keys to use, which are outside the scope of this page)

# RCP mode 

In that mode, you need to create a local key for splunk user on the host you are generating backups then add the public key to the authorized_keys under the backup user on the remote host. You dont need to create a key on the remote host as the connection is one way.

# Rsync over SSH mode

As the connection can be bidirectional between the 2 hosts in that mode (for the recovery process, you will probably want to reverse direction), it is expected to create keys on both sides. It is up to you to decide if the same key can be used on both side or not (as this is the same user on 2 hosts that are the same role for Splunk, this could make sense but purist approach will prefer creating different keys)

# Creating private keys and autorizing connections
On host 1, under splunk user, use ssh-keygen
you may want to generate a newer key if supported by your ssh version, see https://www.unixtutorial.org/how-to-generate-ed25519-ssh-key/ 
in the .ssh directory , copy the pub key to host2 and add it to .ssh/authorized_keys 
On host2, either reuse the same key or repeat key creation

# Additional network restriction
For additional security, as this key is only used between these hosts, you may add a from restriction before the key in authorized_keys (pending your ssh server support it, which should be the case in general)
see syntax examples at https://unix.stackexchange.com/questions/353044/how-to-restrict-an-ssh-key-to-certain-ip-addresses 

# SSH and permissions
SSH is very tight on permissions. It will not trust keys if permissions are too open in particular
In particular, make sure .ssh directory and all files are owned by the user , only the user should have access to .ssh directory (ie rwx------ )
Private key should be only readable by the user (not group or other)
authorized_keys should only be writable by the user (not group or other)

# Test connection
On host 1, under splunk user try ssh targetuser@targethost
if it doesnt work, you may use -v to diagnose on client side. If the server is refusing keys, check logs on receiving server
For rsync mode, on host2, make the reverse test to connect to host1

# Known hosts
splunkconf-backup will autoaccept new keys so you are not required to accept keys first
However if you change one host by another (for example because it failed) , you will need to reset the entry in known_hosts file (ssh file)

# Failure conditions
Splunkconf-backup will try to handle remote hosts failure in the following way : 
- use connection timeout to the ssh doesnt wait forever (which would block backups)
- send a heartbeat to detect broken ssh connection (so that ssh will close the connection in that case)
- order operations to first rsync before any other remote operations (to maximize chances of having remote backup current in case of failures)
- if the remote hosts is responding but extremely slow,it could take a very long time to complete remote backups operations but this should be under the default one hour scheduling (as Splunk will only fire one splunkconf-backup input at a time)







 
