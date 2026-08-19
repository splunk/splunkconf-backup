{
    "Version": "2012-10-17",
    "Id": "splunk-kms-key-policy",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow CloudWatch Logs",
            "Effect": "Allow",
            "Principal": {
                "Service": "logs.${region}.amazonaws.com"
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*",
            "Condition": {
                "ArnLike": {
                    "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:${region}:${account_id}:*"
                }
            }
        },
        {
            "Sid": "Allow Secrets Manager",
            "Effect": "Allow",
            "Principal": {
                "Service": "secretsmanager.amazonaws.com"
            },
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*",
            "Condition": {
                "ArnLike": {
                    "kms:EncryptionContext:SecretARN": "arn:aws:secretsmanager:${region}:${account_id}:secret:*"
                }
            }
        }
    ]
}
