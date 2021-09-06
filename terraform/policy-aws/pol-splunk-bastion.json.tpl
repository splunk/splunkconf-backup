{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow Source-Dest check modification",
            "Effect": "Allow",
            "Action": "ec2:ModifyInstanceAttribute",
            "Resource": "*"
        }
    ]
}
