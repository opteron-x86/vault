# OWASP Juice Shop (GCP)

**Difficulty:** 3
**Description:** Comprehensive web application security testing environment with multiple OWASP Top 10 vulnerabilities  
**Estimated Time:** 2-4 hours

## Overview

OWASP Juice Shop is an intentionally insecure web application deployed on Google Cloud Platform with Compute Engine. The application contains various security vulnerabilities mapped to the OWASP Top 10, CWE, and MITRE ATT&CK frameworks.

This lab integrates Juice Shop with GCP services including Service Accounts, Cloud Storage, Secret Manager, and Cloud Logging to create realistic cloud-native vulnerability scenarios.

## Learning Objectives

- Identify and exploit web application vulnerabilities (OWASP Top 10)
- Perform SQL injection and XSS attacks
- Exploit broken authentication and authorization
- Discover sensitive data exposure in cloud storage
- Extract credentials from GCP services
- Enumerate Cloud Storage buckets and download sensitive files
- Access Secret Manager to retrieve application secrets
- Abuse GCE metadata service for credential extraction

## Scenario

You've discovered a company running OWASP Juice Shop as an internal testing application. The application is deployed on GCP with various cloud integrations for configuration and data storage.

Your goal is to exploit web vulnerabilities, gain administrative access, discover GCP credentials, and exfiltrate sensitive data from Cloud Storage and Secret Manager.

## Architecture

- GCE instance running Docker with Juice Shop container on port 3000
- Service account with Cloud Storage and Secret Manager permissions
- Cloud Storage bucket containing customer orders and database backups
- Secret Manager storing application configuration and credentials
- VPC network with firewall rules for SSH and HTTP

## Attack Surface

**Web Application:**
- Main application: `http://<external-ip>:3000`
- API endpoints under `/api/`
- Admin panel at `/#/administration`
- Score board at `/#/score-board`

**GCP Resources (from outputs):**
- Cloud Storage bucket name
- Secret Manager secret ID
- Service account email
- Instance external IP

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

### GCP Cloud Integration

The lab demonstrates cloud-specific attack vectors:
- GCE metadata service access via SSRF
- Service account credential extraction
- Cloud Storage bucket enumeration and data exfiltration
- Secret Manager secret retrieval
- Cloud resource reconnaissance

### GCE Metadata Service

The metadata service provides service account credentials at:
- `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token`
- Requires `Metadata-Flavor: Google` header
- Returns short-lived OAuth2 tokens

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
- Log files containing GCP resource references
- Environment variables with GCP credentials

Check `/var/log/juice-shop-setup.log` or configuration files for GCP resource hints.

GCE metadata endpoint: `http://metadata.google.internal/computeMetadata/v1/`
</details>

<details>
<summary>Hint 4: GCP Metadata Service</summary>

Access the metadata service to get service account tokens:
```bash
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
```

The token can be used with `gcloud` or REST APIs:
```bash
export CLOUDSDK_AUTH_ACCESS_TOKEN=<token>
gcloud config set project <project-id>
```
</details>

<details>
<summary>Hint 5: Cloud Storage Enumeration</summary>

List and download bucket contents:
```bash
gcloud storage ls gs://<bucket-name>/
gcloud storage cp gs://<bucket-name>/orders/customer_orders.json .
gcloud storage cp gs://<bucket-name>/backups/db_backup_latest.sql .
```

Or use REST API:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://storage.googleapis.com/storage/v1/b/<bucket>/o
```
</details>

<details>
<summary>Hint 6: Secret Manager Access</summary>

Retrieve secrets:
```bash
gcloud secrets versions access latest --secret=<secret-id>
```

Or REST API:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://secretmanager.googleapis.com/v1/projects/<project>/secrets/<secret-id>/versions/latest:access
```
</details>

## Success Criteria

✓ Gain administrative access to Juice Shop  
✓ Solve multiple security challenges from the score board  
✓ Exploit SSRF or file disclosure to access GCE metadata  
✓ Extract service account credentials  
✓ Enumerate Cloud Storage bucket contents  
✓ Download sensitive data files from Cloud Storage  
✓ Retrieve application secrets from Secret Manager  
✓ Find flags hidden in customer orders and database backups

## Common Pitfalls

- Not checking the score board for hints on challenge locations
- Overlooking SQL injection points in multiple input fields
- Missing SSRF vulnerabilities in URL parameter handling
- Forgetting to include `Metadata-Flavor: Google` header for metadata requests
- Attempting to use AWS CLI commands instead of gcloud
- Not properly setting the OAuth2 token for API requests
- Missing the project ID requirement for some gcloud commands

## Remediation

**Web Application Security:**
- Use parameterized queries to prevent SQL injection
- Implement proper input validation and output encoding
- Use secure authentication mechanisms with MFA
- Implement rate limiting and CAPTCHA
- Follow OWASP secure coding guidelines
- Regular security testing and code reviews

**GCP Security:**
- Disable legacy metadata endpoints
- Use Workload Identity for GKE workloads
- Apply principle of least privilege to service accounts
- Implement VPC Service Controls
- Enable Cloud Storage encryption and retention policies
- Use Secret Manager rotation policies
- Enable Cloud Audit Logging
- Implement Organization Policy constraints

**Defense in Depth:**
- Network segmentation with VPC firewall rules
- Cloud Armor for DDoS protection and WAF
- Container image scanning with Artifact Analysis
- Runtime security monitoring with Security Command Center
- Regular vulnerability assessments

## Additional Resources

- [OWASP Juice Shop Documentation](https://pwning.owasp-juice.shop/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
- [Juice Shop GitHub](https://github.com/juice-shop/juice-shop)
- [GCP Metadata Service Documentation](https://cloud.google.com/compute/docs/metadata/overview)

## Challenge Categories

The score board organizes challenges by difficulty:
- ⭐ Trivial (1 star)
- ⭐⭐ Easy (2 stars)
- ⭐⭐⭐ Medium (3 stars)
- ⭐⭐⭐⭐ Hard (4 stars)
- ⭐⭐⭐⭐⭐ Expert (5 stars)
- ⭐⭐⭐⭐⭐⭐ Guru (6 stars)

Focus on discovering the GCP integration points to complete the cloud-specific objectives of this lab.