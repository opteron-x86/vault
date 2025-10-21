#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS_DIR="$PROJECT_ROOT/labs"
STATE_DIR="$PROJECT_ROOT/.state"
CONFIG_DIR="$PROJECT_ROOT/config"
METADATA_DIR="$STATE_DIR/.metadata"
HISTORY_FILE="$STATE_DIR/.vault_history"

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

CONTACT_EMAIL="caleb.n.cline.ctr@mail.mil"
GITLAB_REPO="https://web.git.mil/USG/DOD/DISA/cyber-executive/disa-cssp/disa-cols-na/cyber-threat-emulation"

CURRENT_LAB=""
INTERACTIVE_MODE=true

print_banner() {
    clear
    cat << 'EOF'
  ██╗   ██╗ █████╗ ██╗   ██╗██╗  ████████╗    ██████╗ ███████╗
  ██║   ██║██╔══██╗██║   ██║██║  ╚══██╔══╝    ╚════██╗██╔════╝
  ██║   ██║███████║██║   ██║██║     ██║        █████╔╝███████╗
  ╚██╗ ██╔╝██╔══██║██║   ██║██║     ██║        ╚═══██╗╚════██║
   ╚████╔╝ ██║  ██║╚██████╔╝███████╗██║       ██████╔╝███████║
    ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝       ╚═════╝ ╚══════╝
EOF
    echo -e "${DIM}  ═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}    Vulnerability Analysis Universal Lab Terminal${NC}"
    echo -e "${DIM}  ───────────────────────────────────────────────────────${NC}"
    echo -e "${DIM}  Organization: ${NC}${BOLD}DG35 - Cyber Threat Emulation${NC}"
    echo -e "${DIM}  Contact:      ${NC}${CONTACT_EMAIL}"
    echo -e "${DIM}  Repository:   ${NC}${GITLAB_REPO}"
    echo -e "${DIM}  ═══════════════════════════════════════════════════════${NC}\n"
    echo -e "${DIM}  Type ${NC}${BOLD}help${NC}${DIM} for commands or ${NC}${BOLD}exit${NC}${DIM} to quit${NC}\n"
}

get_prompt() {
    if [ -n "$CURRENT_LAB" ]; then
        echo -e "${RED}vault${NC}${DIM}(${NC}${YELLOW}$CURRENT_LAB${NC}${DIM})${NC} ${BOLD}>${NC} "
    else
        echo -e "${RED}vault${NC} ${BOLD}>${NC} "
    fi
}

log_info() {
    echo -e "${BLUE}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[-]${NC} $1"
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
  "aws_region": "$(grep aws_region $COMMON_VARS 2>/dev/null | cut -d'=' -f2 | tr -d ' "' || echo 'unknown')"
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

check_prerequisites() {
    local lab=$1
    local lab_dir="$LABS_DIR/$lab"

    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install Terraform."
        return 1
    fi

    if [ ! -f "$COMMON_VARS" ]; then
        log_warning "Common variables file not found at $COMMON_VARS"
        log_info "Creating template..."
        mkdir -p "$CONFIG_DIR"
        cat > "$COMMON_VARS" << 'VAREOF'
aws_region = "us-gov-east-1"
allowed_source_ips = ["YOUR_IP/32"]
VAREOF
        log_error "Please edit $COMMON_VARS with your IP address before continuing"
        return 1
    fi

    local ip_check=$(grep "YOUR_IP" "$COMMON_VARS" || true)
    if [ -n "$ip_check" ]; then
        log_error "Please update YOUR_IP in $COMMON_VARS"
        return 1
    fi

    if [ ! -d "$lab_dir" ]; then
        log_error "Lab directory not found: $lab_dir"
        return 1
    fi
    
    return 0
}

cmd_list() {
    echo -e "\n${BOLD}${GREEN}Available Labs:${NC}\n"
    local index=1
    for lab in "$LABS_DIR"/*; do
        if [ -d "$lab" ]; then
            local lab_name=$(basename "$lab")
            local readme="$lab/README.md"
            local difficulty="Unknown"
            local description=""
            
            if [ -f "$readme" ]; then
                difficulty=$(grep -i "Difficulty:" "$readme" | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo "Unknown")
                description=$(grep -i "Description:" "$readme" | head -1 | cut -d: -f2- | xargs 2>/dev/null || echo "")
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

cmd_use() {
    local input=$1
    local lab=""
    
    if [ -z "$input" ]; then
        log_error "Usage: use <lab-name|lab-number>"
        return 1
    fi
    
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        local labs=()
        for lab_dir in "$LABS_DIR"/*; do
            if [ -d "$lab_dir" ]; then
                labs+=("$(basename "$lab_dir")")
            fi
        done
        
        if [ "$input" -lt 1 ] || [ "$input" -gt ${#labs[@]} ]; then
            log_error "Invalid lab number: $input (valid range: 1-${#labs[@]})"
            return 1
        fi
        
        lab="${labs[$((input-1))]}"
    else
        lab="$input"
    fi
    
    if [ ! -d "$LABS_DIR/$lab" ]; then
        log_error "Lab not found: $lab"
        return 1
    fi
    
    CURRENT_LAB=$lab
    log_success "Selected lab: $lab"
}

cmd_info() {
    local lab=${1:-$CURRENT_LAB}
    
    if [ -z "$lab" ]; then
        log_error "No lab selected. Use: info <lab-name> or use <lab-name> first"
        return 1
    fi
    
    local readme="$LABS_DIR/$lab/README.md"
    
    if [ ! -f "$readme" ]; then
        log_error "No README found for lab: $lab"
        return 1
    fi
    
    echo -e "\n${BOLD}${CYAN}Lab Information: ${NC}${BOLD}$lab${NC}\n"
    
    if command -v bat &> /dev/null; then
        bat --style=plain --color=always "$readme"
    elif command -v pygmentize &> /dev/null; then
        pygmentize -l markdown "$readme"
    else
        cat "$readme"
    fi
    echo ""
}

cmd_deploy() {
    local lab=${1:-$CURRENT_LAB}
    
    if [ -z "$lab" ]; then
        log_error "No lab selected. Use: deploy <lab-name> or use <lab-name> first"
        return 1
    fi
    
    check_prerequisites "$lab" || return 1
    
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"
    
    log_info "Initializing lab: ${BOLD}$lab${NC}"
    
    mkdir -p "$state_path"
    cd "$lab_dir"
    
    terraform init -backend-config="path=$state_path/terraform.tfstate" -reconfigure > /dev/null 2>&1
    
    log_success "Lab initialized"
    
    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        log_warning "Using terraform.tfvars.example"
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi
    
    echo -e "\n${BOLD}${CYAN}Deployment Plan:${NC}\n"
    terraform plan $var_files
    
    echo ""
    read -p "$(echo -e ${GREEN}Proceed with deployment?${NC} [yes/no]: )" proceed
    
    if [ "$proceed" != "yes" ]; then
        log_info "Deployment cancelled"
        return 0
    fi
    
    log_info "Deploying lab: ${BOLD}$lab${NC}"
    terraform apply $var_files -auto-approve
    
    save_metadata "$lab" "deployed"
    
    log_success "Lab deployed successfully"
    echo -e "\n${BOLD}${CYAN}Lab Access Information:${NC}"
    terraform output
    
    echo -e "\n${YELLOW}Note:${NC} Instance will auto-shutdown in 4 hours"
}

cmd_destroy() {
    local lab=${1:-$CURRENT_LAB}
    
    if [ -z "$lab" ]; then
        log_error "No lab selected. Use: destroy <lab-name> or use <lab-name> first"
        return 1
    fi
    
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"
    
    if [ ! -f "$state_path/terraform.tfstate" ]; then
        log_warning "No active deployment found for lab: $lab"
        return 0
    fi
    
    cd "$lab_dir"
    
    local var_files="-var-file=$COMMON_VARS"
    
    if [ -f "terraform.tfvars" ]; then
        var_files="$var_files -var-file=terraform.tfvars"
    elif [ -f "terraform.tfvars.example" ]; then
        var_files="$var_files -var-file=terraform.tfvars.example"
    fi
    
    echo -e "\n${RED}${BOLD}WARNING:${NC} ${RED}This will destroy all resources for lab: $lab${NC}\n"
    read -p "$(echo -e ${YELLOW}Type lab name to confirm:${NC} )" confirm
    
    if [ "$confirm" != "$lab" ]; then
        log_info "Destruction cancelled"
        return 0
    fi
    
    log_info "Destroying lab: ${BOLD}$lab${NC}"
    terraform destroy $var_files -auto-approve
    
    save_metadata "$lab" "destroyed"
    log_success "Lab destroyed successfully"
    
    if [ "$CURRENT_LAB" == "$lab" ]; then
        CURRENT_LAB=""
    fi
}

cmd_outputs() {
    local lab=${1:-$CURRENT_LAB}
    local sensitive=${2:-false}
    
    if [ -z "$lab" ]; then
        log_error "No lab selected. Use: outputs <lab-name> or use <lab-name> first"
        return 1
    fi
    
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"
    
    if [ ! -f "$state_path/terraform.tfstate" ]; then
        log_error "No state file found. Lab may not be deployed."
        return 1
    fi
    
    cd "$lab_dir"
    
    echo -e "\n${BOLD}${CYAN}Lab Outputs: ${NC}${BOLD}$lab${NC}\n"
    
    if [ "$sensitive" == "true" ] || [ "$sensitive" == "--sensitive" ]; then
        log_warning "Showing sensitive values"
        terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"'
    else
        terraform output
        echo -e "\n${DIM}Use 'outputs --sensitive' to reveal sensitive values${NC}"
    fi
}

cmd_status() {
    local lab=${1:-$CURRENT_LAB}
    
    if [ -z "$lab" ]; then
        log_error "No lab selected. Use: status <lab-name> or use <lab-name> first"
        return 1
    fi
    
    local lab_dir="$LABS_DIR/$lab"
    local state_path="$STATE_DIR/$lab"
    
    echo -e "\n${BOLD}${CYAN}Lab Status: ${NC}${BOLD}$lab${NC}\n"
    
    if [ ! -f "$state_path/terraform.tfstate" ]; then
        echo -e "${YELLOW}Status:${NC} Not deployed"
        return 0
    fi
    
    cd "$lab_dir"
    
    local resources=$(terraform state list 2>/dev/null | wc -l || echo "0")
    local metadata=$(load_metadata "$lab")
    
    echo -e "${GREEN}Status:${NC} Deployed"
    echo -e "${CYAN}Resources:${NC} $resources"
    
    if [ "$metadata" != "{}" ]; then
        echo -e "${CYAN}Deployed by:${NC} $(echo $metadata | jq -r '.deployed_by' 2>/dev/null || echo 'unknown')"
        echo -e "${CYAN}Deployed at:${NC} $(echo $metadata | jq -r '.timestamp' 2>/dev/null || echo 'unknown')"
        echo -e "${CYAN}Region:${NC} $(echo $metadata | jq -r '.aws_region' 2>/dev/null || echo 'unknown')"
    fi
    
    echo -e "\n${BOLD}Key Resources:${NC}"
    terraform state list 2>/dev/null | grep -E "(instance|bucket|role)" | sed 's/^/  • /' || echo "  ${DIM}No resources found${NC}"
    echo ""
}

cmd_active() {
    echo -e "\n${BOLD}${GREEN}Active Deployments:${NC}\n"
    
    if [ ! -d "$STATE_DIR" ]; then
        echo -e "${DIM}None${NC}\n"
        return 0
    fi
    
    local found=0
    for state in "$STATE_DIR"/*; do
        if [ -d "$state" ] && [ -f "$state/terraform.tfstate" ]; then
            local lab_name=$(basename "$state")
            local metadata=$(load_metadata "$lab_name")
            local resources=$(grep -o '"resources":' "$state/terraform.tfstate" | wc -l 2>/dev/null || echo "0")
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

cmd_help() {
    cat << 'HELPEOF'

Core Commands
=============
  list                 List all available labs
  use <lab>            Select a lab to work with
  info [lab]           Show detailed lab information
  deploy [lab]         Deploy the selected or specified lab
  destroy [lab]        Destroy the selected or specified lab
  status [lab]         Show deployment status
  outputs [lab]        Show lab outputs
                       Add --sensitive to show sensitive values
  active               List all active deployments

Navigation
==========
  back                 Deselect current lab
  clear                Clear the screen
  help                 Show this help message
  exit/quit            Exit VAULT

Tips
====
  • Use 'use <lab>' to select a lab, then run commands without specifying the lab name
  • Tab completion available for commands (if readline is enabled)
  • Command history is saved between sessions

HELPEOF
}

cmd_back() {
    if [ -n "$CURRENT_LAB" ]; then
        log_info "Deselected lab: $CURRENT_LAB"
        CURRENT_LAB=""
    else
        log_warning "No lab currently selected"
    fi
}

cmd_clear() {
    clear
    print_banner
}

process_command() {
    local cmd=$1
    shift
    
    case $cmd in
        list|ls)
            cmd_list
            ;;
        use|select)
            cmd_use "$@"
            ;;
        info|show)
            cmd_info "$@"
            ;;
        deploy|run)
            cmd_deploy "$@"
            ;;
        destroy|kill)
            cmd_destroy "$@"
            ;;
        outputs|output)
            cmd_outputs "$@"
            ;;
        status|stat)
            cmd_status "$@"
            ;;
        active|sessions)
            cmd_active
            ;;
        back|deselect)
            cmd_back
            ;;
        clear|cls)
            cmd_clear
            ;;
        help|?|h)
            cmd_help
            ;;
        exit|quit|q)
            echo -e "\n${CYAN}Exiting VAULT...${NC}\n"
            exit 0
            ;;
        "")
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo -e "${DIM}Type 'help' for available commands${NC}"
            ;;
    esac
}

interactive_shell() {
    mkdir -p "$STATE_DIR"
    touch "$HISTORY_FILE"
    
    history -r "$HISTORY_FILE" 2>/dev/null || true
    
    while true; do
        read -e -p "$(get_prompt)" input
        
        if [ -n "$input" ]; then
            history -s "$input"
            history -w "$HISTORY_FILE"
            
            read -ra args <<< "$input"
            process_command "${args[@]}"
        fi
    done
}

non_interactive() {
    INTERACTIVE_MODE=false
    local command=$1
    shift
    
    local lab_name=""
    local sensitive=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sensitive)
                sensitive=true
                shift
                ;;
            *)
                lab_name=$1
                shift
                ;;
        esac
    done
    
    case $command in
        list)
            cmd_list
            ;;
        deploy)
            [ -n "$lab_name" ] && CURRENT_LAB=$lab_name
            cmd_deploy "$lab_name"
            ;;
        destroy)
            [ -n "$lab_name" ] && CURRENT_LAB=$lab_name
            cmd_destroy "$lab_name"
            ;;
        outputs)
            [ -n "$lab_name" ] && CURRENT_LAB=$lab_name
            cmd_outputs "$lab_name" "$sensitive"
            ;;
        status)
            [ -n "$lab_name" ] && CURRENT_LAB=$lab_name
            cmd_status "$lab_name"
            ;;
        active)
            cmd_active
            ;;
        *)
            log_error "Unknown command: $command"
            exit 1
            ;;
    esac
}

main() {
    if [ $# -eq 0 ]; then
        print_banner
        interactive_shell
    else
        non_interactive "$@"
    fi
}

main "$@"