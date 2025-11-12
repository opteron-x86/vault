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
- **Cost Controls** - Auto-shutdown tags and resource limits to prevent cost overruns

## 📚 Documentation

- 📖 **[Full Documentation](https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation/-/wikis/home)** - Complete guides and tutorials
- 🔍 **[Lab Catalog](https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation/-/wikis/Lab-Catalog)** - Browse all available labs
- 🛠️ **[Troubleshooting](https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation/-/wikis/Troubleshooting)** - Common issues and solutions
- 🤝 **[Contributing](CONTRIBUTING.md)** - Development guidelines and lab creation

## 📋 Prerequisites

- **Python** 3.12 or higher
- **Terraform** 1.0 or higher
- **Cloud CLI Tools** - AWS CLI, Azure CLI, or gcloud SDK
- **Valid Cloud Credentials** - Configured for your target provider(s)

## 🔧 Quick Start

### Installation

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

### Configuration

Run the interactive setup wizard to configure cloud providers:

```bash
vault setup
```

Or manually create configuration files in `config/`:
- `common-aws.tfvars` - AWS settings
- `common-azure.tfvars` - Azure settings  
- `common-gcp.tfvars` - GCP settings

### Deploy Your First Lab

**Interactive Mode:**
```bash
vault
> list                     # Browse available labs
> search ssrf              # Search for specific labs
> use aws/ssrf-metadata    # Select a lab
> info                     # Review lab details
> deploy                   # Deploy the lab
> outputs                  # Get connection details
> destroy                  # Clean up when done
```

**CLI Mode:**
```bash
vault list
vault deploy aws/ssrf-metadata
vault outputs aws/ssrf-metadata
vault destroy aws/ssrf-metadata
```

## 🎯 Common Commands

| Command | Description |
|---------|-------------|
| `list [query]` | List all labs, optionally filter by query |
| `use <lab>` | Select lab by path or number |
| `info [lab]` | Display lab details and README |
| `deploy [lab]` | Deploy selected or specified lab |
| `destroy [lab]` | Destroy deployed lab |
| `status [lab]` | Show deployment status and resources |
| `outputs [lab]` | Display lab outputs (use `--sensitive` for all values) |
| `active` | List all active deployments |
| `search <query>` | Fuzzy search across lab names and descriptions |
| `attack [lab]` | Execute automated attack chain against lab |
| `validate [lab]` | Validate Terraform configuration |

## 🧪 Creating New Labs

To create a new lab, see [instructions.md](instructions.md) for detailed guidelines.

**Quick start:**
```bash
mkdir -p labs/aws/my-new-lab && cd labs/aws/my-new-lab
touch main.tf variables.tf outputs.tf README.md
# Follow lab structure conventions from instructions.md
vault validate aws/my-new-lab
vault deploy aws/my-new-lab
```

## 📦 State Management

VAULT maintains deployment state in `.state/`:
- `.state/<csp>_<lab>/terraform.tfstate` - Terraform state files
- `.state/.metadata/<csp>_<lab>.json` - Deployment metadata (timestamps, resources, user)

Each lab deployment is isolated with its own state to prevent conflicts.

## 📞 Support

- **Repository:** [GitLab](https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation)
- **Documentation:** [Wiki](https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation/-/wikis/home)
- **Contact:** caleb.n.cline.ctr@mail.mil
- **Organization:** DG35 - Cyber Threat Emulation

## 📖 Version History

**Current Version:** 1.4.1 (2025-11-04)

See [CHANGELOG.md](CHANGELOG.md) for full version history.

---

**⚠️ Security Notice:** All labs are designed for authorized security testing in isolated environments. Always ensure proper authorization before deploying infrastructure or conducting security testing.