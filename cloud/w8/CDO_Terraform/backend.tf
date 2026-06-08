# ==============================================================================
# INSTRUCTIONS FOR REMOTE STATE BACKEND
# ==============================================================================
# 1. First, navigate to the `bootstrap` directory: cd bootstrap
# 2. Initialize and apply the bootstrap code to create the S3 bucket & DynamoDB table:
#    terraform init
#    terraform apply -auto-approve
# 3. Take note of the output `s3_bucket_name` (e.g. terraform-state-web-app-xxxxxxxx)
# 4. Uncomment the backend block below and replace the bucket name with the output.
# 5. From the root directory, run:
#    terraform init -migrate-state
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "terraform-state-web-app-hwwpnx07"
    key            = "dev/web-app-state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
