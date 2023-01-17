{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_install}/env/${profile}/${splunktargetenv}/*",
                "${s3_install}/install/*",
                "${s3_install}/packaged/*",
                "${s3_install}/*"
            ]
        },
       {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:${region}:*:parameter/splunk-user-seed"
        }
    ]
}
