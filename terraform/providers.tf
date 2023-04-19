# Region comes from var.aws_region — keep GitHub Actions `aws-region` input aligned with this.

provider "aws" {
  region = var.aws_region
}
