{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DescribeInstancesAndRouteTables",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeRouteTables"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ManageBastionDefaultRoute",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateRoute",
                "ec2:ReplaceRoute",
                "ec2:DeleteRoute"
            ],
            "Resource": "arn:aws:ec2:${region}:${account_id}:route-table/${route_table_id}"
        },
        {
            "Sid": "DescribeAutoScalingGroups",
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups"
            ],
            "Resource": "*"
        }
    ]
}
