# VAULT 35 - Virtual Attack Utility Lab Terminal

[![Version](https://img.shields.io/badge/version-1.4.1-blue.svg)](CHANGELOG.md)
[![Python](https://img.shields.io/badge/python-3.12%2B-blue.svg)](https://www.python.org/)
[![Terraform](https://img.shields.io/badge/terraform-1.0%2B-purple.svg)](https://www.terraform.io/)
[![Org: DISA DG35](https://img.shields.io/badge/org-DG35-green.svg)]()
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

VAULT 35 is a comprehensive Python CLI tool for deploying and managing threat emulation labs across AWS, Azure, and GCP. Designed for cybersecurity professionals, VAULT provides pre-built vulnerable infrastructure scenarios for adversary emulation, penetration testing training, and detection engineering.

## 🚀 Features

- **Multi-Cloud Support** - Deploy labs seamlessly across AWS, Azure, and GCP
- **Interactive CLI** - Intuitive shell with tab completion and command history
- **Automated Attack Chains** - Built-in scripts to automate exploitation workflows
- **Lab Discovery** - Fuzzy search across labs by name, description, or objectives
- **State Management** - Isolated Terraform state per deployment with metadata tracking
- **Configuration Wizard** - Interactive setup for cloud provider configuration
- **Cost Controls** - Auto-shutdown tags and resource limits to prevent cost overruns
- **Lab Validation** - Pre-deployment validation of Terraform configurations

## 📋 Prerequisites

- **Python** 3.12 or higher
- **Terraform** 1.0 or higher
- **Cloud CLI Tools** - AWS CLI, Azure CLI, or gcloud SDK
- **Valid Cloud Credentials** - Configured for your target provider(s)

## 🔧 Installation

```bash
# Clone the repository
git clone https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation.git
cd cyber-threat-emulation

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install VAULT
pip install -e .

# Verify installation
vault --version
```

## ⚙️ Configuration

VAULT includes an interactive setup wizard to help you configure cloud providers.

### Quick Setup

```bash
# Interactive setup for all providers
vault setup

# Or setup a specific provider
vault setup aws
vault setup azure
vault setup gcp
```

The setup wizard will:
- Auto-detect your public IP address
- Prompt for cloud-specific settings
- Generate configuration files in `config/`
- Validate cloud CLI tool installation

### Manual Configuration

Alternatively, create configuration files manually:

**AWS** (`config/common-aws.tfvars`):
```hcl
aws_region          = "us-gov-east-1"
allowed_source_ips  = ["YOUR_IP/32"]
ssh_key_name        = "YOUR_SSH_KEY"
lab_prefix          = "yourname-lab"
default_tags = {
  Owner       = "you@example.com"
  Environment = "lab"
}
```

**Azure** (`config/common-azure.tfvars`):
```hcl
azure_region = "usgovvirginia"
lab_prefix   = "yourname-lab"
```

**GCP** (`config/common-gcp.tfvars`):
```hcl
gcp_project = "your-project-id"
gcp_region  = "us-east4"
lab_prefix  = "yourname-lab"
```

### Cloud Authentication

**AWS:**
```bash
aws configure --profile default
# Or use environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
```

**Azure:**
```bash
az cloud set --name AzureUSGovernment
az login
```

**GCP:**
```bash
gcloud auth application-default login
gcloud config set project your-project-id
```

## 🎯 Usage

### Interactive Mode

Launch the interactive shell with tab completion and command history:

```bash
vault
```

Available commands:
```
list [query]         List all labs, optionally filter by query
use <lab>            Select lab by path or number
info [lab]           Display lab details and README
init [lab]           Initialize lab (download providers)
plan [lab]           Preview terraform plan without deploying
deploy [lab]         Deploy selected or specified lab
attack [lab]         Automate attack chain against deployed lab
destroy [lab]        Destroy deployed lab resources
status [lab]         Show deployment status and resource count
outputs [lab]        Display lab outputs (--sensitive for all values)
active               List all active deployments
search <query>       Fuzzy search across lab names and descriptions
validate [lab]       Validate terraform configuration
setup [provider]     Run configuration wizard (aws/azure/gcp/all)
check                Check CSP CLI tool installation
install <tool>       Show installation instructions for tools
git                  Show git repository status
version              Display VAULT version
back                 Deselect current lab
clear                Clear screen
help                 Show help
exit                 Exit vault
```

### CLI Mode

Execute commands directly without entering interactive mode:

```bash
# List and search labs
vault list
vault search ssrf
vault search "privilege escalation"

# Deploy and manage labs
vault deploy aws/iam-privesc
vault status aws/iam-privesc
vault outputs aws/iam-privesc --sensitive
vault destroy aws/iam-privesc

# Automate attacks
vault attack aws/ssrf-metadata
vault attack aws/lambda-secrets-exposure --verbose

# Check active deployments
vault active

# Configuration
vault setup aws
vault check
vault install terraform
```

## 🔬 Lab Workflow

### 1. Discover Labs

```bash
# Interactive
vault
> list
> search metadata

# CLI
vault list
vault search ssrf
```

### 2. Review Lab Details

```bash
# Interactive
vault
> use 1                    # or: use aws/iam-privesc
> info

# CLI
vault info aws/iam-privesc
```

### 3. Deploy Lab

```bash
# Interactive
vault
> use aws/iam-privesc
> deploy                   # Reviews plan, prompts for confirmation

# CLI
vault deploy aws/iam-privesc
```

### 4. Exploit Lab (Manual or Automated)

**Manual exploitation:**
```bash
# Get lab outputs
vault outputs aws/iam-privesc --sensitive

# Follow lab README for exploitation steps
# labs/aws/iam-privesc/README.md contains full walkthrough
```

**Automated exploitation:**
```bash
# Run automated attack chain
vault attack aws/ssrf-metadata

# With verbose logging
vault attack aws/lambda-secrets-exposure --verbose

# Save attack log
vault attack aws/lambda-secrets-exposure --log ./attack.log
```

### 5. Review Results

```bash
vault status aws/iam-privesc
vault outputs aws/iam-privesc
```

### 6. Clean Up

```bash
# Interactive
vault
> destroy aws/iam-privesc  # Requires lab name confirmation

# CLI
vault destroy aws/iam-privesc
```

## 🤖 Attack Automation

VAULT includes automated attack scripts for supported labs:

```bash
# List labs with automation support
vault list

# Run automated attack
vault attack aws/ssrf-metadata

# Verbose output with full details
vault attack aws/lambda-secrets-exposure --verbose

# Save attack log to file
vault attack aws/ssrf-metadata --log ./attacks/ssrf-$(date +%Y%m%d).log
```

## 📂 Project Structure

```
cyber-threat-emulation/
├── labs/                        # Lab terraform configurations
│   ├── aws/                     
│   ├── azure/                   
│   └── gcp/                     
├── vault/                       # VAULT application source
│   ├── attacks/                 
│   ├── cli/                     
│   ├── core/                    
│   ├── providers/               
│   └── utils/                   
├── modules/                     # Shared terraform modules
│   ├── aws/                    
│   ├── azure/                   
│   └── gcp/                     
├── config/                      # Cloud provider configurations
│   ├── common-aws.tfvars
│   ├── common-azure.tfvars
│   └── common-gcp.tfvars
├── .state/                      # Terraform state (auto-created)
│   ├── csp_lab-name/
│   │   └── terraform.tfstate
│   └── .metadata/
│       └── csp_lab-name.json
├── pyproject.toml              # Python package configuration
├── CHANGELOG.md                # Version history
└── README.md                   # This file
```

## 🔍 State Management

VAULT maintains isolated state for each lab deployment:

**State Location:** `.state/<provider>_<lab>/`

**View Active Deployments:**
```bash
vault active
```

## 🛠️ Troubleshooting

### Prerequisites Check

```bash
# Check which tools are installed
vault check

# Get installation instructions
vault install terraform
vault install aws
vault install az
vault install gcloud
```

## 🧪 Development

### Running Tests

```bash
pip install -e ".[dev]"
pytest
pytest --cov=vault --cov-report=html
```

### Code Quality

```bash
# Type checking
mypy vault

# Linting and formatting
ruff check vault
ruff format vault
```

### Creating New Labs

1. **Create lab directory structure:**
   ```bash
   mkdir -p labs/aws/my-new-lab
   cd labs/aws/my-new-lab
   touch main.tf variables.tf outputs.tf README.md
   ```

2. **Follow lab development conventions:**
   - See `instructions.md` for detailed guidelines
   - Use shared modules from `modules/` directory
   - Include difficulty rating and estimated time in README
   - Add AutoShutdown tags for cost control

3. **Validate and test:**
   ```bash
   vault validate aws/my-new-lab
   vault deploy aws/my-new-lab
   ```

### Adding New Cloud Providers

1. Create provider class in `vault/providers/`
2. Implement `BaseProvider` interface
3. Register in `ProviderFactory._providers`
4. Add configuration template

## 🤝 Contributing

Contributions are welcome! Please follow:

- Lab structure conventions from `instructions.md`
- Naming standards (lowercase, hyphens)
- Security requirements (no hardcoded credentials)
- Documentation requirements (README with objectives)
- Cost control measures (AutoShutdown tags)

## 📞 Support

- **Repository:** [GitLab](https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation)
- **Contact:** caleb.n.cline.ctr@mail.mil
- **Organization:** DG35 - Cyber Threat Emulation

## 🔖 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

**Current Version:** 1.4.1 (2025-11-04)

**Recent Updates:**
- Added lambda-secrets-exposure lab with automated attack
- Interactive configuration wizard with auto-detection
- Lab prefix support for multi-user environments
- Automated IP detection and tagging
- Enhanced tab completion

---

**⚠️ Security Notice:** All labs are designed for authorized security testing in isolated environments. Always ensure proper authorization before deploying infrastructure or conducting security testing.