
resource "aws_s3_bucket" "s3_install" {
  provider      = aws.region-master
  bucket_prefix = "splunkconf-${var.profile}-${var.splunktargetenv}-install"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "s3_install" {
  bucket = aws_s3_bucket.s3_install.id
  block_public_acls   = true
  block_public_policy = true
}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_install_versioning" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_install.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_install_lifecycle" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_install.id

  rule {
    id = "purge-old-noncurrent-versionned-install"
    filter {
      prefix = "install/"
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    expiration {
      expired_object_delete_marker = true
    }
    status = "Enabled"
  }

  rule {
    id = "purge-old-noncurrent-versionned-packaged"
    filter {
      prefix = "packaged/"
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
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

resource "aws_s3_bucket" "s3_backup" {
  provider      = aws.region-master
  bucket_prefix = "splunkconf-${var.profile}-${var.splunktargetenv}-backup"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "s3_backup" {
  bucket = aws_s3_bucket.s3_backup.id
  block_public_acls   = true
  block_public_policy = true
}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_backup_versioning" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_backup_lifecycle" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_backup.id

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

resource "aws_s3_bucket" "s3_data" {
  provider      = aws.region-master
  bucket_prefix = "splunkconf-${var.profile}-${var.splunktargetenv}-data"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "s3_data" {
  bucket = aws_s3_bucket.s3_data.id
  block_public_acls   = true
  block_public_policy = true
}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_data_versioning" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_data_lifecycle" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_data.id

  rule {
    id = "purge-old-noncurrent-versionned-data"
    filter {
      prefix = "smartstore/"
    }
    noncurrent_version_expiration {
      noncurrent_days = var.deleteddata-retention
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


# Ingest Action bucket
resource "aws_s3_bucket" "s3_ia" {
  provider      = aws.region-master
  bucket_prefix = "splunkconf-${var.profile}-${var.splunktargetenv}-ia"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "s3_ia" {
  bucket = aws_s3_bucket.s3_ia.id
  block_public_acls   = true
  block_public_policy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_ia_lifecycle" {
  provider = aws.region-master
  bucket   = aws_s3_bucket.s3_ia.id

  rule {
    id      = "purge-old-noncurrent-versionned-ia"
    filter {
      prefix  = "ia/"
    }
    noncurrent_version_expiration {
      noncurrent_days = var.deleteddata-retention
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
