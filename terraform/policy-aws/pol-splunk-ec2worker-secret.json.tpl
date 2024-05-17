{
    "Version": "2012-10-17",
    "Statement": [
        %{ if strcontains(secret,"arn") }
        {
            "Sid": "Getpwd",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${secret}"
        }%{ endif }
        %{ if strcontains(secret2,"arn") }
        ,{
            "Sid": "Getkey",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${secret2}"
        }%{ endif }
        ,{
            "Sid": "Describessm",
            "Effect": "Allow",
            "Action": [
                    "ssm:DescribeParameters"
            ],
            "Resource": "*"
        }%{ if strcontains(ssmkey,"arn") }
        ,{
            "Sid": "Getssmprivkey",
            "Effect": "Allow",
            "Action": [
              "ssm:DescribeParameters",
              "ssm:GetParametersByPath",
              "ssm:GetParameters",
              "ssm:GetParameter"
            ],
            "Resource": "${ssmkey}"
        }%{ endif }%{ if strcontains(ssmkeyrunner,"arn") }
        ,{
            "Sid": "Getssmpatrunner",
            "Effect": "Allow",
            "Action": [
              "ssm:DescribeParameters",
              "ssm:GetParametersByPath",
              "ssm:GetParameters",
              "ssm:GetParameter"
            ],
            "Resource": "${ssmkeyrunner}"
        }%{ endif }
    ]
}
