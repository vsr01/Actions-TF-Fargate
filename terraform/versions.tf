# Root module: pin Terraform and providers so `terraform init` is reproducible.

terraform {
  # S3 backend `use_lockfile` (native locking) is stable in Terraform 1.11+.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
