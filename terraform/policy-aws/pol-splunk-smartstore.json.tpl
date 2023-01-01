{
    "Version": "2012-10-17",
    "Statement": [
       {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:ListBucketMultipartUploads",
                "s3:ListBucketVersions",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "${s3_data}"
            ]
        },
        {
            "Sid": "VisualEditor2",
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
                "${s3_data}/smartstore/*",
                "${s3_data}/smartstore1/*",
                "${s3_data}/smartstore2/*",
                "${s3_data}/smartstore3/*",
                "${s3_data}/smartstore4/*",
                "${s3_data}/smartstore5/*",
                "${s3_data}/smartstore6/*",
                "${s3_data}/smartstore7/*",
                "${s3_data}/smartstore8/*",
                "${s3_data}/smartstore9/*"
            ]
        }
    ]
}
