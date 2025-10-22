# IAM Privilege Escalation Lab

**Difficulty:** Easy-Medium  
**Time:** 30-45 minutes  
**Prerequisites:** AWS CLI, basic IAM knowledge

## Scenario

You've compromised credentials for a developer IAM user in a target AWS environment. Initial reconnaissance shows the account has limited permissions - typical for a junior developer role. Your objective is to escalate privileges and access sensitive data stored in S3.

The target organization follows a "self-service" model where developers can manage their own credentials. Investigate whether this policy has been implemented securely.

## Objectives

1. Enumerate your current IAM permissions
2. Identify misconfigurations in IAM policies
3. Escalate privileges to access protected resources
4. Retrieve sensitive data from S3 buckets
5. Capture the flag

## Initial Access

After deploying the lab, retrieve your credentials:

```bash
terraform output developer_access_key_id
terraform output -raw developer_secret_access_key
```

Configure your AWS CLI:

```bash
aws configure set aws_access_key_id <access_key>
aws configure set aws_secret_access_key <secret_key>
aws configure set region us-gov-east-1
```

Verify access:
```bash
aws sts get-caller-identity
```

## Enumeration Checklist

- What IAM user are you authenticated as?
- What inline policies are attached to your user?
- What permissions do these policies grant?
- Can you list S3 buckets?
- Are there any SSM parameters accessible?
- What AWS resources exist in this account?

## Key Questions

- What actions can you perform on IAM resources?
- Are there resource-level restrictions or wildcards?
- How does AWS evaluate policy variables like `${aws:username}`?
- What's the difference between `user/*` and `user/${aws:username}`?

## Attack Chain Hints

IAM privilege escalation typically follows this pattern:
1. Enumerate current permissions
2. Identify overly permissive policies
3. Leverage self-modification capabilities
4. Grant additional permissions
5. Access protected resources

Look for policies that allow you to modify IAM principals. Pay attention to `Resource` ARN patterns.

## Target

There is a protected S3 bucket containing financial data and production credentials. Standard developer access should not permit retrieval of this data. Find a way in.

## Success Criteria

- Identify the IAM policy misconfiguration
- Successfully escalate your privileges
- Access the protected S3 bucket
- Retrieve the flag from stored data

## Useful Commands

**IAM Enumeration:**
```bash
aws iam get-user
aws iam list-user-policies --user-name <username>
aws iam get-user-policy --user-name <username> --policy-name <policy-name>
aws iam list-attached-user-policies --user-name <username>
```

**S3 Operations:**
```bash
aws s3 ls
aws s3 ls s3://<bucket-name>/
aws s3 cp s3://<bucket-name>/<key> .
```

**SSM Parameters:**
```bash
aws ssm describe-parameters
aws ssm get-parameter --name <parameter-name>
```

**Policy Management:**
```bash
aws iam put-user-policy --user-name <username> --policy-name <policy-name> --policy-document file://policy.json
aws iam delete-user-policy --user-name <username> --policy-name <policy-name>
```

## Common Pitfalls

- Not reading policy documents thoroughly
- Overlooking wildcards in resource ARNs
- Assuming you need to create new users or roles
- JSON syntax errors in policy documents
- PowerShell encoding issues with JSON files

## Learning Objectives

- IAM policy evaluation logic
- Resource ARN patterns and wildcards
- Policy variables and their evaluation
- Difference between inline and managed policies
- Principle of least privilege
- Detection methods for privilege escalation

## Resources

- [AWS IAM Policy Evaluation Logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)
- [IAM Policy Variables](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html)
- [AWS CLI IAM Reference](https://docs.aws.amazon.com/cli/latest/reference/iam/)

## Notes

This lab uses intentionally vulnerable IAM configurations for educational purposes. These patterns should never exist in production environments. The vulnerability demonstrated here is based on real-world misconfigurations found during security assessments.