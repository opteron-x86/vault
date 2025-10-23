# IAM Privilege Escalation

**Difficulty:** easy-medium  
**Description:** Exploit IAM policy misconfiguration to escalate privileges and access protected S3 data  
**Estimated Time:** 30-45 minutes

## Overview

You have compromised AWS credentials for a junior developer account with limited permissions. The organization uses a "self-service" model allowing developers to manage their own credentials.

Your goal is to identify IAM policy misconfigurations, escalate privileges, and access sensitive financial data stored in a protected S3 bucket.

## Learning Objectives

- Enumerate IAM user permissions and policies
- Identify overly permissive resource ARN patterns
- Understand IAM policy evaluation and wildcards
- Exploit self-service IAM policies for privilege escalation
- Access protected S3 resources after escalation
- Detect and prevent IAM privilege escalation attacks

## Scenario

Internal developers have read-only access to most AWS services for troubleshooting. To reduce friction, the security team implemented self-service credential management allowing developers to rotate their own access keys.

You've obtained credentials for a developer account. Initial testing shows limited S3 access and no obvious paths to sensitive data. However, there's a protected S3 bucket containing financial records and production credentials that's off-limits to standard developers.

Find the misconfiguration and escalate your privileges to access the protected bucket.

## Architecture

- IAM user with programmatic access (access key/secret)
- Inline IAM policies for base permissions and self-service
- Protected S3 bucket with financial data and credentials
- SSM Parameter Store containing configuration hints
- CloudTrail logging for audit compliance
- Admin automation role with elevated S3 permissions

## Attack Surface

**Initial Credentials:**
- AWS Access Key ID
- AWS Secret Access Key
- Region: us-gov-east-1

**Available from outputs:**
- Developer username
- Protected bucket name
- AWS region

## Key Concepts

### IAM Policy Evaluation

AWS evaluates permissions based on:
- Explicit deny (highest priority)
- Explicit allow
- Implicit deny (default)

Policies use Resource ARNs to specify targets. Wildcards (`*`) in ARNs can create unintended permissions.

### Resource ARN Patterns

Common patterns:
```
arn:aws:iam::account-id:user/*                    # All users
arn:aws:iam::account-id:user/${aws:username}      # Only own user
arn:aws:iam::account-id:user/prefix-*             # Users with prefix
```

### Policy Variables

IAM supports variables for dynamic evaluation:
- `${aws:username}` - Current user's name
- `${aws:userid}` - Current user's ID
- `${aws:PrincipalArn}` - ARN of the calling principal

Intended to restrict actions to own resources, but easy to misconfigure.

### Self-Service IAM Actions

Common actions for credential management:
- `iam:CreateAccessKey` - Generate new access keys
- `iam:DeleteAccessKey` - Remove access keys
- `iam:PutUserPolicy` - Attach inline policy to user
- `iam:DeleteUserPolicy` - Remove inline policy

### Privilege Escalation via IAM

If a user can modify their own policies:
1. Create new inline policy with elevated permissions
2. Attach policy to own user
3. Use new permissions to access restricted resources
4. Clean up by removing the policy (optional)

## Hints

<details>
<summary>Hint 1: Enumeration</summary>

Start by understanding what you can do:
```bash
aws iam get-user
aws iam list-user-policies --user-name <username>
aws iam get-user-policy --user-name <username> --policy-name <policy>
```

Look for policies that mention IAM actions. Pay attention to Resource ARNs.
</details>

<details>
<summary>Hint 2: Policy Analysis</summary>

Check the `SelfManagePolicies` statement. What actions does it allow?

Look at the Resource ARN. Does it properly restrict to only your user, or does it use a wildcard pattern that could match other users too?

Remember: `user/*` matches all users, while `user/${aws:username}` matches only yours.
</details>

<details>
<summary>Hint 3: Privilege Escalation</summary>

If you can call `iam:PutUserPolicy` on your own user, you can grant yourself any permissions.

Create a policy JSON file that grants S3 access, then attach it:
```bash
aws iam put-user-policy --user-name <username> --policy-name <name> --policy-document file://policy.json
```
</details>

<details>
<summary>Hint 4: Finding the Bucket</summary>

Once escalated, check SSM parameters for configuration hints:
```bash
aws ssm describe-parameters
aws ssm get-parameter --name <parameter-name>
```

You can also list all S3 buckets and look for the protected one:
```bash
aws s3 ls
```
</details>

## Success Criteria

✓ Enumerate IAM user permissions  
✓ Identify policy misconfiguration in Resource ARN  
✓ Create inline policy granting elevated permissions  
✓ Attach policy to escalate privileges  
✓ Access protected S3 bucket  
✓ Download sensitive financial data  
✓ Capture the flag from customer records

## Common Pitfalls

- Not reading Resource ARN patterns carefully
- Assuming you need to create new users or roles (you don't)
- JSON syntax errors in policy documents
- Forgetting to specify policy document in correct format
- Not checking SSM parameters for hints
- Overlooking the wildcard in the Resource ARN

## Remediation

**IAM Policy Best Practices:**
- Use specific Resource ARNs instead of wildcards
- Always use `${aws:username}` for self-service actions
- Example: `arn:aws:iam::account:user/${aws:username}` NOT `arn:aws:iam::account:user/*`
- Implement policy validation in CI/CD pipelines

**Principle of Least Privilege:**
- Grant only minimum required permissions
- Use managed policies when possible
- Regular audit of inline policies
- Implement permission boundaries for delegated administration

**Detection and Monitoring:**
- CloudTrail alerts on `PutUserPolicy` actions
- Monitor for rapid permission changes
- Flag policies granting broad permissions
- Automated policy analysis tools (AWS Access Analyzer)

**Alternative Approaches:**
- Use AWS IAM Identity Center (SSO) for credential management
- Implement break-glass procedures instead of self-service
- Require MFA for sensitive IAM operations
- Use service control policies (SCPs) for organizational guardrails