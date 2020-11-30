resource "aws_route53_zone" "dnszone" {
  name = var.dns-zone-name
  comment = "public dns zone for splunk dns updates"
}
