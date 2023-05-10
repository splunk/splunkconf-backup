

#    ***** GLOBAL AMI defintions ******

# This is used by a ami image variable that is then referenced in templates



#Get Linux AMI ID using SSM Parameter endpoint in region
data "aws_ssm_parameter" "linuxAmi" {
  provider = aws.region-primary
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}


data "aws_ssm_parameter" "linuxAmiAL2023" {
  provider = aws.region-primary
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "linuxAmicustom" {
  count = enable-customami ? 1 : 0
  provider = aws.region-primary
  name     = var.ssmamicustompath
}


