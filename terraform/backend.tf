terraform {
  backend s3 {
    bucket         = mybuckett21000
    key            = terraformmyresumeamplifyterraform.tfstate
    region         = us-east-1
    encrypt        = true
  }
}
