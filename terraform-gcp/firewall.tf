# by default rules are inbound


resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = "splunk-firewall-rule"
  network     = "default"
  description = "splunk port"

  allow {
    protocol  = "tcp"
    ports     = ["8000","8088","8089","9997-9999"]
  }
  target_tags = ["splunk-ui-mgt-log"]
}

resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = "splunk-webui"
  network     = "default"
  description = "splunk access to web ui"

  allow {
    protocol  = "tcp"
    ports     = ["8000"]
  }
  target_tags = ["splunk-webui"]
}

resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = "splunk-hec"
  network     = "default"
  description = "splunk HEC"

  allow {
    protocol  = "tcp"
    ports     = ["8088"]
  }
  target_tags = ["splunk-hec"]
}
 
resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = "splunk-rest"
  network     = "default"
  description = "splunkREST API"

  allow {
    protocol  = "tcp"
    ports     = ["8089"]
  }
  target_tags = ["splunk-restapi"]
}
 
resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = "splunk-replication"
  network     = "default"
  description = "splunk replication"

  allow {
    protocol  = "tcp"
    ports     = ["9887"]
  }
  target_tags = ["splunk-replication"]
}
 
resource "google_compute_firewall" "rules" {
  project     = var.project
  name        = "splunk-log"
  network     = "default"
  description = "splunk log s2s"

  allow {
    protocol  = "tcp"
    ports     = ["9997-9999"]
  }
  target_tags = ["splunk-log"]
}

