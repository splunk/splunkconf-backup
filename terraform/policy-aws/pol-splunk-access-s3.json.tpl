{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Access S3 prefix ${s3_bucket}/${s3_prefix}",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_bucket}/${s3_prefix}/*"
            ]
        },
        {
            "Sid": "Access S3 bucket ${s3_bucket}",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_bucket}"
            ]
        }
    ]
}
