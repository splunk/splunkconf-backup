resource "aws_route53_zone" "dnszone" {
  name    = var.dns-zone-name
  comment = "public dns zone for splunk dns updates"
  provisionner "local-exec" {
    count = var.enable-ns-glue-aws ? 1 : 0
    command = "sleep 10; ./scripts/route53-delegatetop.sh ${aws_route53_zone.dnszone.name} ${aws_route53_zone.dnszone.zone_id} ${var.region} ${var."
 
 } 
}



