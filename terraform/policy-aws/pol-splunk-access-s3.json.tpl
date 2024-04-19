{
    "Version": "2012-10-17",
    "Statement": [
#%{ if ${s3_prefix}!="notset" ~}
##%{ if ${s3_prefix}!="notset" && ${s3_bucket}!="notset" }
#        {
#            "Sid": "AccessS3prefix",
#            "Effect": "Allow",
#            "Action": [
#                "s3:PutObject",
#                "s3:GetObject",
#                "s3:ListBucket",
#                "s3:GetBucketLocation"
#            ],
#            "Resource": [
#                "${s3_bucket}/${s3_prefix}/*"
#            ]
#        },
#        {
#            "Sid": "AccessS3bucket",
#            "Effect": "Allow",
#            "Action": [
#                "s3:GetObject",
#                "s3:ListBucket",
#                "s3:GetBucketLocation"
#            ],
#            "Resource": [
#                "${s3_bucket}"
#            ]
#%{ endif ~}
        }
    ]
}
