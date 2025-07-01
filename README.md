# 🌩️ Cloud Resume Challenge

This project implements the [Cloud Resume Challenge](https://cloudresumechallenge.dev/), showcasing practical skills in AWS cloud infrastructure, serverless computing, CI/CD, and Infrastructure as Code (IaC) using Terraform.

🌐 **Live Site:** [https://myresume.rabietech.dpdns.org/](https://myresume.rabietech.dpdns.org/)

📁 **Repositories:**
- **Frontend:** [CloudResumeChallenge_Frontend](https://github.com/rabie01/CloudResumeChallenge_Frontend)
- **Infrastructure:** [CloudResumeChallenge_Infra_with_Amplify (modularized)](https://github.com/rabie01/CloudResumeChallenge_Infra_with_Amplify/tree/modularized)

---

## 🧾 Branch Overview

This project consists of three branches, each showcasing a different Terraform structure or feature:

- **`main`**  
  - Contains a monolithic Terraform setup (no modules).
  - All resources are declared in a single set of `.tf` files.

- **`modularized`**  
  - Refactors the infrastructure using Terraform modules.
  - Each AWS service (Lambda, API Gateway, Amplify, etc.) is organized in its own module for better reusability and scalability.

- **`api_custom_domain`**  
  - Based on the non-modular structure.
  - Focuses on attaching a **custom domain** to the API Gateway endpoint.
  - Allows the frontend to call the backend using a user-friendly domain name instead of the default API Gateway URL.

---

## ⚙️ Services & Tools Used

| Category             | Tool / Service                  | Purpose                                 |
|----------------------|----------------------------------|-----------------------------------------|
| **Cloud Provider**   | AWS                              | Hosting and cloud infrastructure        |
| **IaC**              | Terraform                        | Automating AWS resource provisioning    |
| **CI/CD**            | Jenkins                          | Automating deployment pipeline          |
| **Frontend Hosting** | AWS Amplify                      | Static site hosting with GitHub CI/CD   |
| **Backend**          | AWS Lambda (Python)              | Visitor count backend function          |
| **API Gateway**      | Amazon API Gateway (HTTP API)    | RESTful API to trigger Lambda           |
| **Database**         | Amazon DynamoDB                  | Store and increment visitor counts      |
| **DNS/SSL**          | Route 53 + ACM                   | Custom domain + HTTPS                   |
| **Source Control**   | GitHub                           | Repo for frontend and Terraform code    |
| **Scripting**        | Bash                             | Lambda packaging script                 |

---

## 🔧 Prerequisites

Before deploying or modifying the infrastructure, make sure you have:

- AWS Account with admin privileges
- Terraform v1.x
- AWS CLI (configured with credentials)
- Git
- Jenkins (optional for automation)
- GitHub Personal Access Token (classic) with `repo` and `admin:repo_hook` scopes for Amplify
- A registered domain (used with Route 53)

---

## 📁 Repository Structure

### [CloudResumeChallenge_Frontend](https://github.com/rabie01/CloudResumeChallenge_Frontend)

- Static HTML/CSS/JS resume site
- Includes a JavaScript file `get_count.js` with a placeholder `__API_URL__`
- During Amplify deployment, `sed` is used to inject the real API Gateway endpoint

---

### [CloudResumeChallenge_Infra_with_Amplify](https://github.com/rabie01/CloudResumeChallenge_Infra_with_Amplify/tree/modularized)

#### 📁 Modular Terraform Setup (Branch: `modularized`)

The `modularized` branch organizes infrastructure using a clean module-based structure:

```text
terraform/
├── main.tf
├── backend.tf
├── variables.tf
├── output.tf
├── provider.tf
├── modules/
│   ├── Amplify/
│   ├── ApiGateway/
│   ├── Lambda/
│   ├── Dynamodb/
│
scripts/
└── zip_lambda.sh

- The Jenkins pipeline automates Lambda packaging and Terraform deployment.

---

## 🚀 CI/CD Pipeline (Jenkins)

### Steps:

1. **Checkout Source Code** from GitHub  
2. **Run `zip_lambda.sh`** to package the Lambda Python code  
3. **Run `terraform init`** to initialize modules  
4. **Run `terraform apply`** to provision:  
   - Lambda function  
   - API Gateway  
   - DynamoDB table  
   - IAM roles  
   - Amplify app  
5. **Amplify builds the frontend** and injects the real API URL into `get_count.js`  
6. **Frontend is deployed** to the custom domain with HTTPS  

> 💡 Jenkins securely provides the GitHub token for Amplify integration using credentials binding (`TF_VAR_github_token`).

---

## 🧠 Terraform Modules

| Module        | Description                                                 |
|---------------|-------------------------------------------------------------|
| **Amplify**   | Deploys Amplify app and connects it to the frontend repo    |
| **Lambda**    | Deploys Python Lambda function for visitor counting         |
| **ApiGateway**| Creates HTTP API Gateway to expose the Lambda               |
| **Dynamodb**  | Creates `visitor_cnt` table to store count                  |

---

## 🐍 Lambda Function (Python)

Located in the `terraform/lambda/` directory and executed by `zip_lambda.sh`, this Python Lambda:

- Uses the `boto3` SDK  
- Connects to a DynamoDB table (`visitor_cnt`)  
- Atomically increments a visitor count key on each invocation  
- Returns the updated count as a JSON response  

---

## 📦 Lambda Packaging Script

`scripts/zip_lambda.sh`:

- Navigates to `terraform/lambda`  
- Zips all Python files (`*.py`) into `lambda.zip`  
- Terraform uses the resulting archive to deploy your Lambda function  

> ⚠️ Ensure `zip` is installed on your Jenkins agent or local environment.

---

## 🛡️ Custom Domain & SSL

- **Domain:** `rabietech.dpdns.org` hosted on Route 53  
- **SSL Certificates** issued via ACM for:
  - `myresume.rabietech.dpdns.org`  
  - `www.myresume.rabietech.dpdns.org`  
- **Amplify handles**:
  - Domain association  
  - SSL validation and management  
  - HTTPS configuration  

---

## 📈 How It All Works Together

1. You visit: [https://myresume.rabietech.dpdns.org/](https://myresume.rabietech.dpdns.org/)  
2. The frontend JavaScript calls the backend API via API Gateway  
3. The API Gateway triggers a Python Lambda function  
4. Lambda increments the visitor count in DynamoDB  
5. The updated visitor count is returned and displayed on the page  

---

---

## 🙌 Author

**Rabie Rabie**  
📧 [rabeea2100@yahoo.com](mailto:rabeea2100@yahoo.com)  
🔗 [myresume.rabietech.dpdns.org](https://myresume.rabietech.dpdns.org)  
🐙 [GitHub Profile](https://github.com/rabie01)

