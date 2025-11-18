# OWASP Juice Shop

**Difficulty:** 3
**Description:** Comprehensive web application security testing environment with multiple OWASP Top 10 vulnerabilities  
**Estimated Time:** 2-4 hours

## Overview

OWASP Juice Shop is an intentionally insecure web application deployed on AWS EC2 with Docker. The application contains various security vulnerabilities mapped to the OWASP Top 10, CWE, and MITRE ATT&CK frameworks.

This lab integrates Juice Shop with AWS services including IAM, S3, Secrets Manager, and SSM Parameter Store to create realistic cloud-native vulnerability scenarios.

## Learning Objectives

- Identify and exploit web application vulnerabilities (OWASP Top 10)
- Perform SQL injection and XSS attacks
- Exploit broken authentication and authorization
- Discover sensitive data exposure in cloud storage
- Extract credentials from AWS services
- Enumerate S3 buckets and download sensitive files
- Access Secrets Manager to retrieve application secrets

## Scenario

You've discovered a company running OWASP Juice Shop as an internal testing application. The application is deployed on AWS with various cloud integrations for configuration and data storage.

Your goal is to exploit web vulnerabilities, gain administrative access, discover AWS credentials, and exfiltrate sensitive data from S3 and Secrets Manager.

## Architecture

- EC2 instance running Docker with Juice Shop container on port 3000
- IAM instance profile with S3 and Secrets Manager permissions
- S3 bucket containing customer orders and database backups
- Secrets Manager storing application configuration and credentials
- SSM Parameter Store with resource hints

## Attack Surface

**Web Application:**
- Main application: `http://<instance-ip>:3000`
- API endpoints under `/api/`
- Admin panel at `/#/administration`
- Score board at `/#/score-board`

**AWS Resources (from outputs):**
- S3 bucket name
- Secrets Manager ARN
- Instance IAM role
- SSM parameter paths

## Key Concepts

### OWASP Juice Shop Vulnerabilities

Juice Shop contains 100+ security challenges including:
- SQL Injection
- XSS (reflected, stored, DOM-based)
- Broken authentication
- Sensitive data exposure
- Security misconfiguration
- API abuse
- SSRF
- XXE

### AWS Cloud Integration

The lab demonstrates cloud-specific attack vectors:
- EC2 metadata service access via SSRF
- IAM role credential extraction
- S3 bucket enumeration and data exfiltration
- Secrets Manager secret retrieval
- SSM Parameter Store reconnaissance

### Instance Metadata Service

IMDSv1 provides IAM credentials at:
- `http://169.254.169.254/latest/meta-data/iam/security-credentials/`

These credentials can be used with AWS CLI to access S3 and Secrets Manager.

## Hints

<details>
<summary>Hint 1: Getting Started</summary>

Browse the application to understand its functionality. The score board (`/#/score-board`) shows all available challenges. Start with easier challenges in the "Trivial" and "Easy" categories.

Common first steps:
- SQL injection in login form
- XSS in search functionality
- Admin panel discovery
</details>

<details>
<summary>Hint 2: Finding Admin Access</summary>

Look for:
- SQL injection points in authentication
- Default or weak credentials
- JWT token manipulation
- Hidden admin endpoints

The admin panel provides access to user management and system configuration.
</details>

<details>
<summary>Hint 3: Cloud Credential Access</summary>

Once you have application-level access, look for:
- SSRF vulnerabilities to access metadata service
- File disclosure vulnerabilities revealing configuration
- Log files containing AWS resource references
- Environment variables with AWS credentials

Check `/var/log/juice-shop-setup.log` or configuration files for AWS resource hints.
</details>

<details>
<summary>Hint 4: AWS Resource Enumeration</summary>

After extracting IAM credentials:
```bash
export AWS_ACCESS_KEY_ID=<key>
export AWS_SECRET_ACCESS_KEY=<secret>
export AWS_SESSION_TOKEN=<token>

aws sts get-caller-identity
aws s3 ls
aws secretsmanager list-secrets
aws ssm describe-parameters
```

Use SSM parameters to discover additional resources.
</details>

<details>
<summary>Hint 5: Data Exfiltration</summary>

Download S3 objects:
```bash
aws s3 cp s3://<bucket>/orders/customer_orders.json .
aws s3 cp s3://<bucket>/backups/db_backup_latest.sql .
```

Retrieve secrets:
```bash
aws secretsmanager get-secret-value --secret-id <arn>
```
</details>

## Success Criteria

✓ Gain administrative access to Juice Shop  
✓ Solve multiple security challenges from the score board  
✓ Exploit SSRF or file disclosure to access EC2 metadata  
✓ Extract IAM role credentials  
✓ Enumerate S3 bucket contents  
✓ Download sensitive data files from S3  
✓ Retrieve application secrets from Secrets Manager  
✓ Find flags hidden in customer orders and database backups

## Common Pitfalls

- Not checking the score board for hints on challenge locations
- Overlooking SQL injection points in multiple input fields
- Missing SSRF vulnerabilities in URL parameter handling
- Forgetting to include session token when using temporary credentials
- Not checking SSM Parameter Store for resource hints
- Attempting to access S3 without proper AWS CLI configuration

## Remediation

**Web Application Security:**
- Use parameterized queries to prevent SQL injection
- Implement proper input validation and output encoding
- Use secure authentication mechanisms with MFA
- Implement rate limiting and CAPTCHA
- Follow OWASP secure coding guidelines
- Regular security testing and code reviews

**AWS Security:**
- Enable IMDSv2 (requires session tokens)
- Apply principle of least privilege to IAM roles
- Enable S3 bucket encryption and versioning
- Use S3 Block Public Access
- Implement Secrets Manager rotation
- Enable CloudTrail for audit logging
- Use VPC endpoints for AWS service access
- Implement WAF rules for common attack patterns

**Defense in Depth:**
- Network segmentation with security groups
- Application load balancer with WAF
- Container image scanning
- Runtime application security monitoring
- Regular vulnerability assessments

## Additional Resources

- [OWASP Juice Shop Documentation](https://pwning.owasp-juice.shop/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Juice Shop GitHub](https://github.com/juice-shop/juice-shop)

## Challenge Categories

The score board organizes challenges by difficulty:
- ⭐ Trivial (1 star)
- ⭐⭐ Easy (2 stars)
- ⭐⭐⭐ Medium (3 stars)
- ⭐⭐⭐⭐ Hard (4 stars)
- ⭐⭐⭐⭐⭐ Expert (5 stars)
- ⭐⭐⭐⭐⭐⭐ Guru (6 stars)

Focus on discovering the AWS integration points to complete the cloud-specific objectives of this lab.