#!/bin/bash

yum update -y
yum install httpd -y
service httpd start

