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
