

resource "random_password" "splunkpassword" {
  count    = var.generateuserseed ? 1 : 0
  length           = 16
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  lower            = true
  upper            = true
  numeric          = true
  special          = true
  override_special = "_%@"
}

resource "random_password" "splunksalt" {
  count    = var.generateuserseed ? 1 : 0
  length           = 16
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  lower            = true
  upper            = true
  numeric          = true
  special          = false
}
  
resource "aws_secretsmanager_secret" "splunk_admin" {
  count    = var.generateuserseed ? 1 : 0
  name_prefix = "splunk_admin_pwd"
  description = " Splunk admin password"
}

resource "aws_secretsmanager_secret_version" "splunk_admin" {
  count    = var.generateuserseed ? 1 : 0
  secret_id     = aws_secretsmanager_secret.splunk_admin[0].id
  secret_string = random_password.splunkpassword[0].result
}

resource "random_password" "splunkpass4symmkeyidx" {
  length           = 20
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  lower            = true
  upper            = true
  numeric          = true
  special          = false
}

resource "aws_secretsmanager_secret" "splunk_pass4symmkeyidx" {
  name_prefix = "splunk_pass4symmkeyidx"
  description = " Splunk pass4symmkey for idx clustering communication"
}

resource "aws_secretsmanager_secret_version" "splunk_pass4symmkeyidx" {
  secret_id     = aws_secretsmanager_secret.splunk_pass4symmkeyidx.id
  secret_string = random_password.splunkpass4symmkeyidx.result
  lifecycle {
    ignore_changes = [secret_string ]
  }
}

resource "random_password" "splunkpass4symmkeyidxdiscovery" {
  length           = 20
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  lower            = true
  upper            = true
  numeric          = true
  special          = false
}

resource "aws_secretsmanager_secret" "splunk_pass4symmkeyidxdiscovery" {
  name_prefix = "splunk_pass4symmkeyidxdiscovery"
  description = " Splunk pass4symmkey for idx discovery protocol"
}

resource "aws_secretsmanager_secret_version" "splunk_pass4symmkeyidxdiscovery" {
  secret_id     = aws_secretsmanager_secret.splunk_pass4symmkeyidxdiscovery.id
  secret_string = random_password.splunkpass4symmkeyidxdiscovery.result
  lifecycle {
    ignore_changes = [secret_string ]
  }
}

resource "random_password" "splunkpass4symmkeyshc" {
  length           = 20
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  lower            = true
  upper            = true
  numeric          = true
  special          = false
}

resource "aws_secretsmanager_secret" "splunk_pass4symmkeyshc" {
  name_prefix = "splunk_pass4symmkeyshc"
  description = " Splunk pass4symmkey for shc communication"
}

resource "aws_secretsmanager_secret_version" "splunk_pass4symmkeyshc" {
  secret_id     = aws_secretsmanager_secret.splunk_pass4symmkeyshc.id
  secret_string = random_password.splunkpass4symmkeyshc.result
  lifecycle {
    ignore_changes = [secret_string ]
  }
}


locals {
  splunk_admin_pwd=var.generateuserseed ? aws_secretsmanager_secret_version.splunk_admin[0].secret_string : "disabledhere"
}

locals {
  splunkpass4symmkeyidx = aws_secretsmanager_secret_version.splunk_pass4symmkeyidx.secret_string
  splunkpass4symmkeyidxdiscovery = aws_secretsmanager_secret_version.splunk_pass4symmkeyidxdiscovery.secret_string
  splunkpass4symmkeyshc = aws_secretsmanager_secret_version.splunk_pass4symmkeyshc.secret_string
  sensitive = true
}

resource "null_resource" "generate-user-seed" {
  count    = var.generateuserseed ? 1 : 0
  provisioner "local-exec" {
      command = "python3 ./scripts/generate-user-seed.py admin ${local.splunk_admin_pwd} ${random_password.splunksalt} > ../buckets/bucket-install/install/user-seed.conf"
  }
  #depends_on = [local.splunk_admin_pwd]
}



output "splunk_admin_password" {
  value = var.generateuserseed ? "${local.splunk_admin_pwd[0]}" : "user seed generation disabled here"
  description = "splunk admin password"
  sensitive = true
}

output "splunk_pass4symmkeyidx" {
  value = "${local.splunkpass4symmkeyidx}"
  description = "splunk pass4symmkey for idx clustering"
  sensitive = true
}

output "splunk_pass4symmkeyidxdiscovery" {
  value = "${local.splunkpass4symmkeyidxdiscovery}"
  description = "splunk pass4symmkey for idx discovery protocol"
  sensitive = true
}

output "splunk_pass4symmkeyshc" {
  value = "${local.splunkpass4symmkeyshc}"
  description = "splunk pass4symmkey for shc clustering"
  sensitive = true
}

