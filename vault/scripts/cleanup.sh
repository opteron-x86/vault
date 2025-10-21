#!/bin/bash
# Emergency cleanup script - destroys all active labs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STATE_DIR="$PROJECT_ROOT/.state"
LABS_DIR="$PROJECT_ROOT/labs"
CONFIG_DIR="$PROJECT_ROOT/config"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}WARNING: This will destroy ALL active lab deployments${NC}"
read -p "Type 'DESTROY ALL' to confirm: " confirm

if [ "$confirm" != "DESTROY ALL" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

if [ ! -d "$STATE_DIR" ]; then
    echo "No active deployments found"
    exit 0
fi

for state in "$STATE_DIR"/*; do
    if [ -d "$state" ] && [ -f "$state/terraform.tfstate" ]; then
        lab_name=$(basename "$state")
        lab_dir="$LABS_DIR/$lab_name"
        
        if [ ! -d "$lab_dir" ]; then
            echo -e "${YELLOW}Warning: Lab directory not found for $lab_name, skipping${NC}"
            continue
        fi
        
        echo -e "\n${RED}Destroying: $lab_name${NC}"
        cd "$lab_dir"
        
        var_files=""
        if [ -f "$CONFIG_DIR/common.tfvars" ]; then
            var_files="-var-file=$CONFIG_DIR/common.tfvars"
        fi
        
        if [ -f "terraform.tfvars" ]; then
            var_files="$var_files -var-file=terraform.tfvars"
        elif [ -f "terraform.tfvars.example" ]; then
            var_files="$var_files -var-file=terraform.tfvars.example"
        fi
        
        terraform init -backend-config="path=$state/terraform.tfstate" -reconfigure > /dev/null
        terraform destroy $var_files -auto-approve || echo -e "${RED}Failed to destroy $lab_name${NC}"
    fi
done

echo -e "\n${GREEN}Cleanup complete${NC}"