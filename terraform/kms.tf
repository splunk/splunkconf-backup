resource "aws_kms_key" "splunkkms" {
  provider      = aws.region-master
  description             = "Splunk KMS key"
  deletion_window_in_days = 30
  enable_key_rotation = false
  # key_usage = "ENCRYPT_DECRYPT"
  # customer_master_key_spec = SYMMETRIC_DEFAULT
  # policy    
  is_enabled = true
  multi_region = false
  # in order to avoid that terraform destroy remove it (clean it manually if you need , use terraform inport if ever needed later (interesting for testing as AWS charge for each key creation)
  #lifecycle {
  #  prevent_destroy = true
  #}
  tags = {
    Type = "Splunk"
  }

}

# this fill in the alias seen in AWS Console
resource "aws_kms_alias" "splunkkms" {
  provider      = aws.region-master
  name_prefix   = "alias/splunkkms"
  target_key_id = aws_kms_key.splunkkms.key_id
}

