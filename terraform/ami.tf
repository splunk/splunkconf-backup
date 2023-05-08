

#    ***** GLOBAL AMI defintions ******

# This is used by a ami image variable that is then referenced in templates



#Get Linux AMI ID using SSM Parameter endpoint in region
data "aws_ssm_parameter" "linuxAmi" {
  provider = aws.region-primary
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}




