{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Describessm",
            "Effect": "Allow",
            "Action": [
                    "ssm:DescribeParameters"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Getssmprivrsynckey",
            "Effect": "Allow",
            "Action": [
              "ssm:DescribeParameters",
              "ssm:GetParametersByPath",
              "ssm:GetParameters",
              "ssm:GetParameter"
            ],
            "Resource": "${ssmkey1}"
        },
        {
            "Sid": "Getssmpubrsynckey",
            "Effect": "Allow",
            "Action": [
              "ssm:DescribeParameters",
              "ssm:GetParametersByPath",
              "ssm:GetParameters",
              "ssm:GetParameter"
            ],
            "Resource": "${ssmkey2}"
        }
    ]
}
