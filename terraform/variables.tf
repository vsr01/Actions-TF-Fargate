# -----------------------------------------------------------------------------
# Input variables (set in CI via TF_VAR_* or in a .tfvars file for local runs).
# Run `terraform console` and type `var.<name>` to inspect values interactively.
# -----------------------------------------------------------------------------

variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Short prefix for resource names."
  default     = "myapp"
}

variable "db_password" {
  type        = string
  description = "RDS master password. Set via TF_VAR_db_password (for example GitHub Actions secret)."
  sensitive   = true
}

variable "docker_username" {
  type        = string
  description = "Docker Hub username for the application image repository."
}

variable "image_tag" {
  type        = string
  description = "Immutable image tag (for example git SHA) so ECS pulls the new image each deploy."
  default     = "latest"
}

variable "github_repository" {
  type        = string
  description = "GitHub repo for OIDC trust, in owner/name form. CI sets TF_VAR_github_repository to github.repository."
}

variable "use_existing_github_oidc_provider" {
  type        = bool
  description = "Set true if this AWS account already registered https://token.actions.githubusercontent.com (avoid duplicate provider errors)."
  default     = false
}

variable "alb_ingress_cidr_ipv4" {
  type        = string
  description = "CIDR allowed to reach the load balancer on port 80."
  default     = "0.0.0.0/0"
}
