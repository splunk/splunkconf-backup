
resource "google_storage_bucket" "gcs_install" {
  provider      = google
  name          = "splunkconf-${var.profile}-${var.splunktargetenv}-install"
  location      = var.region
  force_destroy = true
  versioning {
    enabled = true
  }
}


#  lifecycle_rule {
#    id      = "purge-old-noncurrent-versionned-install"
#    prefix  = "install/"
#    enabled = true
#    noncurrent_version_expiration {
#      days = 90
#    }
#    abort_incomplete_multipart_upload_days = 1
#    expiration {
#      expired_object_delete_marker = true
#    }
#  }

#  lifecycle_rule {
#    id      = "purge-old-noncurrent-versionned-packaged"
#    prefix  = "packaged/"
#    enabled = true
#    noncurrent_version_expiration {
#      days = 90
#    }
#    abort_incomplete_multipart_upload_days = 1
#    expiration {
#      expired_object_delete_marker = true
#    }
#  }
#}


resource "google_storage_bucket" "gcs_backup" {
  provider      = google
  name          = "splunkconf-${var.profile}-${var.splunktargetenv}-backup"
  location      = var.region
  force_destroy = true
  versioning {
    enabled = true
  }
}


#  lifecycle_rule {
#    id      = "purge-old-noncurrent-versionned-backup"
#    prefix  = "splunkconf-backup/"
#    enabled = true
#
#    noncurrent_version_expiration {
#      days = var.backup-retention
#    }
#    abort_incomplete_multipart_upload_days = 1
#    expiration {
#      expired_object_delete_marker = true
#    }
#  }

#}

resource "google_storage_bucket" "gcs_data" {
  provider      = google
  name          = "splunkconf-${var.profile}-${var.splunktargetenv}-data"
  location      = var.region
  force_destroy = true
  versioning {
    enabled = true
  }
}

#  lifecycle_rule {
#    id      = "purge-old-noncurrent-versionned-data"
#    prefix  = "smartstore/"
#    enabled = true
#
#    noncurrent_version_expiration {
#      days = var.deleteddata-retention
#    }
#    abort_incomplete_multipart_upload_days = 1
#    expiration {
#      expired_object_delete_marker = true
#    }
#  }

#}
