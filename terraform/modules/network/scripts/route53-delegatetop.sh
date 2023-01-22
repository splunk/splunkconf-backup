#!/bin/bash


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
# 20230120  initial version

VERSION="20230120a"

function get_zone_id () {
  local Z=$1
  echo "ID for Zone $Z"
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name ${Z} --query HostedZones --output text | head -1 | awk '{print $2}'| sed 's/\/hostedzone\/\([A-Za-z0-9]*\)/\1/')
  echo $HOSTED_ZONE_ID

}

if [ $# -ne 5 ]; then
  echo "Argument list incorrect. Syntax is  $0 ZONE ZONEID REGION ZONETOP TTL"
  echo "where ZONEID is the id for ZONE , REGION the zone in which ZONEID was created , ZONETOP is the dns name of the zone above where you want NS records rto be inserted and TTL is the TTL to set in seconds (300=5m, 3600=1h, 86400=1 day, please use 1d+ i(for stability and trust) except when testing"
  exit 1
fi


#aws route53 list-hosted-zones-by-name --dns-name ia.cloud.plouic.com --query HostedZones --output text | head -1 | awk '{print $2}'

# the subzone
#ZONE="ia.cloud.plouic.com"
ZONE=$1
ZONEID="Z0113630MP14LCE9W6AX"
ZONEID=$2
REGION=$3
# one up
#TOP="cloud.plouic.com"
TOP=$4

TTL=$5

# 1d
#TTL=86400
# 1h
#TTL=3600
# for test only, ns should be min 1h or 1d to stabilityi+trust reason 
#TTL=300

#get_zone_id $ZONE
# we got this one by arg
get_zone_id $TOP
# We get HOSTED_ZONE_ID here

echo "get NS records for id $ZONEID (ZONE $ZONE) in REGION $REGION"
A=$(aws route53 get-hosted-zone --region $REGION --id ${ZONEID}| grep \"ns- | grep -o '".*"' | sed 's/"//g' | sed 's/\(.*\)/{"Value": "\1."},/g')

echo "RECORDS="


echo $A
echo "-----"

#B=${A::-1}
B=${A::${#A}-1}

echo "JSON RECORDS="

echo $B
#echo "-----"

#HOSTED_ZONE_ID=$( aws route53 list-hosted-zones-by-name | grep -i ${DOMAIN} -B5 | grep hostedzone | sed 's/.*hostedzone\/\([A-Za-z0-9]*\)\".*/\1/')
#echo "Hosted zone being modified: $HOSTED_ZONE_ID"


INPUT_JSON=$(cat <<EOF
{ "ChangeBatch":
 {
  "Comment": "Update the record set for delegating subzone $ZONE",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${ZONE}.",
        "Type": "NS",
        "TTL": $TTL,
        "ResourceRecords": [
${B}
        ]
      }
    }
  ]
 }
}
EOF
)


#INPUT_JSON=$( cat ./dns_record.json | sed "s/127\.0\.0\.1/$IP/" )

# http://docs.aws.amazon.com/cli/latest/reference/route53/change-resource-record-sets.html
# We want to use the string variable command so put the file contents (batch-changes file) in the following JSON

echo "INPUT_JSON"
 
echo $INPUT_JSON

aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --cli-input-json "$INPUT_JSON" || echo "ERROR updating dns record "

echo "route53 update sent to route53"
