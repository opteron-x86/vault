#!/bin/bash

# Lab orchestrator for cloud security training environments
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LABS_DIR="$PROJECT_ROOT/labs"
CONFIG_FILE="$PROJECT_ROOT/config/labs.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Terraform workspace isolation
export TF_DATA_DIR=".terraform"
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

function show_usage() {
    echo "Usage: labctl [command] [lab-name] [options]"
    echo ""
    echo "Commands:"
    echo "  list              List all available labs"
    echo "  info <lab>        Show lab details and requirements"
    echo "  deploy <lab>      Deploy a specific lab"
    echo "  destroy <lab>     Destroy a specific lab"
    echo "  status <lab>      Show deployment status"
    echo "  output <lab>      Show lab outputs (URLs, credentials, etc.)"
    echo "  validate <lab>    Validate terraform configuration"
    echo "  cost <lab>        Estimate lab costs"
    echo "  cleanup-all       Destroy all deployed labs"
    echo ""
    echo "Options:"
    echo "  --auto-approve    Skip confirmation prompts"
    echo "  --var-file FILE   Specify terraform variables file"
    echo "  --dry-run         Show what would be executed"
    echo ""
    echo "Examples:"
    echo "  labctl deploy ssrf-metadata"
    echo "  labctl destroy ssrf-metadata --auto-approve"
    echo "  labctl list"
}

function list_labs() {
    echo -e "${GREEN}Available Labs:${NC}"
    echo ""
    for lab_dir in "$LABS_DIR"/*; do
        if [ -d "$lab_dir" ]; then
            lab_name=$(basename "$lab_dir")
            if [ -f "$lab_dir/README.md" ]; then
                # Extract difficulty and description from README
                difficulty=$(grep -m1 "^## Difficulty" "$lab_dir/README.md" 2>/dev/null | sed 's/.*: //' || echo "Unknown")
                description=$(grep -m1 "^## Scenario" "$lab_dir/README.md" 2>/dev/null | sed 's/.*: //' || echo "No description")
                
                # Check deployment status
                if [ -f "$lab_dir/.terraform/terraform.tfstate" ]; then
                    status="${GREEN}[DEPLOYED]${NC}"
                else
                    status="${YELLOW}[NOT DEPLOYED]${NC}"
                fi
                
                printf "  %-20s %s %s\n" "$lab_name" "$status" "($difficulty)"
                printf "  %-20s %s\n" "" "$description"
                echo ""
            fi
        fi
    done
}

function check_prerequisites() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    echo "Checking prerequisites..."
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform not installed${NC}"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        exit 1
    fi
    
    # Check for tfvars
    if [ ! -f "$lab_dir/terraform.tfvars" ]; then
        if [ -f "$lab_dir/terraform.tfvars.example" ]; then
            echo -e "${YELLOW}Warning: terraform.tfvars not found${NC}"
            echo "Creating from template..."
            
            # Get current IP
            current_ip=$(curl -s https://api.ipify.org || echo "")
            if [ -n "$current_ip" ]; then
                cp "$lab_dir/terraform.tfvars.example" "$lab_dir/terraform.tfvars"
                sed -i.bak "s/YOUR_IP_ADDRESS/$current_ip/g" "$lab_dir/terraform.tfvars"
                rm "$lab_dir/terraform.tfvars.bak"
                echo "Updated terraform.tfvars with your IP: $current_ip"
            else
                echo -e "${RED}Could not detect your IP. Please update terraform.tfvars manually${NC}"
                exit 1
            fi
        fi
    fi
    
    echo -e "${GREEN}Prerequisites check passed${NC}"
}

function deploy_lab() {
    local lab_name=$1
    local auto_approve=$2
    local lab_dir="$LABS_DIR/$lab_name"
    
    if [ ! -d "$lab_dir" ]; then
        echo -e "${RED}Error: Lab '$lab_name' not found${NC}"
        exit 1
    fi
    
    check_prerequisites "$lab_name"
    
    echo -e "${GREEN}Deploying lab: $lab_name${NC}"
    cd "$lab_dir"
    
    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    # Plan
    echo "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply
    if [ "$auto_approve" == "--auto-approve" ]; then
        terraform apply tfplan
    else
        echo ""
        echo -e "${YELLOW}Review the plan above. Deploy? (yes/no):${NC}"
        read -r confirmation
        if [ "$confirmation" == "yes" ]; then
            terraform apply tfplan
        else
            echo "Deployment cancelled"
            rm tfplan
            exit 0
        fi
    fi
    
    rm -f tfplan
    
    # Show outputs
    echo ""
    echo -e "${GREEN}Lab deployed successfully!${NC}"
    echo ""
    echo "Lab Access Information:"
    terraform output
    
    # Save deployment metadata
    mkdir -p "$lab_dir/.lab-metadata"
    echo "$(date +%s)" > "$lab_dir/.lab-metadata/deployed_at"
    echo "$(date +%Y-%m-%d\ %H:%M:%S)" > "$lab_dir/.lab-metadata/deployed_at_human"
}

function destroy_lab() {
    local lab_name=$1
    local auto_approve=$2
    local lab_dir="$LABS_DIR/$lab_name"
    
    if [ ! -d "$lab_dir" ]; then
        echo -e "${RED}Error: Lab '$lab_name' not found${NC}"
        exit 1
    fi
    
    if [ ! -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        echo -e "${YELLOW}Lab '$lab_name' is not deployed${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Destroying lab: $lab_name${NC}"
    cd "$lab_dir"
    
    if [ "$auto_approve" == "--auto-approve" ]; then
        terraform destroy -auto-approve
    else
        terraform destroy
    fi
    
    # Clean metadata
    rm -rf "$lab_dir/.lab-metadata"
    
    echo -e "${GREEN}Lab destroyed successfully${NC}"
}

function show_status() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    if [ ! -d "$lab_dir" ]; then
        echo -e "${RED}Error: Lab '$lab_name' not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Status for lab: $lab_name${NC}"
    echo ""
    
    if [ -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        cd "$lab_dir"
        
        # Check if resources exist
        resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
        
        if [ "$resource_count" -gt 0 ]; then
            echo "Status: DEPLOYED"
            echo "Resources: $resource_count"
            
            if [ -f "$lab_dir/.lab-metadata/deployed_at_human" ]; then
                deployed_at=$(cat "$lab_dir/.lab-metadata/deployed_at_human")
                echo "Deployed: $deployed_at"
                
                # Calculate uptime
                if [ -f "$lab_dir/.lab-metadata/deployed_at" ]; then
                    deployed_timestamp=$(cat "$lab_dir/.lab-metadata/deployed_at")
                    current_timestamp=$(date +%s)
                    uptime_seconds=$((current_timestamp - deployed_timestamp))
                    uptime_hours=$((uptime_seconds / 3600))
                    uptime_minutes=$(((uptime_seconds % 3600) / 60))
                    echo "Uptime: ${uptime_hours}h ${uptime_minutes}m"
                    
                    # Cost estimate
                    hourly_cost="0.05"  # Rough estimate
                    total_cost=$(echo "scale=2; $uptime_hours * $hourly_cost" | bc)
                    echo "Estimated cost: \$$total_cost"
                fi
            fi
            
            echo ""
            echo "Key resources:"
            terraform state list | grep -E "(aws_instance|aws_s3_bucket|aws_iam_role)" | head -10
        else
            echo "Status: NOT DEPLOYED"
        fi
    else
        echo "Status: NOT INITIALIZED"
    fi
}

function show_output() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    if [ ! -d "$lab_dir" ]; then
        echo -e "${RED}Error: Lab '$lab_name' not found${NC}"
        exit 1
    fi
    
    if [ ! -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        echo -e "${YELLOW}Lab '$lab_name' is not deployed${NC}"
        exit 1
    fi
    
    cd "$lab_dir"
    terraform output
}

function estimate_cost() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    if [ ! -d "$lab_dir" ]; then
        echo -e "${RED}Error: Lab '$lab_name' not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Cost Estimate for lab: $lab_name${NC}"
    echo ""
    
    # Parse terraform files for instance types and resources
    cd "$lab_dir"
    
    # Basic cost estimation
    instances=$(grep -h "instance_type" *.tf 2>/dev/null | grep -oP 't[0-9]\.[a-z]+' || echo "")
    
    if [ -n "$instances" ]; then
        echo "EC2 Instances detected:"
        for instance in $instances; do
            case $instance in
                t2.micro) cost="0.0116" ;;
                t2.small) cost="0.023" ;;
                t2.medium) cost="0.0464" ;;
                t3.micro) cost="0.0104" ;;
                *) cost="0.05" ;;
            esac
            echo "  - $instance: ~\$$cost/hour"
        done
    fi
    
    echo ""
    echo "Additional resources: S3, IAM, VPC (minimal cost)"
    echo "Estimated total: <\$0.10/hour for typical lab"
    echo ""
    echo "Note: Labs auto-shutdown after 4 hours"
}

function cleanup_all() {
    echo -e "${YELLOW}WARNING: This will destroy ALL deployed labs${NC}"
    echo "Type 'destroy-all-labs' to confirm:"
    read -r confirmation
    
    if [ "$confirmation" != "destroy-all-labs" ]; then
        echo "Cancelled"
        exit 0
    fi
    
    for lab_dir in "$LABS_DIR"/*; do
        if [ -d "$lab_dir" ] && [ -f "$lab_dir/.terraform/terraform.tfstate" ]; then
            lab_name=$(basename "$lab_dir")
            echo ""
            echo "Destroying $lab_name..."
            destroy_lab "$lab_name" "--auto-approve"
        fi
    done
    
    echo -e "${GREEN}All labs destroyed${NC}"
}

# Main command routing
case "$1" in
    list)
        list_labs
        ;;
    deploy)
        deploy_lab "$2" "$3"
        ;;
    destroy)
        destroy_lab "$2" "$3"
        ;;
    status)
        show_status "$2"
        ;;
    output)
        show_output "$2"
        ;;
    info)
        if [ -f "$LABS_DIR/$2/README.md" ]; then
            cat "$LABS_DIR/$2/README.md"
        else
            echo -e "${RED}Lab '$2' not found${NC}"
        fi
        ;;
    validate)
        cd "$LABS_DIR/$2" && terraform validate
        ;;
    cost)
        estimate_cost "$2"
        ;;
    cleanup-all)
        cleanup_all
        ;;
    *)
        show_usage
        ;;
esac