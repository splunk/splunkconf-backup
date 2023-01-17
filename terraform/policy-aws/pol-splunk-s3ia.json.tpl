{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Allow access to S3 IA",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucketMultipartUploads",
                "s3:AbortMultipartUpload",
                "s3:ListBucketVersions",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion",
                "s3:GetBucketLocation",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "${s3_ia}/${s3_iaprefix}/*",
                "${s3_ia}/*"
            ]
        },
        {
            "Sid": "AllowSplunkAccessTo ${s3_ia} (FS S3)",
            "Effect": "Allow",
            "Principal": {
                 "AWS": ${fs_s3_principals}
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
        },
    ]
}
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["arn:aws:iam::594195655983:role/emea-arch-fs4s3-02"]},"Action":["s3:GetBucketLocation","s3:ListBucket","s3:GetObject*"],"Sid":"AllowSplunkAccessTo splunkconf-default-test-ia20230115220555618000000005","Resource":["arn:aws:s3:::splunkconf-default-test-ia20230115220555618000000005","arn:aws:s3:::splunkconf-default-test-ia20230115220555618000000005/*"]}]}
