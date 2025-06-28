terraform {
  backend "s3" {
    bucket  = "mybuckett21000"
    key     = "terraform/myresume/amplify/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
