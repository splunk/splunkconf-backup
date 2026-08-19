{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "secretsmanager:PutSecretValue",
            "Resource": "${secret}"
        }%{ if kmsarn != "" ~},
        {
            "Sid": "AllowSplunkKmsForSecrets",
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "${kmsarn}"
        }%{ endif ~}
    ]
}
