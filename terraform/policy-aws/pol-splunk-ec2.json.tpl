{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ec2global",
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        },
        {
            "Sid": "s3install1",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_install}/env/${profile}/${splunktargetenv}/*",
                "${s3_install}/install/*",
                "${s3_install}/packaged/*"
            ]
        },
       {
            "Sid": "s3installroot",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_install}"
            ]
        },

       {
            "Sid": "ssmuserseed",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:${region}:*:parameter/splunk-user-seed"
        }
    ]
}
