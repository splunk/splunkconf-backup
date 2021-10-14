# by default rules are inbound


resource "google_compute_firewall" "splunk-webui" {
  project     = var.project
  name        = "splunk-webui"
  network     = "default"
  description = "splunk access to web ui"

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }
  source_ranges = var.splunkadmin-networks
  target_tags   = ["splunk-webui"]
}

resource "google_compute_firewall" "splunk-hec" {
  project     = var.project
  name        = "splunk-hec"
  network     = "default"
  description = "splunk HEC"

  allow {
    protocol = "tcp"
    ports    = ["8088"]
  }
  source_tags = ["splunk"]
  target_tags = ["splunk-hec"]
}

resource "google_compute_firewall" "splunk-rest" {
  project     = var.project
  name        = "splunk-rest"
  network     = "default"
  description = "splunkREST API"

  allow {
    protocol = "tcp"
    ports    = ["8089"]
  }
  source_tags = ["splunk-mc", "splunk-cm", "splunk-idx", "splunk-sh", "splunk"]
  target_tags = ["splunk-restapi"]
}

resource "google_compute_firewall" "splunk-replication-idx" {
  project     = var.project
  name        = "splunk-replication-idx"
  network     = "default"
  description = "splunk replication idx"

  allow {
    protocol = "tcp"
    ports    = ["9887"]
  }
  source_tags = ["splunk-idx"]
  target_tags = ["splunk-replication-idx"]
}

resource "google_compute_firewall" "splunk-log" {
  project     = var.project
  name        = "splunk-log"
  network     = "default"
  description = "splunk log s2s from splunk components"

  allow {
    protocol = "tcp"
    ports    = ["9997-9999"]
  }
  source_tags = ["splunk-mc", "splunk-cm", "splunk-hf", "splunk-sh", "splunk-iuf", "splunk-ds", "splunk-lm", "splunk"]
  target_tags = ["splunk-log"]
}

