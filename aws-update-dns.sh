#!/bin/bash

# 20200413 fix typo + improve logging
# 20200510 update to metadata v2
# 20210531 support splunkdnszone tag


if [ -z "$1" ]; then
    echo "IP not given...trying EC2 metadata...";
    TOKEN=`curl --silent --show-error -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900"`
    IP=$( curl --silent --show-error -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4 )
else
    IP="$1"
fi
echo "IP to update: $IP"

# need iam ->  policy  permissions of
#
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Sid": "VisualEditor0",
#            "Effect": "Allow",
#            "Action": [
#                "route53:ChangeResourceRecordSets",
#                "route53:ListHostedZonesByName"
#            ],
#            "Resource": "*"
#        }
#    ]
#}

# you could put statically aws managed zone here
DOMAIN="cloud.plouic.com"
# but better get it from instance tags
. /etc/instance-tags
if [ -z ${splunkdnszone+x} ]; then
  echo "splunkdnszone is unset, consider provide it via instance tags will try fallback method ";
  if [ -z ${splunkawsdnszone+x} ]; then
    echo "neither splunkdnszone or splunkawsdnszone is unset, consider provide splunkdnszone via instance tags will try to use static domain from script : ${DOMAIN} ";
  else
    echo "splunkawsdnszone is set to '$splunkawsdnszone' from instance tags";
    DOMAIN="${splunkawsdnszone}"
  fi
else
    echo "splunkdnszone is set to '$splunkdnszone' from instance tags (tag ok)";
    DOMAIN="${splunkdnszone}"
fi
echo "DOMAIN  now '$DOMAIN'";
NAME=`hostname --short`
FULLNAME=$NAME"."$DOMAIN

HOSTED_ZONE_ID=$( aws route53 list-hosted-zones-by-name | grep -i ${DOMAIN} -B5 | grep hostedzone | sed 's/.*hostedzone\/\([A-Za-z0-9]*\)\".*/\1/')
echo "Hosted zone being modified: $HOSTED_ZONE_ID"


INPUT_JSON=$(cat <<EOF
{ "ChangeBatch":
 {
  "Comment": "Update the record set of ${FULLNAME}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${FULLNAME}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "${IP}"
          }
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

#echo $INPUT_JSON

aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --cli-input-json "$INPUT_JSON" || echo "ERROR updating dns record for ${FULLNAME}"


