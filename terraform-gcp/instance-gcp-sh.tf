# SH

resource "google_compute_instance_template" "splunk-sh" {
  name_prefix = "splunk-sh-template-"
  #machine_type   = "f1-micro"
  machine_type   = "n2-standard-2"
  can_ip_forward = false

  tags = ["splunk","splunk-webui","splunk-restapi"]

  disk {
    # use the latest image at instance creation (reduce time to yum update)
    source_image = var.gcposimage
    #source_image = "centos-cloud/centos-8"
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
    splunkinstanceType       = "sh"
    splunks3installbucket    = google_storage_bucket.gcs_install.url
    splunks3backupbucket     = google_storage_bucket.gcs_backup.url
    splunks3databucket       = google_storage_bucket.gcs_data.url
    splunkorg                = var.splunkorg
    splunkdnszone            = var.dns-zone-name
    splunkdnszoneid          = var.gcpdnszoneid
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

resource "google_compute_target_pool" "splunk-sh" {
  name = "target-pool-splunk-sh"
}

resource "google_compute_region_instance_group_manager" "splunk-sh" {
  name                      = "igm-splunk-sh"
  region                    = var.region
  distribution_policy_zones = var.zoneslist

#  distribution_policy_zones = ["us-central1-a", "us-central1-b", "us-central1-c", "us-central1-f"]

  version {
    instance_template = google_compute_instance_template.splunk-sh.id
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

  target_pools = [google_compute_target_pool.splunk-sh.id]
  # when not using autoscaler only , set this
  #target_size = 1
  base_instance_name = "sh"
}

resource "google_compute_region_autoscaler" "splunk-sh" {
  name   = "splunk-sh-autoscaler"
  region = "us-central1"
  target = google_compute_region_instance_group_manager.splunk-sh.id

  autoscaling_policy {
    max_replicas    = var.nb-sh
    min_replicas    = var.nb-sh
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

