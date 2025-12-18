# React2Shell (CVE-2025-55182) - Azure

**Difficulty:** 4  
**Time:** 45-60 minutes  
**Prerequisites:** HTTP request crafting, Azure CLI, basic Linux commands

## Scenario

A SaaS company runs their customer portal on Next.js with React Server Components. The application was deployed before the React2Shell vulnerability disclosure and remains unpatched. The portal integrates with Azure services for data storage and secrets management.

Your objective is to exploit CVE-2025-55182 to gain remote code execution, enumerate the cloud environment, and exfiltrate customer data from Azure Blob Storage.

## Objectives

1. Identify the vulnerable Next.js application
2. Exploit React2Shell for remote code execution
3. Enumerate the server environment
4. Extract managed identity token from Azure IMDS
5. Access Blob Storage containing customer data
6. Retrieve secrets from Key Vault

## Architecture

- Azure VM running Next.js 16.0.6 with App Router
- User-assigned managed identity with Storage and Key Vault access
- Storage Account with customer exports and API keys
- Key Vault storing database credentials and tokens
- Azure IMDS available for credential retrieval

## Attack Surface

**Web Application:** `http://<vm-ip>:3000`

The application uses React Server Components which are vulnerable by default in Next.js 16.0.6.

## CVE-2025-55182 Overview

React2Shell is an unsafe deserialization vulnerability in the React Server Components "Flight" protocol. The flaw allows unauthenticated attackers to achieve remote code execution by sending a crafted HTTP request to any RSC endpoint.

Key characteristics:
- CVSS 10.0 (Critical)
- Affects React 19.x and Next.js 15.x/16.x with App Router
- Default configurations are vulnerable
- Near 100% exploitation success rate
- No authentication required

## Flags

- **Flag 1:** Blob Storage customer data exfiltration
- **Flag 2:** API keys exposure
- **Flag 3:** Key Vault secrets access

## Enumeration Checklist

### Phase 1: Reconnaissance
- What framework and version is the application running?
- Are React Server Components enabled?
- What endpoints exist on the application?

### Phase 2: Exploitation
- How do you identify RSC endpoints?
- What does a React2Shell payload look like?
- How do you verify successful code execution?

### Phase 3: Post-Exploitation
- What environment variables are set?
- What user context is the application running as?
- What network access does the server have?

### Phase 4: Cloud Pivot
- How do you access Azure IMDS?
- What managed identity is attached to the VM?
- What permissions does the identity have?

### Phase 5: Data Exfiltration
- What storage accounts are accessible?
- What blobs contain sensitive data?
- What secrets can be retrieved from Key Vault?

## Hints

<details>
<summary>Hint 1: Version Detection</summary>

Check response headers or JavaScript bundles for Next.js version indicators. The `x-powered-by` header may reveal framework information.
</details>

<details>
<summary>Hint 2: RSC Endpoints</summary>

React Server Components communicate using the Flight protocol. Look for requests with specific content types or action parameters. Server Actions create exploitable endpoints automatically.
</details>

<details>
<summary>Hint 3: Payload Execution</summary>

Public PoC exploits are available. The vulnerability is in the deserialization of RSC payloads. Command execution can be achieved through prototype pollution gadgets.
</details>

<details>
<summary>Hint 4: Environment Discovery</summary>

After achieving RCE, check:
- `/opt/webapp/.env` for application configuration
- Environment variables for cloud resource identifiers
- Process environment with `env` or `printenv`
</details>

<details>
<summary>Hint 5: Azure IMDS Access</summary>

The Azure Instance Metadata Service provides managed identity tokens:
```bash
curl -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com/&client_id=<CLIENT_ID>"
```
</details>

<details>
<summary>Hint 6: Azure CLI Usage</summary>

Use the retrieved token with Azure CLI or direct REST calls:
```bash
# List blobs
curl -H "Authorization: Bearer $TOKEN" \
  -H "x-ms-version: 2020-04-08" \
  "https://<storage>.blob.core.usgovcloudapi.net/<container>?restype=container&comp=list"

# Download blob
curl -H "Authorization: Bearer $TOKEN" \
  -H "x-ms-version: 2020-04-08" \
  "https://<storage>.blob.core.usgovcloudapi.net/<container>/<blob>"
```

For Key Vault:
```bash
curl -H "Authorization: Bearer $TOKEN" \
  "https://<vault>.vault.usgovcloudapi.net/secrets?api-version=7.4"
```
</details>

## MITRE ATT&CK Mapping

| Tactic | Technique | Description |
|--------|-----------|-------------|
| Initial Access | T1190 | Exploit Public-Facing Application |
| Execution | T1059.004 | Unix Shell |
| Discovery | T1082 | System Information Discovery |
| Credential Access | T1552.005 | Cloud Instance Metadata API |
| Collection | T1530 | Data from Cloud Storage |
| Exfiltration | T1567 | Exfiltration Over Web Service |

## References

- [CVE-2025-55182 - NVD](https://nvd.nist.gov/vuln/detail/CVE-2025-55182)
- [React Security Advisory](https://github.com/facebook/react/security/advisories)
- [React2Shell Technical Analysis](https://react2shell.com/)
- [Azure IMDS Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/instance-metadata-service)