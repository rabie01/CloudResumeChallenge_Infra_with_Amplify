pipeline {
  agent any
  environment {
    AWS_DEFAULT_REGION = "us-east-1"
    TF_VAR_github_token = credentials('github-token') // stored in Jenkins as secret
  }
  stages {
    stage('Prepare Lambda ZIP') {
      steps {
        sh 'chmod +x ./scripts/zip_lambda.sh'
        sh './scripts/zip_lambda.sh'
      }
    }
    stage('Terraform Init') {
      steps {
        sh 'cd terraform && terraform init'
      }
    }
    stage('Terraform Apply') {
      steps {
        sh 'cd terraform && terraform apply -auto-approve'
      }
    }
  }
}
