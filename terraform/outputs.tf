output "alb_dns_name" {
  description = "Open this hostname in a browser (HTTP port 80) once the service is healthy."
  value       = aws_lb.app.dns_name
}

# Handy for labs: compare /health (no DB) vs / (hits MySQL).
output "alb_urls" {
  description = "Example URLs through the load balancer for the Flask app."
  value = {
    app    = "http://${aws_lb.app.dns_name}/"
    health = "http://${aws_lb.app.dns_name}/health"
  }
}

output "github_actions_deploy_role_arn" {
  description = "Add this value as GitHub repository secret AWS_ROLE_ARN for OIDC-based deploys."
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_oidc_provider_arn" {
  description = "IAM OIDC provider ARN used for GitHub Actions (for troubleshooting)."
  value       = local.github_oidc_provider_arn
}
