# Remote state: create the S3 bucket in this AWS account first (name must be globally unique),
# set `bucket` below to match, then run `terraform init`. Locking uses S3 native lockfiles
# (`use_lockfile`, Terraform >= 1.11) — no DynamoDB table required.
#
# State can still reference sensitive resource metadata; tighten bucket IAM when you are ready.

terraform {
  backend "s3" {
    bucket       = "my-terraform-state-storage-2026" # Replace with YOUR bucket name
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}