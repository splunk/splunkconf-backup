



#Please note that this code expects SSH key pair to exist in default dir under 
#users home directory, otherwise it will fail

# use this version if you want to import existing key generated outside terraform

#Create key-pair for logging into EC2 
#resource "aws_key_pair" "mykey" {
#  provider   = aws.region-primary
#  key_name_prefix   = "mykey"
#  public_key = file("~/.ssh/id_rsa.pub")
#}

resource "tls_private_key" "splunk_ssh_key" {
  algorithm = var.ssh_algorithm
}

resource "aws_key_pair" "splunk_ssh_key" {
  #provider   = aws.region-primary
  key_name_prefix   = "splunk_ssh_key"
  public_key = tls_private_key.splunk_ssh_key.public_key_openssh
}

resource "aws_secretsmanager_secret" "splunk_ssh_key" {
  name_prefix = "splunk_ssh_key"
}

resource "aws_secretsmanager_secret_version" "splunk_ssh_key" {
  secret_id     = aws_secretsmanager_secret.splunk_ssh_key.id
  secret_string = tls_private_key.splunk_ssh_key.private_key_openssh
}

