### Common Issues

**Terraform Not Found:**
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Import Errors:**
```bash
# Reinstall in development mode
pip install -e . --force-reinstall
```

**Configuration Issues:**
```bash
# Check for placeholder values
grep -r "YOUR_" config/

# Run setup wizard
vault setup aws
```

**State Corruption:**
```bash
# Backup existing state
cp -r .state .state.backup

# Remove corrupted state for specific lab
rm -rf .state/aws_problematic-lab

# Redeploy if needed
vault deploy aws/problematic-lab
```

**Lab Not Found:**
```bash
# Labs must contain main.tf
ls labs/aws/my-lab/main.tf

# Refresh lab cache by listing
vault list
```