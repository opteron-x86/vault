# VAULT - Vulnerability Analysis Universal Lab Terminal

Python CLI tool for deploying and managing cloud security lab infrastructure across AWS, Azure, and GCP.

## Prerequisites

- Python 3.12+
- Terraform 1.0+
- Cloud provider CLI tools (AWS CLI, Azure CLI, or gcloud)
- Valid cloud credentials configured

## Installation

```bash
# Clone repository
git clone <repository-url>
cd cyber-threat-emulation

# Create virtual environment
python3.13 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install vault
pip install -e .

# Verify installation
vault --help
```

## Project Structure

```
cyber-threat-emulation/
├── labs/                    # Lab terraform configurations
│   ├── aws/
│   ├── azure/
│   └── gcp/
├── config/                  # CSP configuration files
│   ├── common-aws.tfvars
│   ├── common-azure.tfvars
│   └── common-gcp.tfvars
├── .state/                  # Terraform state and metadata
│   └── .metadata/
├── modules/                 # Shared terraform modules
└── vault/                   # Application source
```

## Configuration

### AWS Setup

Create `config/common-aws.tfvars`:

```hcl
aws_region = "us-gov-east-1"
allowed_source_ips = ["YOUR_IP/32"]
```

Configure AWS credentials:
```bash
aws configure --profile default
```

### Azure Setup

Create `config/common-azure.tfvars`:

```hcl
azure_region = "usgovvirginia"
```

Authenticate:
```bash
az login
```

### GCP Setup

Create `config/common-gcp.tfvars`:

```hcl
gcp_project = "your-project-id"
gcp_region = "us-east4"
```

Authenticate:
```bash
gcloud auth application-default login
gcloud config set project your-project-id
```

## Usage

### Interactive Mode

Launch interactive shell with tab completion and command history:

```bash
vault
```

Commands available in interactive mode:

```
list [query]         List all labs, optionally filter by query
use <lab>            Select lab by path or number
info [lab]           Display lab details and README
init [lab]           Initialize lab (download providers, configure backend)
plan [lab]           Show terraform plan without deploying
deploy [lab]         Deploy selected or specified lab
destroy [lab]        Destroy deployed lab
status [lab]         Show deployment status and resources
outputs [lab]        Display lab outputs (--sensitive for all values)
active               List active deployments
search <query>       Fuzzy search across lab names and descriptions
validate [lab]       Validate terraform configuration
back                 Deselect current lab
clear                Clear screen
help                 Show help
exit                 Exit vault
```

### CLI Mode

Execute single commands without entering interactive mode:

```bash
# List all labs
vault list

# Search labs
vault search ssrf
vault search "privilege escalation"

# Deploy lab
vault deploy aws/iam-privesc

# Check status
vault status aws/iam-privesc

# View outputs
vault outputs aws/iam-privesc
vault outputs aws/iam-privesc --sensitive

# Destroy lab
vault destroy aws/iam-privesc

# Show active deployments
vault active
```

## Workflow Examples

### Deploy Lab

```bash
# Interactive
vault
> list
> use 1                    # or: use aws/iam-privesc
> info                     # Review lab details
> deploy                   # Review plan, confirm deployment

# CLI
vault deploy aws/iam-privesc
```

### Check Lab Status

```bash
# Interactive
vault
> status aws/iam-privesc

# CLI
vault status aws/iam-privesc
```

### Retrieve Outputs

```bash
# Interactive
vault
> use aws/iam-privesc
> outputs
> outputs --sensitive      # Show sensitive values

# CLI
vault outputs aws/iam-privesc --sensitive
```

### Destroy Lab

```bash
# Interactive
vault
> destroy aws/iam-privesc  # Requires lab name confirmation

# CLI
vault destroy aws/iam-privesc
```

### Search Labs

```bash
# Interactive
vault
> search metadata
> search privilege escalation

# CLI
vault search ssrf
```

## Lab Development

### Create New Lab

1. Create lab directory:
```bash
mkdir -p labs/aws/my-new-lab
cd labs/aws/my-new-lab
```

2. Create terraform files:
```bash
touch main.tf variables.tf outputs.tf README.md
```

3. Follow lab development guidelines in `instructions.md`

4. Test lab:
```bash
vault validate aws/my-new-lab
vault deploy aws/my-new-lab
```

### Lab README Format

Labs are auto-discovered when they contain `main.tf`. Metadata is parsed from README.md:

```markdown
# Lab Name

**Difficulty:** easy-medium
**Description:** Brief description of the lab scenario
**Estimated Time:** 45-60 minutes

## Learning Objectives
- Objective 1
- Objective 2

## Scenario
Detailed scenario description...
```

## State Management

Vault maintains deployment state in `.state/`:

- `.state/<csp>_<lab>/terraform.tfstate` - Terraform state
- `.state/.metadata/<csp>_<lab>.json` - Deployment metadata

State includes:
- Resource count
- Deployment timestamp
- Deployed by user
- Last action
- Region

## Troubleshooting

### Terraform Not Found

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Import Errors

Ensure vault is installed in development mode:
```bash
pip install -e . --force-reinstall
```

### Missing Cloud CLI

Install required CLI tools:
```bash
# AWS CLI
pip install awscli

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# gcloud
# See: https://cloud.google.com/sdk/docs/install
```

### Configuration File Errors

Vault creates template config files on first run. Edit placeholders:

```bash
# Check for YOUR_IP or YOUR_PROJECT_ID placeholders
grep -r "YOUR_" config/

# Update with actual values
vim config/common-aws.tfvars
```

### State File Corruption

If state becomes corrupted:
```bash
# Backup existing state
cp -r .state .state.backup

# Remove corrupted state
rm -rf .state/aws_problematic-lab

# Redeploy if needed
vault deploy aws/problematic-lab
```

### Lab Not Found

Vault discovers labs by scanning `labs/` directory. Verify structure:

```bash
# Lab must contain main.tf
ls labs/aws/my-lab/main.tf

# Refresh lab cache
vault
> list
```

## Advanced Features

### Tab Completion

Interactive mode supports context-aware tab completion:
- Command names
- Lab paths
- CSP-specific suggestions

### Command History

Command history persists between sessions in `.state/.vault_history`

### Fuzzy Search

Search uses fuzzy matching across:
- Lab names
- Descriptions
- Learning objectives
- File paths

### Output Filtering

Filter terraform plan/apply output:
- ANSI color codes stripped
- Compact warnings enabled
- JSON output for programmatic access

## Security Considerations

- Never commit `.state/` to version control (already in `.gitignore`)
- Store sensitive outputs securely
- Review terraform plans before deployment
- Use `allowed_source_ips` to restrict lab access
- Enable auto-shutdown on lab resources
- Monitor cloud costs with budget alerts

## Development

### Run Tests

```bash
pip install -e ".[dev]"
pytest
pytest --cov=vault --cov-report=html
```

### Type Checking

```bash
mypy vault
```

### Linting

```bash
ruff check vault
ruff format vault
```

### Adding New Provider

1. Create provider class in `vault/providers/`
2. Implement `BaseProvider` interface
3. Register in `ProviderFactory._providers`
4. Add configuration template

## Contributing

Follow guidelines in `instructions.md` for:
- Lab structure conventions
- Naming standards
- Security requirements
- Documentation requirements

## Support

- GitLab: https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation
- Contact: caleb.n.cline.ctr@mail.mil
- Organization: DG35 - Cyber Threat Emulation