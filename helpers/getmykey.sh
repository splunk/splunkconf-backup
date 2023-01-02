#/bin/bash

# Copyright 2023 Splunk Inc.
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
# 20230102 initial version

VERSION="20230102a"

# this is to get ssh key from aws secret manager so you can connect to your instance(s)
# obviously you need to have the appropriate credentials to do this

if [ $# -ne 1 ]; then
  echo "Please provide region as argument"
  exit 1
fi

KEY="mykey"
REGION=$1
FI="mykey-${REGION}.priv"

if [ -e "$FI" ]; then
  echo "$FI already exist , wont attempt to overwrite it !!!! Please remove with care if you really want to update"
  echo " result would have been :"
  aws secretsmanager  get-secret-value --secret-id $KEY --region $REGION| grep SecretString| sed 's/.*\(\-\-\-\-\-BEGIN.*KEY\-\-\-\-\-\).*/\1/' |sed 's/\\n/\r\n/g'
else
  echo "writing to $FI"
  aws secretsmanager  get-secret-value --secret-id $KEY --region $REGION| grep SecretString| sed 's/.*\(\-\-\-\-\-BEGIN.*KEY\-\-\-\-\-\).*/\1/' |sed 's/\\n/\r\n/g' > $FI
  # setting permission to protect key
  chmod u=r $FI
fi
