#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LABS_DIR="$PROJECT_ROOT/labs"
STATE_DIR="$PROJECT_ROOT/.state"
CONFIG_DIR="$PROJECT_ROOT/config"
METADATA_DIR="$STATE_DIR/.metadata"

COMMON_VARS="$CONFIG_DIR/common.tfvars"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CONTACT_EMAIL="your.email@disa.mil"
GITLAB_REPO="https://gitlab.your-domain.mil/cte/cloud-security-labs"

print_banner() {
    cat << 'EOF'
   ██████╗██████╗ ██╗   ██╗ ██████╗██╗██████╗ ██╗     ███████╗
  ██╔════╝██╔══██╗██║   ██║██╔════╝██║██╔══██╗██║     ██╔════╝
  ██║     ██████╔╝██║   ██║██║     ██║██████╔╝██║     █████╗  
  ██║     ██╔══██╗██║   ██║██║     ██║██╔══██╗██║     ██╔══╝  
  ╚██████╗██║  ██║╚██████╔╝╚██████╗██║██████╔╝███████╗███████╗
   ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝╚═════╝ ╚══════╝╚══════╝
EOF
    echo -e "${DIM}  ═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}         Cyber Threat Emulation Lab Framework${NC}"
    echo -e "${DIM}  ───────────────────────────────────────────────────────────${NC}"
    echo -e "${DIM}  Organization: ${NC}${BOLD}DISA Global - Cyber Threat Emulation${NC}"
    echo -e "${DIM}  Contact:      ${NC}${CONTACT_EMAIL}"
    echo -e "${DIM}  Repository:   ${NC}${GITLAB_REPO}"
    echo -e "${DIM}  ═══════════════════════════════════════════════════════════${NC}\n"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

save_metadata() {
    local lab=$1
    local action=$2
    local metadata_file="$METADATA_DIR/$lab.json"
    
    mkdir -p "$METADATA_DIR"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user=$(whoami)
    
    cat > "$metadata_file" << EOF
{
  "lab_name": "$lab",
  "last_action": "$action",
  "timestamp": "$timestamp",
  "deployed_by": "$user",
  "aws_region": "$(grep aws_region $COMMON_VARS | cut -d'=' -f2 | tr -d ' "')"
}
EOF
}

load_metadata() {
    local lab=$1
    local metadata_file="$METADATA_DIR/$lab.json"
    
    if [ -f "$metadata_file" ]; then
        cat "$metadata_file"
    else
        echo "{}"
    fi
}

list_labs() {
    echo -e "${BOLD}${GREEN}Available Labs:${NC}\n"
    local index=1
    for lab in "$LABS_DIR"/*; do
        if [ -d "$lab" ]; then
            local lab_name=$(basename "$lab")
            local readme="$lab/README.md"
            local difficulty="Unknown"
            local description=""
            
            if [ -f "$readme" ]; then
                difficulty=$(grep -i "Difficulty:" "$readme" | head -1 | cut -d: -f2 | xargs || echo "Unknown")
                description=$(grep -i "Description:" "$readme" | head -1 | cut -d: -f2- | xargs || echo "")
            fi
            
            local deployed=""
            if [ -f "$STATE_DIR/$lab_name/terraform.tfstate" ]; then
                deployed="${GREEN}[DEPLOYED]${NC} "
            fi
            
            echo -e "  ${YELLOW}[$index]${NC} ${BOLD}$lab_name${NC} ${deployed}${CYAN}($difficulty)${NC}"
            if [ -n "$description" ]; then
                echo -e "      ${DIM}$description${NC}"
            fi
            echo ""
            ((index++))
        fi
    done
}

select_lab() {
    local labs=()
    for lab in "$LABS_DIR"/*; do
        if [ -d "$lab" ]; then
            labs+=("$(basename "$lab")")
        fi
    done

    if [ ${#labs[@]} -eq 0 ]; then
        log_error "No labs found in $LABS_DIR"
        exit 1
    fi

    read -p "$(echo -e ${CYAN}Select lab number or name${NC} [q to quit]: )" selection

    if [[ "$selection" == "q" ]]; then
        echo "Exiting..."
        exit 0
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        if [ "$selection" -lt 1 ] || [ "$selection" -gt ${#labs[@]} ]; then
            log_error "Invalid selection"
            exit 1
        fi
        echo "${labs[$((selection-1))]}"
    else
        if [[ " ${labs[@]} " =~ " ${selection} " ]]; then
            echo "$selection"
        else
            log_error "Lab not found: $selection"
            exit 1
        fi
    fi
}

check_prerequisites() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"

    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install Terraform."
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI not found. Some features may not work."
    fi

    if [ ! -f "$COMMON_VARS" ]; then
        log_warning "Common variables file not found at $COMMON_VARS"
        log_info "Creating template..."
        mkdir -p "$CONFIG_DIR"
        cat > "$COMMON_VARS" << 'EOF'
aws_region = "us-gov-east-1"
allowed_source_ips = ["YOUR_IP/32"]
EOF
        log_error "Please edit $COMMON_VARS with your IP address before continuing"
        exit 1
    fi

    local ip_check=$(grep "YOUR_IP" "$COMMON_VARS" || true)
    if [ -n "$ip_check" ]; then
        log_error "Please update YOUR_IP in $COMMON_VARS"
        exit 1
    fi

    if [ ! -d "$lab_dir" ]; then
        log_error "Lab directory not found: $lab_dir"
        exit 1
    fi
}

init_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"

    log_info "Initializing lab: ${BOLD}$lab${NC}"

    mkdir -p "$state_path"
    cd "$lab_dir"

    terraform init \
        -backend-config="path=$state_path/terraform.tfstate" \
        -reconfigure > /dev/null 2>&1

    log_success "Lab initialized"
}

plan_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"

    cd "$lab_dir"

    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        log_warning "Using terraform.tfvars.example. Consider creating terraform.tfvars"
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi

    echo -e "\n${BOLD}${CYAN}Deployment Plan:${NC}\n"
    terraform plan $var_files
}

apply_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local dry_run=${2:-false}

    cd "$lab_dir"

    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi

    if [ "$dry_run" = true ]; then
        log_info "Dry run mode - showing plan only"
        terraform plan $var_files
        return
    fi

    log_info "Deploying lab: ${BOLD}$lab${NC}"
    echo -e "${DIM}This may take several minutes...${NC}\n"
    
    terraform apply $var_files -auto-approve

    save_metadata "$lab" "deployed"
    
    log_success "Lab deployed successfully"
    echo -e "\n${BOLD}${CYAN}Lab Access Information:${NC}"
    terraform output
    
    echo -e "\n${YELLOW}Note:${NC} Instance will auto-shutdown in 4 hours"
}

destroy_lab() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"
    local force=${2:-false}

    if [ ! -d "$state_path" ] || [ ! -f "$state_path/terraform.tfstate" ]; then
        log_warning "No active deployment found for lab: $lab"
        exit 0
    fi

    cd "$lab_dir"

    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi

    if [ "$force" = false ]; then
        echo -e "\n${RED}${BOLD}WARNING:${NC} ${RED}This will destroy all resources for lab: $lab${NC}\n"
        read -p "$(echo -e ${YELLOW}Type lab name to confirm:${NC} )" confirm

        if [ "$confirm" != "$lab" ]; then
            log_info "Destruction cancelled"
            exit 0
        fi
    fi

    log_info "Destroying lab: ${BOLD}$lab${NC}"
    terraform destroy $var_files -auto-approve

    save_metadata "$lab" "destroyed"
    log_success "Lab destroyed successfully"
}

show_outputs() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"
    local show_sensitive=${2:-false}

    if [ ! -f "$state_path/terraform.tfstate" ]; then
        log_error "No state file found. Lab may not be deployed."
        exit 1
    fi

    cd "$lab_dir"
    
    echo -e "\n${BOLD}${CYAN}Lab Outputs: ${NC}${BOLD}$lab${NC}\n"
    
    if [ "$show_sensitive" = true ]; then
        log_warning "Showing sensitive values"
        terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"'
    else
        terraform output
        echo -e "\n${DIM}Use --sensitive flag to reveal sensitive outputs${NC}"
    fi
}

show_status() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"

    echo -e "\n${BOLD}${CYAN}Lab Status: ${NC}${BOLD}$lab${NC}\n"

    if [ ! -f "$state_path/terraform.tfstate" ]; then
        echo -e "${YELLOW}Status:${NC} Not deployed"
        return
    fi

    cd "$lab_dir"

    local resources=$(terraform state list 2>/dev/null | wc -l || echo "0")
    local metadata=$(load_metadata "$lab")
    
    echo -e "${GREEN}Status:${NC} Deployed"
    echo -e "${CYAN}Resources:${NC} $resources"
    
    if [ "$metadata" != "{}" ]; then
        echo -e "${CYAN}Deployed by:${NC} $(echo $metadata | jq -r '.deployed_by')"
        echo -e "${CYAN}Deployed at:${NC} $(echo $metadata | jq -r '.timestamp')"
        echo -e "${CYAN}Region:${NC} $(echo $metadata | jq -r '.aws_region')"
    fi
    
    echo -e "\n${BOLD}Key Resources:${NC}"
    terraform state list 2>/dev/null | grep -E "(instance|bucket|role)" | sed 's/^/  • /'
}

list_active() {
    echo -e "\n${BOLD}${GREEN}Active Deployments:${NC}\n"
    
    if [ ! -d "$STATE_DIR" ]; then
        echo -e "${DIM}None${NC}"
        return
    fi

    local found=0
    for state in "$STATE_DIR"/*; do
        if [ -d "$state" ] && [ -f "$state/terraform.tfstate" ]; then
            local lab_name=$(basename "$state")
            local metadata=$(load_metadata "$lab_name")
            local resources=$(grep -o '"resources":' "$state/terraform.tfstate" | wc -l || echo "0")
            local deployed_at=$(echo $metadata | jq -r '.timestamp' 2>/dev/null || echo "Unknown")
            
            echo -e "  ${YELLOW}•${NC} ${BOLD}$lab_name${NC}"
            echo -e "    ${DIM}Resources: $resources | Deployed: $deployed_at${NC}"
            found=1
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo -e "${DIM}None${NC}"
    fi
    echo ""
}

destroy_all() {
    log_warning "This will destroy ALL deployed labs"
    read -p "$(echo -e ${RED}Type 'destroy all labs' to confirm:${NC} )" confirm

    if [ "$confirm" != "destroy all labs" ]; then
        log_info "Cancelled"
        exit 0
    fi

    for state in "$STATE_DIR"/*; do
        if [ -d "$state" ] && [ -f "$state/terraform.tfstate" ]; then
            local lab_name=$(basename "$state")
            log_info "Destroying $lab_name..."
            destroy_lab "$lab_name" true
        fi
    done

    log_success "All labs destroyed"
}

usage() {
    echo -e "${BOLD}Usage:${NC} $0 <command> [options] [lab-name]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}deploy${NC}      Deploy a lab (interactive if no lab specified)"
    echo -e "              Options: --dry-run (plan only)"
    echo -e "  ${RED}destroy${NC}     Destroy a deployed lab"
    echo -e "              Options: --all (destroy all labs)"
    echo -e "  ${CYAN}plan${NC}        Show deployment plan without applying"
    echo -e "  ${BLUE}outputs${NC}     Show outputs for deployed lab"
    echo -e "              Options: --sensitive (show sensitive values)"
    echo -e "  ${MAGENTA}status${NC}      Show detailed status of a lab"
    echo -e "  ${YELLOW}list${NC}        List all available labs"
    echo -e "  ${YELLOW}active${NC}      List active deployments"
    echo -e "  ${GREEN}help${NC}        Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 deploy"
    echo "  $0 deploy ssrf-metadata"
    echo "  $0 deploy --dry-run iam-privesc"
    echo "  $0 destroy iam-privesc"
    echo "  $0 destroy --all"
    echo "  $0 outputs ssrf-metadata"
    echo "  $0 outputs --sensitive ssrf-metadata"
    echo "  $0 status ssrf-metadata"
    echo "  $0 list"
    echo "  $0 active"
    echo ""
    echo -e "${BOLD}Global Options:${NC}"
    echo "  --help, -h    Show this help message"
    echo "  --version     Show version information"
}

main() {
    print_banner

    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi

    local command=$1
    shift

    local lab_name=""
    local sensitive=false
    local dry_run=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --sensitive)
                sensitive=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --all)
                force=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                lab_name=$1
                shift
                ;;
        esac
    done

    case $command in
        deploy)
            if [ -z "$lab_name" ]; then
                list_labs
                lab_name=$(select_lab)
            fi
            check_prerequisites "$lab_name"
            init_lab "$lab_name"
            plan_lab "$lab_name"
            
            if [ "$dry_run" = false ]; then
                echo ""
                read -p "$(echo -e ${GREEN}Proceed with deployment?${NC} [yes/no]: )" proceed
                if [ "$proceed" == "yes" ]; then
                    apply_lab "$lab_name"
                else
                    log_info "Deployment cancelled"
                fi
            fi
            ;;
        destroy)
            if [ "$force" = true ]; then
                destroy_all
            else
                if [ -z "$lab_name" ]; then
                    list_active
                    read -p "$(echo -e ${RED}Enter lab name to destroy:${NC} )" lab_name
                fi
                destroy_lab "$lab_name"
            fi
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
                read -p "$(echo -e ${CYAN}Enter lab name:${NC} )" lab_name
            fi
            show_outputs "$lab_name" "$sensitive"
            ;;
        status)
            if [ -z "$lab_name" ]; then
                list_active
                read -p "$(echo -e ${CYAN}Enter lab name:${NC} )" lab_name
            fi
            show_status "$lab_name"
            ;;
        list)
            list_labs
            ;;
        active)
            list_active
            ;;
        --version)
            echo "CRUCIBLE Lab Framework v1.0.0"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"