{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSplunkAccessToS3IAforFSS3",
            "Effect": "Allow",
            "Principal": {
                 "AWS": [
                     "${fs_s3_principal}"
                 ]
            },
            "Action": [
                "s3:GetBucketLocation",
                "s3:ListBucket",
                "s3:GetObject*"
            ],
            "Resource": [
                "${s3_ia}/${s3_iaprefix}/*",
                "${s3_ia}/*"
            ]
        }
    ]
}
