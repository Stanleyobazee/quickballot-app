output "ci_plan_role_arn" {
  description = "ARN of the role GitHub Actions assumes to run terraform plan"
  value       = aws_iam_role.ci_plan.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ci_push_role_arn" {
  description = "ARN of the role GitHub Actions assumes on the main branch to push images to ECR"
  value       = aws_iam_role.ci_push.arn
}

output "ci_deploy_role_arn" {
  description = "ARN of the role the production deploy workflow assumes to update the cluster"
  value       = aws_iam_role.ci_deploy.arn
}
