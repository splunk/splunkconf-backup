
resource "aws_s3_bucket" "s3_install" {
  provider      = aws.region-master
  bucket_prefix = "${var.profile}-${var.splunktargetenv}-install"
  acl           = "private"
  versioning {
    enabled = true
  }
  # for test
  force_destroy = true

  lifecycle_rule {
    id      = "purge-old-noncurrent-versionned-install"
    prefix  = "install/"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }
    abort_incomplete_multipart_upload_days = 1
    expiration {
      expired_object_delete_marker = true
    }
  }

  lifecycle_rule {
    id      = "purge-old-noncurrent-versionned-packaged"
    prefix  = "packaged/"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }
    abort_incomplete_multipart_upload_days = 1
    expiration {
      expired_object_delete_marker = true
    }
  }
}


resource "aws_s3_bucket" "s3_backup" {
  provider      = aws.region-master
  bucket_prefix = "${var.profile}-${var.splunktargetenv}-backup"
  acl           = "private"
  versioning {
    enabled = true
  }
  # for test
  force_destroy = true

  lifecycle_rule {
    id      = "purge-old-noncurrent-versionned-backup"
    prefix  = "splunkconf-backup/"
    enabled = true

    noncurrent_version_expiration {
      days = var.backup-retention
    }
    abort_incomplete_multipart_upload_days = 1
    expiration {
      expired_object_delete_marker = true
    }
  }

}

resource "aws_s3_bucket" "s3_data" {
  provider      = aws.region-master
  bucket_prefix = "${var.profile}-${var.splunktargetenv}-data"
  acl           = "private"
  versioning {
    enabled = true
  }
  # for test
  force_destroy = true

  lifecycle_rule {
    id      = "purge-old-noncurrent-versionned-data"
    prefix  = "smartstore/"
    enabled = true

    noncurrent_version_expiration {
      days = var.deleteddata-retention
    }
    abort_incomplete_multipart_upload_days = 1
    expiration {
      expired_object_delete_marker = true
    }
  }

}
