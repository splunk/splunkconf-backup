#/bin/bash -x

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
# 20230109 rename to getmycredentials and add splunk admin pwd get from aws secrets 
# 20230109 add query param to only print value
# 20230116 fix typo and change output for ssh key first time 

VERSION="20230116a"

# this is to get ssh key from aws secret manager so you can connect to your instance(s)
# obviously you need to have the appropriate credentials to do this


echo "This helper is used to get credentials from AWS so that you can connect to your instances."
echo "It is obviously and absolutely necessary that you have the appropriate credentials or that will fail"
echo "region and splunk_admin_arn are variables / output of terraform run that you need to provide as inputs (as this is the only way to sort out things if multiple tf have been run in //"

if [ $# -lt 2 ]; then
  echo "Please provide region and splunk_admin_arn as arguments like $0 us-east-1 arn:aws:secretsmanager:us-east-1:nnnnnnnnn:secret:splunk_admin_pwdxxxxxx"
  exit 1
fi

KEY="mykey"
REGION=$1
SPLUNK_ADMIN_ARN=$2
FI="mykey-${REGION}.priv"

if [ -e "$FI" ]; then
  echo "$FI already exist , wont attempt to overwrite it !!!! Please remove with care if you really want to update"
  echo " result would have been :"
  aws secretsmanager  get-secret-value --secret-id $KEY --query "SecretString" --output text --region $REGION
else
  echo "writing to $FI"
  aws secretsmanager  get-secret-value --secret-id $KEY --query "SecretString" --output text --region $REGION > $FI
  # setting permission to protect key
  chmod u=r,og= $FI
  echo "key file contain:"
  cat $FI
fi
echo "get user-seed"
aws ssm get-parameter --name splunk-user-seed --region $REGION --query "Parameter.Value" --output text
if [ $# -eq 3 ]; then
 echo "get pass4symmkeyidx"
 KEY=$3
 aws secretsmanager  get-secret-value --secret-id $KEY --query "SecretString" --output text --region $REGION
fi
echo "Getting splunk admin pwd from AWS SecretsManager with arn $SPLUNK_ADMIN_ARN in region $REGION"
aws secretsmanager  get-secret-value --secret-id $SPLUNK_ADMIN_ARN --region $REGION  --query "SecretString" --output text
