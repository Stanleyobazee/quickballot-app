resource "aws_route53_zone" "app" {
  name    = var.zone_name
  comment = "Delegated subdomain for QuickBallot"
}
