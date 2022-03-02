
resource "aws_s3_bucket" "s3_install" {
  provider      = aws.region-master
  bucket_prefix = "splunkconf-${var.profile}-${var.splunktargetenv}-install"
  #acl           = "private"
  #  versioning {
  #   enabled = true
  # }
  # for test
  force_destroy = true

}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_install_versioning" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_install.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_install_lifecycle1" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_install.id

  rule {
    id      = "purge-old-noncurrent-versionned-install"
    filter {
      prefix  = "install/"
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

resource "aws_s3_bucket_lifecycle_configuration" "s3_install_lifecycle2" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_install.id

  rule {
    id      = "purge-old-noncurrent-versionned-packaged"
    filter {
      prefix  = "packaged/"
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
  #acl           = "private"
  #versioning {
  #  enabled = true
  #}
  # for test
  force_destroy = true

}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_backup_versioning" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_backup_lifecycle1" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_backup.id

  rule {
    id      = "purge-old-noncurrent-versionned-backup"
    filter {
      prefix  = "splunkconf-backup/"
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
  #acl           = "private"
  #versioning {
  #  enabled = true
  #}
  # for test
  force_destroy = true

}

# aws provider change with 4.0 
resource "aws_s3_bucket_versioning" "s3_data_versioning" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_data_lifecycle1" {
  provider      = aws.region-master
  bucket = aws_s3_bucket.s3_data.id
    
  rule {
    id      = "purge-old-noncurrent-versionned-data"
    filter {
      prefix  = "smartstore/"
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
