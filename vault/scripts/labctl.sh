#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LABS_DIR="$PROJECT_ROOT/labs"
STATE_DIR="$PROJECT_ROOT/.state"
CONFIG_DIR="$PROJECT_ROOT/config"

COMMON_VARS="$CONFIG_DIR/common.tfvars"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Cyber Threat Emulation Lab Manager${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

list_labs() {
    echo -e "${GREEN}Available Labs:${NC}\n"
    local index=1
    for lab in "$LABS_DIR"/*; do
        if [ -d "$lab" ]; then
            local lab_name=$(basename "$lab")
            local readme="$lab/README.md"
            local difficulty="Unknown"
            
            if [ -f "$readme" ]; then
                difficulty=$(grep -i "Difficulty:" "$readme" | head -1 | cut -d: -f2 | xargs || echo "Unknown")
            fi
            
            echo -e "  ${YELLOW}[$index]${NC} $lab_name ${BLUE}($difficulty)${NC}"
            ((index++))
        fi
    done
    echo ""
}

select_lab() {
    local labs=()
    for lab in "$LABS_DIR"/*; do
        if [ -d "$lab" ]; then
            labs+=("$(basename "$lab")")
        fi
    done

    if [ ${#labs[@]} -eq 0 ]; then
        echo -e "${RED}Error: No labs found in $LABS_DIR${NC}"
        exit 1
    fi

    read -p "Select lab number (or 'q' to quit): " selection

    if [[ "$selection" == "q" ]]; then
        echo "Exiting..."
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#labs[@]} ]; then
        echo -e "${RED}Invalid selection${NC}"
        exit 1
    fi

    echo "${labs[$((selection-1))]}"
}

check_prerequisites() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"

    if [ ! -f "$COMMON_VARS" ]; then
        echo -e "${YELLOW}Warning: Common variables file not found at $COMMON_VARS${NC}"
        echo "Creating template..."
        mkdir -p "$CONFIG_DIR"
        cat > "$COMMON_VARS" << 'EOF'
aws_region = "us-gov-east-1"
allowed_source_ips = ["YOUR_IP/32"]
EOF
        echo -e "${RED}Please edit $COMMON_VARS with your IP address before continuing${NC}"
        exit 1
    fi

    local ip_check=$(grep "YOUR_IP" "$COMMON_VARS" || true)
    if [ -n "$ip_check" ]; then
        echo -e "${RED}Error: Please update YOUR_IP in $COMMON_VARS${NC}"
        exit 1
    fi

    if [ ! -f "$lab_dir/terraform.tfvars.example" ] && [ ! -f "$lab_dir/terraform.tfvars" ]; then
        echo -e "${YELLOW}No terraform.tfvars found. Proceeding with common variables only.${NC}"
    fi
}

init_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"

    echo -e "\n${GREEN}Initializing lab: $lab${NC}\n"

    mkdir -p "$state_path"

    cd "$lab_dir"

    terraform init \
        -backend-config="path=$state_path/terraform.tfstate" \
        -reconfigure

    echo -e "\n${GREEN}Lab initialized successfully${NC}"
}

plan_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"

    cd "$lab_dir"

    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        echo -e "${YELLOW}Note: Using terraform.tfvars.example. Consider copying to terraform.tfvars for customization.${NC}"
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi

    echo -e "\n${GREEN}Planning deployment...${NC}\n"
    terraform plan $var_files
}

apply_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"

    cd "$lab_dir"

    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi

    echo -e "\n${GREEN}Deploying lab: $lab${NC}\n"
    terraform apply $var_files -auto-approve

    echo -e "\n${GREEN}Lab deployed successfully!${NC}\n"
    echo -e "${BLUE}Lab Outputs:${NC}"
    terraform output
}

destroy_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"

    if [ ! -d "$state_path" ] || [ ! -f "$state_path/terraform.tfstate" ]; then
        echo -e "${YELLOW}No active deployment found for lab: $lab${NC}"
        exit 0
    fi

    cd "$lab_dir"

    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi

    echo -e "\n${RED}Destroying lab: $lab${NC}\n"
    read -p "Are you sure you want to destroy this lab? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "Destruction cancelled"
        exit 0
    fi

    terraform destroy $var_files -auto-approve

    echo -e "\n${GREEN}Lab destroyed successfully${NC}"
}

show_outputs() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"

    if [ ! -f "$state_path/terraform.tfstate" ]; then
        echo -e "${RED}No state file found. Lab may not be deployed.${NC}"
        exit 1
    fi

    cd "$lab_dir"
    echo -e "\n${BLUE}Current Lab Outputs:${NC}\n"
    terraform output
}

list_active() {
    echo -e "\n${GREEN}Active Deployments:${NC}\n"
    if [ ! -d "$STATE_DIR" ]; then
        echo "None"
        return
    fi

    for state in "$STATE_DIR"/*; do
        if [ -d "$state" ] && [ -f "$state/terraform.tfstate" ]; then
            local lab_name=$(basename "$state")
            local resources=$(grep -o '"resources":' "$state/terraform.tfstate" | wc -l || echo "0")
            echo -e "  ${YELLOW}•${NC} $lab_name ${BLUE}($resources resources)${NC}"
        fi
    done
    echo ""
}

usage() {
    cat << EOF
Usage: $0 <command> [lab-name]

Commands:
    deploy      Deploy a lab (interactive if no lab specified)
    destroy     Destroy a deployed lab
    plan        Show deployment plan
    outputs     Show outputs for deployed lab
    list        List all available labs
    active      List active deployments
    help        Show this help message

Examples:
    $0 deploy
    $0 deploy ssrf-metadata
    $0 destroy iam-privesc
    $0 outputs ssrf-metadata
    $0 list
    $0 active
EOF
}

main() {
    print_header

    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi

    local command=$1
    local lab_name=${2:-""}

    case $command in
        deploy)
            if [ -z "$lab_name" ]; then
                list_labs
                lab_name=$(select_lab)
            fi
            check_prerequisites "$lab_name"
            init_lab "$lab_name"
            plan_lab "$lab_name"
            read -p "Proceed with deployment? (yes/no): " proceed
            if [ "$proceed" == "yes" ]; then
                apply_lab "$lab_name"
            fi
            ;;
        destroy)
            if [ -z "$lab_name" ]; then
                list_active
                read -p "Enter lab name to destroy: " lab_name
            fi
            destroy_lab "$lab_name"
            ;;
        plan)
            if [ -z "$lab_name" ]; then
                list_labs
                lab_name=$(select_lab)
            fi
            check_prerequisites "$lab_name"
            init_lab "$lab_name"
            plan_lab "$lab_name"
            ;;
        outputs)
            if [ -z "$lab_name" ]; then
                list_active
                read -p "Enter lab name: " lab_name
            fi
            show_outputs "$lab_name"
            ;;
        list)
            list_labs
            ;;
        active)
            list_active
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}\n"
            usage
            exit 1
            ;;
    esac
}

main "$@"