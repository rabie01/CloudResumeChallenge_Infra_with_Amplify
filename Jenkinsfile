pipeline {
  agent any
  options {
        ansiColor('xterm')
    }

    parameters {
            booleanParam(name: 'PLAN_TERRAFORM', defaultValue: true, description: 'Check to plan Terraform changes')
            booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Check to apply Terraform changes')
            booleanParam(name: 'DESTROY_TERRAFORM', defaultValue: false, description: 'Check to apply Terraform changes')
    }
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

        stage('Terraform plan') {
      when {
                expression {params.APPLY_TERRAFORM}
            }

      steps {
        withCredentials([string(credentialsId: 'github_amplify', variable: 'TF_VAR_github_token')]) {
          sh 'cd terraform && terraform plan -auto-approve'
      }
    }
  }
    stage('Terraform Apply') {
      when {
                expression {params.APPLY_TERRAFORM}
            }

      steps {
        withCredentials([string(credentialsId: 'github_amplify', variable: 'TF_VAR_github_token')]) {
          sh 'cd terraform && terraform apply -auto-approve'
      }
    }
  }

      stage('Terraform destroy') {
        when {
                expression {params.DESTROY_TERRAFORM}
            }
        steps {
        
          sh 'cd terraform && terraform destroy -auto-approve'
        }
      
    }
  }

}
