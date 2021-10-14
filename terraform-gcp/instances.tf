resource "google_compute_instance_template" "splunk-cm" {
  name_prefix = "splunk-cm-template-"
  #machine_type   = "f1-micro"
  machine_type   = "n2-standard-2"
  can_ip_forward = false

  tags = ["splunk", "splunk-cm","splunk-restapi","splunk-webui"]


  disk {
    # use the latest image at instance creation (reduce time to yum update)
    source_image = "centos-cloud/centos-8"
    #source_image = data.google_compute_image.centos_8.id
    auto_delete = true
    boot        = true
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
  metadata_startup_script = file("../buckets/bucket-install/install/user-data-gcp.txt")
  scheduling {
    automatic_restart = false
    preemptible       = local.env == "test" ? true : false
  }

  metadata = {
    splunkinstanceType       = "cm"
    splunks3installbucket    = google_storage_bucket.gcs_install.url
    splunks3backupbucket     = google_storage_bucket.gcs_backup.url
    splunks3databucket       = google_storage_bucket.gcs_data.url
    splunkorg                = var.splunkorg
    splunkosupdatemode       = var.splunkosupdatemode
    splunkdnszone            = var.dns-zone-name
    splunkdnszoneid          = var.gcpdnszoneid
    disable-legacy-endpoints = "TRUE"
    enable-guest-attributes  = "TRUE"
    sshKeys                  = "${var.ssh_user}:${file(var.ssh_keys)}"
  }

  # service_account {
  #   email  = google_service_account.default.email
  #   scopes = ["cloud-platform"]
  # }
  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro", "cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_pool" "splunk-cm" {
  name = "target-pool-splunk-cm"
}

resource "google_compute_region_instance_group_manager" "splunk-cm" {
  name                      = "igm-splunk-cm"
  region                    = var.region
  distribution_policy_zones = ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"]

  version {
    instance_template = google_compute_instance_template.splunk-cm.id
    name              = "primary"
  }

  named_port {
    name = "splunkmgt"
    port = "8089"
  }

  named_port {
    name = "splunkweb"
    port = "8000"
  }

  target_pools = [google_compute_target_pool.splunk-cm.id]
  # when not using autoscaler only , set this 
  #target_size = 1
  base_instance_name = "cm"
}

resource "google_compute_region_autoscaler" "splunk-cm" {
  name   = "splunk-cm-autoscaler"
  region = "us-central1"
  target = google_compute_region_instance_group_manager.splunk-cm.id

  autoscaling_policy {
    max_replicas    = 1
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

# IDX


resource "google_compute_instance_template" "splunk-idx" {
  name_prefix = "splunk-idx-template-"
  #machine_type   = "f1-micro"
  machine_type   = "n2-standard-2"
  can_ip_forward = false

  tags = ["splunk","splunk-idx","splunk-restapi","splunk-replication-idx","splunk-hec","splunk-log"]


  disk {
    # use the latest image at instance creation (reduce time to yum update)
    source_image = "centos-cloud/centos-8"
    #source_image = data.google_compute_image.centos_8.id
    disk_name   = "os"
    auto_delete = true
    boot        = true
  }

  # ephemeral SSD (local)
  dynamic "disk" {
    for_each = range(var.idx_disk_count)
    content {
      disk_type = "local-ssd"
      interface = "NVME"
      #interface = "SCSI"
      type         = "SCRATCH"
      disk_size_gb = 375
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
  metadata_startup_script = file("../buckets/bucket-install/install/user-data-gcp.txt")
  scheduling {
    automatic_restart = false
    preemptible       = local.env == "test" ? true : false
  }

  metadata = {
    splunkinstanceType       = "idx"
    splunks3installbucket    = google_storage_bucket.gcs_install.url
    splunks3backupbucket     = google_storage_bucket.gcs_backup.url
    splunks3databucket       = google_storage_bucket.gcs_data.url
    splunkorg                = var.splunkorg
    splunkosupdatemode       = var.splunkosupdatemode
    disable-legacy-endpoints = "TRUE"
    enable-guest-attributes  = "TRUE"
    sshKeys                  = "${var.ssh_user}:${file(var.ssh_keys)}"
  }

  # service_account {
  #   email  = google_service_account.default.email
  #   scopes = ["cloud-platform"]
  # }
  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro", "cloud-platform"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_pool" "splunk-idx" {
  name = "target-pool-splunk-idx"
}

resource "google_compute_region_instance_group_manager" "splunk-idx" {
  name                      = "igm-splunk-idx"
  region                    = var.region
  distribution_policy_zones = ["us-central1-a", "us-central1-b", "us-central1-c"]

  version {
    instance_template = google_compute_instance_template.splunk-idx.id
    name              = "primary"
  }

  named_port {
    name = "splunkhec"
    port = "8088"
  }

  named_port {
    name = "splunkmgt"
    port = "8089"
  }

  named_port {
    name = "splunklog9997"
    port = "9997"
  }

  named_port {
    name = "splunklog9998"
    port = "9998"
  }

  named_port {
    name = "splunklog9999"
    port = "9999"
  }

  target_pools = [google_compute_target_pool.splunk-idx.id]
  # when not using autoscaler only , set this
  #target_size = 1
  base_instance_name = "idx"
}

resource "google_compute_region_autoscaler" "splunk-idx" {
  name   = "splunk-idx-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.splunk-idx.id


  autoscaling_policy {
    max_replicas    = local.nb-indexers
    min_replicas    = local.nb-indexers
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

