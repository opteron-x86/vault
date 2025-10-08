#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LABS_DIR="$PROJECT_ROOT/labs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

function show_usage() {
    echo "Usage: labctl [command] [lab-name] [options]"
    echo ""
    echo "Deployment Commands:"
    echo "  deploy <lab>      Deploy a specific lab"
    echo "  destroy <lab>     Destroy a specific lab"
    echo "  redeploy <lab>    Destroy and redeploy a lab"
    echo ""
    echo "Planning Commands:"
    echo "  plan <lab>        Show deployment plan"
    echo "  validate <lab>    Validate terraform configuration"
    echo "  fmt <lab>         Format terraform files"
    echo ""
    echo "Information Commands:"
    echo "  list              List all available labs"
    echo "  status <lab>      Show deployment status"
    echo "  output <lab>      Show lab outputs"
    echo "  show <lab>        Show specific resources"
    echo ""
    echo "Management Commands:"
    echo "  init <lab>        Initialize terraform for a lab"
    echo "  refresh <lab>     Refresh terraform state"
    echo "  cost <lab>        Estimate hourly costs"
    echo "  ssh <lab>         SSH to lab instance"
    echo "  console <lab>     Open terraform console"
    echo ""
    echo "Options:"
    echo "  --auto-approve    Skip confirmation prompts"
    echo "  --compact         Minimal output"
    echo ""
}

function verify_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    if [ ! -d "$lab_dir" ]; then
        echo -e "${RED}Error: Lab '$lab_name' not found${NC}"
        echo "Available labs:"
        for dir in "$LABS_DIR"/*; do
            [ -d "$dir" ] && echo "  - $(basename "$dir")"
        done
        exit 1
    fi
}

function list_labs() {
    echo -e "${GREEN}Available Labs:${NC}"
    echo ""
    
    if [ ! -d "$LABS_DIR" ]; then
        echo -e "${RED}Error: Labs directory not found at $LABS_DIR${NC}"
        exit 1
    fi
    
    for lab_path in "$LABS_DIR"/*; do
        if [ -d "$lab_path" ]; then
            lab_name=$(basename "$lab_path")
            
            if [ -f "$lab_path/terraform.tfstate" ] || [ -f "$lab_path/.terraform/terraform.tfstate" ]; then
                status="${GREEN}[DEPLOYED]${NC}"
            elif [ -d "$lab_path/.terraform" ]; then
                status="${BLUE}[INITIALIZED]${NC}"
            else
                status="${YELLOW}[NOT DEPLOYED]${NC}"
            fi
            
            printf "  %-20s %s\n" "$lab_name" "$status"
        fi
    done
}

function check_prerequisites() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform not installed${NC}"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        exit 1
    fi
    
    if [ ! -f "$lab_dir/terraform.tfvars" ]; then
        if [ -f "$lab_dir/terraform.tfvars.example" ]; then
            echo "Creating terraform.tfvars from template..."
            current_ip=$(curl -s https://api.ipify.org || curl -s ifconfig.me || curl -s icanhazip.com)
            if [ -n "$current_ip" ]; then
                cp "$lab_dir/terraform.tfvars.example" "$lab_dir/terraform.tfvars"
                sed -i.bak "s/YOUR_IP_ADDRESS/$current_ip/g" "$lab_dir/terraform.tfvars"
                rm -f "$lab_dir/terraform.tfvars.bak"
                echo "Updated with your IP: $current_ip"
            else
                echo -e "${YELLOW}Warning: Could not detect IP. Update terraform.tfvars manually${NC}"
            fi
        else
            echo -e "${YELLOW}Warning: No terraform.tfvars.example found${NC}"
        fi
    fi
}

function init_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    check_prerequisites "$lab_name"
    
    echo -e "${BLUE}Initializing lab: $lab_name${NC}"
    cd "$lab_dir"
    
    terraform init
    echo -e "${GREEN}Initialization complete${NC}"
}

function plan_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    local compact=${2:-false}
    
    verify_lab "$lab_name"
    check_prerequisites "$lab_name"
    
    cd "$lab_dir"
    
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    echo -e "${BLUE}Planning lab: $lab_name${NC}"
    
    if [ "$compact" = "--compact" ]; then
        terraform plan -out=tfplan > /dev/null 2>&1
        terraform show -no-color tfplan | grep -E "^  # |will be created|will be destroyed|will be updated"
        rm -f tfplan
    else
        terraform plan
    fi
}

function validate_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    cd "$lab_dir"
    
    echo -e "${BLUE}Validating lab: $lab_name${NC}"
    
    if ! terraform validate; then
        echo -e "${RED}Validation failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Configuration is valid${NC}"
    
    # Check for common issues
    echo "Checking for common issues..."
    
    if ! grep -q "allowed_source_ips" *.tf 2>/dev/null; then
        echo -e "${YELLOW}Warning: No IP restrictions found${NC}"
    fi
    
    if ! grep -q "force_destroy.*true" *.tf 2>/dev/null; then
        echo -e "${YELLOW}Warning: S3 buckets may block terraform destroy${NC}"
    fi
    
    if ! grep -q "shutdown" *.tf 2>/dev/null; then
        echo -e "${YELLOW}Warning: No auto-shutdown mechanism detected${NC}"
    fi
}

function format_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    cd "$lab_dir"
    
    echo -e "${BLUE}Formatting terraform files for: $lab_name${NC}"
    
    if terraform fmt -check=true > /dev/null 2>&1; then
        echo "Files already formatted correctly"
    else
        terraform fmt
        echo -e "${GREEN}Files formatted${NC}"
    fi
}

function deploy_lab() {
    local lab_name=$1
    local auto_approve=$2
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    check_prerequisites "$lab_name"
    
    echo -e "${GREEN}Deploying lab: $lab_name${NC}"
    cd "$lab_dir"
    
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    echo "Planning deployment..."
    terraform plan -out=tfplan
    
    if [ "$auto_approve" = "--auto-approve" ]; then
        terraform apply tfplan
    else
        echo ""
        read -p "Deploy these resources? (yes/no): " confirmation
        if [ "$confirmation" = "yes" ]; then
            terraform apply tfplan
        else
            echo "Deployment cancelled"
            rm -f tfplan
            exit 0
        fi
    fi
    
    rm -f tfplan
    
    echo ""
    echo -e "${GREEN}Lab deployed successfully!${NC}"
    echo ""
    terraform output
}

function destroy_lab() {
    local lab_name=$1
    local auto_approve=$2
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    if [ ! -f "$lab_dir/terraform.tfstate" ] && [ ! -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        echo -e "${YELLOW}Lab '$lab_name' is not deployed${NC}"
        exit 0
    fi
    
    echo -e "${YELLOW}Destroying lab: $lab_name${NC}"
    cd "$lab_dir"
    
    if [ "$auto_approve" = "--auto-approve" ]; then
        terraform destroy -auto-approve
    else
        terraform destroy
    fi
    
    echo -e "${GREEN}Lab destroyed successfully${NC}"
}

function redeploy_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    echo -e "${BLUE}Redeploying lab: $lab_name${NC}"
    
    if [ -f "$lab_dir/terraform.tfstate" ] || [ -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        destroy_lab "$lab_name" "--auto-approve"
        sleep 2
    fi
    
    deploy_lab "$lab_name" "--auto-approve"
}

function show_status() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    echo -e "${GREEN}Status for lab: $lab_name${NC}"
    echo ""
    
    if [ -f "$lab_dir/terraform.tfstate" ] || [ -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        cd "$lab_dir"
        
        resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
        
        if [ "$resource_count" -gt 0 ]; then
            echo "Status: DEPLOYED"
            echo "Resources: $resource_count"
            echo ""
            echo "Key resources:"
            terraform state list | grep -E "(aws_instance|aws_s3_bucket|aws_iam_role)" | head -10
            echo ""
            terraform output 2>/dev/null || true
        else
            echo "Status: NOT DEPLOYED (no resources)"
        fi
    else
        echo "Status: NOT DEPLOYED"
    fi
}

function show_resources() {
    local lab_name=$1
    local resource=$2
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    cd "$lab_dir"
    
    if [ -z "$resource" ]; then
        terraform state list
    else
        terraform state show "$resource"
    fi
}

function refresh_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    cd "$lab_dir"
    
    echo -e "${BLUE}Refreshing state for: $lab_name${NC}"
    terraform refresh
    echo -e "${GREEN}State refreshed${NC}"
}

function estimate_cost() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    echo -e "${BLUE}Cost estimate for: $lab_name${NC}"
    echo ""
    
    cd "$lab_dir"
    
    # Parse for EC2 instances
    instances=$(grep -h "instance_type" *.tf 2>/dev/null | grep -oP '"t[0-9]\.[a-z]+"' | tr -d '"' || echo "")
    
    total_hourly=0
    if [ -n "$instances" ]; then
        echo "EC2 Instances:"
        for instance in $instances; do
            case $instance in
                t2.micro) cost=0.0116 ;;
                t2.small) cost=0.023 ;;
                t2.medium) cost=0.0464 ;;
                t3.micro) cost=0.0104 ;;
                t3.small) cost=0.0208 ;;
                *) cost=0.05 ;;
            esac
            echo "  $instance: \$${cost}/hour"
            total_hourly=$(echo "$total_hourly + $cost" | bc)
        done
    fi
    
    echo ""
    echo "Estimated hourly: \$${total_hourly}"
    echo "Estimated daily: \$$(echo "$total_hourly * 24" | bc)"
    echo ""
    echo "Note: S3, IAM, and VPC resources have minimal cost"
    
    # Check for auto-shutdown
    if grep -q "shutdown" *.tf 2>/dev/null; then
        echo -e "${GREEN}Auto-shutdown configured${NC}"
    else
        echo -e "${YELLOW}Warning: No auto-shutdown detected${NC}"
    fi
}

function ssh_to_lab() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    cd "$lab_dir"
    
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        echo -e "${RED}Lab not deployed${NC}"
        exit 1
    fi
    
    ssh_cmd=$(terraform output -raw ssh_connection 2>/dev/null || echo "")
    
    if [ -z "$ssh_cmd" ]; then
        echo -e "${RED}No SSH connection output found${NC}"
        exit 1
    fi
    
    echo "Connecting: $ssh_cmd"
    eval "$ssh_cmd"
}

function terraform_console() {
    local lab_name=$1
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    cd "$lab_dir"
    
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    echo "Opening terraform console (type 'exit' to quit)..."
    terraform console
}

function show_output() {
    local lab_name=$1
    local output_name=$2
    local lab_dir="$LABS_DIR/$lab_name"
    
    verify_lab "$lab_name"
    
    if [ ! -f "$lab_dir/terraform.tfstate" ] && [ ! -f "$lab_dir/.terraform/terraform.tfstate" ]; then
        echo -e "${YELLOW}Lab '$lab_name' is not deployed${NC}"
        exit 1
    fi
    
    cd "$lab_dir"
    
    if [ -z "$output_name" ]; then
        terraform output
    else
        terraform output -raw "$output_name"
    fi
}

# Main command routing
case "$1" in
    list)
        list_labs
        ;;
    init)
        init_lab "$2"
        ;;
    plan)
        plan_lab "$2" "$3"
        ;;
    validate)
        validate_lab "$2"
        ;;
    fmt|format)
        format_lab "$2"
        ;;
    deploy)
        deploy_lab "$2" "$3"
        ;;
    destroy)
        destroy_lab "$2" "$3"
        ;;
    redeploy)
        redeploy_lab "$2"
        ;;
    status)
        show_status "$2"
        ;;
    show)
        show_resources "$2" "$3"
        ;;
    refresh)
        refresh_lab "$2"
        ;;
    cost)
        estimate_cost "$2"
        ;;
    ssh)
        ssh_to_lab "$2"
        ;;
    console)
        terraform_console "$2"
        ;;
    output)
        show_output "$2" "$3"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        if [ -n "$1" ]; then
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
        fi
        show_usage
        ;;
esac