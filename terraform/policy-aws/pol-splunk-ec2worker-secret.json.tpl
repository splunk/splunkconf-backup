{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Getpwd",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${secret}"
        },
        {
            "Sid": "Getkey",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${secret2}"
        },
        {
            "Sid": "Describessm",
            "Effect": "Allow",
            "Action": [
                    "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Getssmprivkey",
            "Effect": "Allow",
            "Action": [
              "ssm:DescribeParameters",
              "ssm:GetParametersByPath",
              "ssm:GetParameters",
              "ssm:GetParameter"
            ],
            "Resource": "${ssmkey}"
        }
    ]
}
