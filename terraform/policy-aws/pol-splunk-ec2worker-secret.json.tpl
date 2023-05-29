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
            "Sid": "Getssmprivkey",
            "Effect": "Allow",
            "Action": "ssm:DescribeParameters",
            "Resource": "${ssmkey}"
        }
    ]
}
