# Remote state: create the S3 bucket + DynamoDB lock table once (outside this snippet),
# then `terraform init` can store state centrally. State still contains secrets metadata;
# lock down bucket IAM when you are ready for that lesson.

terraform {
  backend "s3" {
    bucket = "my-terraform-state-storage-2026" # Change this!
    key    = "prod/terraform.tfstate"
    region = "us-east-1"

    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}