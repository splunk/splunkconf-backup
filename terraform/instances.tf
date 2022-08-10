

#    ***** GLOBAL ******





#Get Linux AMI ID using SSM Parameter endpoint in region
data "aws_ssm_parameter" "linuxAmi" {
  provider = aws.region-master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}


# ssh oved to module to be able to import a ref

#Please note that this code expects SSH key pair to exist in default dir under 
#users home directory, otherwise it will fail

#Create key-pair for logging into EC2 
#resource "aws_key_pair" "master-key" {
#  provider   = aws.region-master
#  key_name   = "mykey"
#  public_key = file("~/.ssh/id_rsa.pub")
#}



