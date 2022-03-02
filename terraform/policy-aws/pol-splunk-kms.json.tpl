{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Keykms1",
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:ReEncrypt",
                "kms:Decrypt",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": [
                "${kmsarn}"
            ]
        }
    ]
}
