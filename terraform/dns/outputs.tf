output "zone_id" {
  value = aws_route53_zone.app.zone_id
}

output "name_servers" {
  description = "Create one NS record per value at the registrar"
  value       = aws_route53_zone.app.name_servers
}

output "certificate_arn" {
  description = "ARN of the validated certificate for the load balancer"
  value       = aws_acm_certificate_validation.app.certificate_arn
}
