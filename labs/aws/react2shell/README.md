# React2Shell (CVE-2025-55182)

**Difficulty:** 5  
**Time:** 60-90 minutes  
**CVE:** CVE-2025-55182  
**CVSS:** 10.0  

## Overview

Exploit an unsafe deserialization vulnerability in React Server Components to achieve unauthenticated remote code execution on a Next.js application, then pivot to AWS credential extraction and data exfiltration.

## Learning Objectives

- Identify vulnerable Next.js/React Server Components deployments
- Exploit CVE-2025-55182 deserialization vulnerability
- Execute arbitrary code via RSC Flight protocol
- Extract IAM credentials from EC2 metadata service
- Exfiltrate data from S3 and Secrets Manager

## Scenario

You've discovered a corporate internal dashboard running Next.js 16.0.6 with React Server Components enabled. The application uses AWS services for data storage and configuration. Your objective is to exploit the React2Shell vulnerability to gain code execution, then leverage the instance's IAM role to access sensitive data.

## Architecture

- EC2 instance running Next.js 16.0.6 (vulnerable)
- React 19.1.0 with Server Components enabled
- IAM instance profile with S3/Secrets Manager access
- IMDSv1 enabled
- S3 bucket with customer data and flags
- Secrets Manager with application secrets

## Attack Surface

**Web Application:**
```
http://<instance-ip>:3000
```

**Vulnerable Component:**
- React Server Components Flight protocol
- Default App Router configuration
- Server actions endpoint

## Vulnerability Details

CVE-2025-55182 is an unsafe deserialization vulnerability in the React Server Components Flight protocol. Applications using React 19.x with Server Components are vulnerable even without explicitly defined server functions.

**Affected Versions:**
- React: 19.0, 19.1.0, 19.1.1, 19.2.0
- Next.js: 15.x, 16.x (with App Router)

**Fixed Versions:**
- React: 19.0.1, 19.1.2, 19.2.1
- Next.js: 15.1.4+, 16.0.7+

## Attack Chain

1. **Reconnaissance** - Identify Next.js version and RSC endpoints
2. **Exploitation** - Send crafted Flight protocol payload for RCE
3. **Credential Extraction** - Query IMDS for IAM role credentials
4. **Enumeration** - Discover S3 buckets and Secrets Manager resources
5. **Exfiltration** - Retrieve flags from cloud storage

## Flags

- **Flag 1:** S3 bucket `/internal/flag.txt`
- **Flag 2:** Secrets Manager `jwt_secret` value

## Hints

<details>
<summary>Hint 1: Version Detection</summary>

Check response headers and `/_next/` static paths. The `x-powered-by` header often reveals Next.js. Page source may contain version info in bundled scripts.
</details>

<details>
<summary>Hint 2: Exploitation</summary>

Public PoC exploits are available at:
- https://github.com/lachlan2k/React2Shell-CVE-2025-55182-original-poc
- https://github.com/assetnote/react2shell-scanner

The vulnerability targets the RSC Flight protocol deserialization.
</details>

<details>
<summary>Hint 3: Post-Exploitation</summary>

After RCE, query the metadata service:
```bash
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```
Use extracted credentials with AWS CLI to access S3 and Secrets Manager.
</details>

<details>
<summary>Hint 4: Data Exfiltration</summary>

```bash
aws s3 ls s3://<bucket-name>/ --recursive
aws s3 cp s3://<bucket-name>/internal/flag.txt -
aws secretsmanager get-secret-value --secret-id <arn>
```
</details>

## MITRE ATT&CK Mapping

| Tactic | Technique | ID |
|--------|-----------|-----|
| Initial Access | Exploit Public-Facing Application | T1190 |
| Execution | Command and Scripting Interpreter | T1059 |
| Credential Access | Unsecured Credentials: Cloud Instance Metadata API | T1552.005 |
| Collection | Data from Cloud Storage | T1530 |
| Exfiltration | Exfiltration Over Web Service | T1567 |

## References

- https://react2shell.com/
- https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components
- https://github.com/facebook/react/security/advisories/GHSA-fv66-9v8q-g76r
- https://github.com/vercel/next.js/security/advisories/GHSA-9qr9-h5gf-34mp