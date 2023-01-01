
resource "aws_iam_role" "role-splunk-s3-replication" {
  name_prefix           = "role-splunk-s3-replication"
  force_detach_policies = true
  description           = "iam role for splunk s3 replication"
  assume_role_policy    = file("./policy-aws/assumerolepolicy-s3.json")

  tags = {
    Name = "splunk"
  }
}

resource "aws_iam_role_policy_attachment" "splunk-s3-replication" {
  role       = aws_iam_role.role-splunk-s3-replication.name
  policy_arn = aws_iam_policy.pol-splunk-s3-replication-backup.arn
}

#resource "aws_s3_bucket" "s3_install" {
#  provider      = aws.region-primary
#  bucket_prefix = "splunkconf-${var.profile}-${var.splunktargetenv}-install"
#  force_destroy = true
#}

#resource "aws_s3_bucket_public_access_block" "s3_install" {
#  bucket = aws_s3_bucket.s3_install.id
#  block_public_acls   = true
#  block_public_policy = true
#  ignore_public_acls = true
#}

## aws provider change with 4.0 
#resource "aws_s3_bucket_versioning" "s3_install_versioning" {
#  provider = aws.region-primary
#  bucket   = aws_s3_bucket.s3_install.id
#
#  versioning_configuration {
#    status = "Enabled"
#  }
#}

#resource "aws_s3_bucket_lifecycle_configuration" "s3_install_lifecycle" {
#  provider = aws.region-primary
#  bucket   = aws_s3_bucket.s3_install.id
#
#  rule {
#    id = "s3install-purge-old-noncurrent-versionned-install"
#    filter {
#      prefix = "install/"
#    }
#    noncurrent_version_expiration {
#      noncurrent_days = 90
#    }
#    abort_incomplete_multipart_upload {
#      days_after_initiation = 1
#    }
#    expiration {
#      expired_object_delete_marker = true
#    }
#    status = "Enabled"
#  }
#
#  rule {
#    id = "s3install-purge-old-noncurrent-versionned-packaged"
#    filter {
#      prefix = "packaged/"
#    }
#    noncurrent_version_expiration {
#      noncurrent_days = 90
#    }
#    abort_incomplete_multipart_upload {
#      days_after_initiation = 1
#    }
#    expiration {
#      expired_object_delete_marker = true
#    }
#    status = "Enabled"
#  }
#}

resource "aws_s3_bucket" "s3_backup_secondary" {
  provider = aws.region-secondary
  # limited to 37 char here, suffix with b as the date will be added after
  bucket_prefix       = "splunkconf-${var.profile}-${var.splunktargetenv}-backupb"
  force_destroy       = true
  object_lock_enabled = var.objectlock-backup
}

resource "aws_s3_bucket_object_lock_configuration" "s3_backup-secondary" {
  count    = var.objectlock-backup ? 1 : 0
  provider = aws.region-secondary
  bucket   = aws_s3_bucket.s3_backup_secondary.bucket

  rule {
    default_retention {
      mode = var.objectlock-backup-mode
      days = var.objectlock-backup-days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3_backup_secondary" {
  provider            = aws.region-secondary
  bucket              = aws_s3_bucket.s3_backup_secondary.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_backup_secondary_versioning" {
  provider = aws.region-secondary
  bucket   = aws_s3_bucket.s3_backup_secondary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_backup_secondary_lifecycle" {
  provider = aws.region-secondary
  bucket   = aws_s3_bucket.s3_backup_secondary.id

  rule {
    id = "purge-old-noncurrent-versionned-backup"
    filter {
      prefix = "splunkconf-backup/"
    }
    noncurrent_version_expiration {
      noncurrent_days = var.backup-retention
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    expiration {
      expired_object_delete_marker = true
    }
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "source_s3_bucket_backup_acl" {
  provider = aws.region-primary

  bucket = aws_s3_bucket.s3_backup.id
  acl    = "private"
}

resource "aws_s3_bucket_replication_configuration" "backup_primary_to_secondary" {
  provider = aws.region-primary
  count    = var.enable-s3-normal-replication-backup ? 1 : 0
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.s3_backup_versioning, aws_s3_bucket_versioning.s3_backup_secondary_versioning, aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle, aws_s3_bucket_lifecycle_configuration.s3_backup_secondary_lifecycle]

  role   = aws_iam_role.role-splunk-s3-replication.arn
  bucket = aws_s3_bucket.s3_backup.id

  rule {
    id = "sync-backup-primary-secondary"

    filter {
      prefix = "splunkconf-backup"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.s3_backup_secondary.arn
      storage_class = "STANDARD_IA"
    }
    delete_marker_replication {
      status = "Enabled"
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "backup_secondary_to_primary" {
  provider = aws.region-secondary
  count    = var.enable-s3-reverse-replication-backup ? 1 : 0
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.s3_backup_versioning, aws_s3_bucket_versioning.s3_backup_secondary_versioning, aws_s3_bucket_lifecycle_configuration.s3_backup_lifecycle, aws_s3_bucket_lifecycle_configuration.s3_backup_secondary_lifecycle]

  role   = aws_iam_role.role-splunk-s3-replication.arn
  bucket = aws_s3_bucket.s3_backup_secondary.id

  rule {
    id = "sync-backup-secondary-primary"

    filter {
      prefix = "splunkconf-backup"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.s3_backup.arn
      storage_class = "STANDARD_IA"
    }
    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# add data secondary here if needed






#output "s3_install_arn" {
#  value = "${aws_s3_bucket.s3_install.arn}"
#  description = "s3 install arn"
#}

output "s3_backup_secondary_arn" {
  value       = aws_s3_bucket.s3_backup_secondary.arn
  description = "s3 backup secondary arn"
}

#output "s3_data_arn" {
#  value = "${aws_s3_bucket.s3_data.arn}"
#  description = "s3 data arn"
#}
