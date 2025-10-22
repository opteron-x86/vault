# Lambda Code Injection Lab

**Difficulty:** medium  
**Description:** Exploit command injection in a Lambda function to steal credentials and exfiltrate data  
**Estimated Time:** 60-90 minutes

## Learning Objectives

- Identify and exploit command injection vulnerabilities in serverless functions
- Extract AWS credentials from Lambda execution environments
- Enumerate and access AWS Secrets Manager
- Leverage stolen credentials for lateral movement
- Exfiltrate data from protected S3 buckets
- Understand Lambda security model and IAM role permissions

## Scenario

Your target organization has deployed a serverless health check API that allows internal services to verify connectivity to external systems. The API is built using API Gateway and Lambda, with a Python function that performs basic ping operations.

During reconnaissance, you discover an API endpoint at `/healthcheck` that accepts JSON payloads. The service is intended to be used internally but is exposed publicly for testing purposes.

Your objective is to compromise the Lambda function, steal credentials, and exfiltrate sensitive customer data from the company's S3 storage.

## Prerequisites

- AWS CLI configured with access to your lab account
- `curl` or similar HTTP client
- `jq` for JSON parsing
- Basic knowledge of:
  - Command injection techniques
  - AWS Lambda execution model
  - AWS IAM roles and policies
  - AWS Secrets Manager
  - S3 bucket operations

## Lab Deployment

```bash
# Deploy the lab
vault deploy aws/lambda-injection

# Retrieve API endpoint
vault outputs aws/lambda-injection

# Test basic connectivity
curl -X POST <API_ENDPOINT> \
  -H "Content-Type: application/json" \
  -d '{"hostname": "example.com"}'
```

## Attack Chain Overview

1. **Reconnaissance**
   - Test API endpoint functionality
   - Identify input parameters and expected behavior
   - Look for error messages or verbose responses

2. **Vulnerability Discovery**
   - Test for command injection in the `hostname` parameter
   - Identify command execution context
   - Determine available commands and tools

3. **Credential Extraction**
   - Enumerate Lambda environment variables
   - Locate AWS credential information
   - Identify IAM role and permissions

4. **Secrets Manager Access**
   - Use Lambda's IAM credentials to access Secrets Manager
   - Enumerate available secrets
   - Retrieve database credentials and configuration

5. **Data Exfiltration**
   - Parse secrets for S3 bucket information
   - Use stolen credentials to access S3
   - Download confidential customer data

## Key Concepts

### Lambda Execution Environment

Lambda functions run with:
- Temporary AWS credentials via IAM role
- Environment variables (often containing sensitive data)
- Access to AWS SDK (boto3 for Python)
- Limited execution time (default 3-10 seconds)

### Command Injection in Lambda

The vulnerable function uses `subprocess.run()` with `shell=True`, allowing command concatenation via shell metacharacters:
- `;` - Command separator
- `&&` - Execute if previous succeeds
- `||` - Execute if previous fails
- `|` - Pipe output to next command

### AWS Credential Priority

Lambda credentials are available via:
1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
2. IMDSv2 endpoint (not available in Lambda)
3. Task IAM role (automatic via SDK)

### Secrets Manager Structure

Secrets Manager stores JSON-formatted secrets with:
- Secret name (identifier)
- Secret ARN (full resource path)
- Secret value (JSON string)
- Metadata (description, tags, rotation config)

## Common Pitfalls

- **Timing out**: Lambda functions have execution time limits. Use efficient commands.
- **Output truncation**: API Gateway limits response size. Pipe commands carefully.
- **URL encoding**: Special characters may need encoding in JSON payloads.
- **Credential expiration**: Lambda credentials are temporary and expire after session ends.

## Hints

<details>
<summary>Hint 1: Testing for Command Injection</summary>

Try appending common shell operators to the hostname parameter:
```json
{"hostname": "example.com; whoami"}
{"hostname": "example.com && env"}
{"hostname": "example.com | cat /etc/passwd"}
```
</details>

<details>
<summary>Hint 2: Finding Credentials</summary>

Lambda functions have environment variables that may contain:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- Custom variables (like `DB_SECRET_NAME`)

Use `env` or `printenv` to list all environment variables.
</details>

<details>
<summary>Hint 3: Accessing Secrets Manager</summary>

The AWS CLI can be called from within Lambda if available. Alternatively:
- Use the boto3 library via Python
- Call `aws secretsmanager get-secret-value --secret-id <name>`
- Look for environment variables that reference secret names
</details>

<details>
<summary>Hint 4: Exfiltrating Data</summary>

Once you have credentials and know the S3 bucket:
- Configure AWS CLI with stolen credentials locally
- Use `aws s3 ls` to list bucket contents
- Use `aws s3 cp` to download files
- Check secrets for paths to sensitive data
</details>

## Success Criteria

You have successfully completed the lab when you:

1. ✓ Identified command injection vulnerability in the Lambda function
2. ✓ Extracted AWS credentials from the execution environment
3. ✓ Retrieved database credentials from Secrets Manager
4. ✓ Located the S3 bucket containing customer data
5. ✓ Downloaded and read the confidential customer database file
6. ✓ Captured the flag from the customer data

## Remediation

This lab demonstrates several security issues:

1. **Command Injection**
   - Never use `shell=True` with user input
   - Use parameterized commands with `subprocess.run(['ping', '-c', '1', hostname])`
   - Validate and sanitize all inputs
   - Use allowlists for permitted hostnames/IPs

2. **Excessive IAM Permissions**
   - Follow principle of least privilege
   - Lambda doesn't need Secrets Manager access for health checks
   - Restrict S3 access to specific prefixes
   - Use resource-based policies

3. **Sensitive Data in Environment Variables**
   - Don't expose secret names in environment variables
   - Use AWS Systems Manager Parameter Store for non-sensitive config
   - Implement proper secret rotation

4. **API Security**
   - Implement authentication (API keys, IAM auth, Cognito)
   - Use WAF rules to block malicious patterns
   - Rate limit requests to prevent abuse
   - Enable CloudTrail logging for audit trail

## Additional Resources

- [AWS Lambda Security Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Lambda Execution Role](https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html)

## Lab Cleanup

```bash
# Destroy all lab resources
vault destroy aws/lambda-injection

# Verify cleanup
vault status aws/lambda-injection
```

All resources are tagged with `Destroyable = true` and will be removed when you run destroy.