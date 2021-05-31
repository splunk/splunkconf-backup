#!/bin/bash

# Matthieu Araman, Splunk

# 20210527 comment out real server as done via splunkconf-init

VERSION="20210527"

yum install ipvsadm -y

echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-zzz-ipvs.conf

sysctl --system

sysctl net.ipv4.conf.all.rp_filter=0
sysctl net.ipv4.conf.tunl0.rp_filter=0
sysctl net.ipv4.conf.eth0.arp_ignore=1
sysctl net.ipv4.conf.eth0.arp_announce=2




touch /etc/sysconfig/ipvsadm
systemctl enable --now ipvsadm


# clear
ipvsadm -C

# nornal port 8089
VIPPORT=8089

# get my ip

IP=`ip route get 8.8.8.8 | head -1 | cut -d' ' -f7`

echo "creating vip=$IP:$VIPPORT"

# add vip with source hash

ipvsadm --add-service -t $IP:$VIPPORT -s sh


# add backend

echo "adding backend"

# this is done by splunkconf-init for each instance at creation time
#ipvsadm --add-server -t $IP:$VIPPORT -r $IP:18089 -m


ipvsadm --save > /etc/sysconfig/ipvsadm



