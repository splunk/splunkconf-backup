



#Please note that this code expects SSH key pair to exist in default dir under 
#users home directory, otherwise it will fail

#Create key-pair for logging into EC2 
resource "aws_key_pair" "master-key" {
  provider   = aws.region-primary
  key_name_prefix   = "mykey"
  public_key = file("~/.ssh/id_rsa.pub")
}



