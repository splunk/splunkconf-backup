#!/bin/bash

# Copyright 2021 Splunk Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Contributor :
#
# Matthieu Araman, Splunk
#
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



