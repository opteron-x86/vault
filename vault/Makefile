# Makefile for cloud security lab management

.PHONY: help list deploy destroy status clean setup

LAB ?= ssrf-metadata
LABCTL = ./scripts/labctl.sh

help:
	@echo "Cloud Security Labs Management"
	@echo ""
	@echo "Usage: make [target] LAB=lab-name"
	@echo ""
	@echo "Targets:"
	@echo "  setup           Install prerequisites and configure environment"
	@echo "  list            List all available labs"
	@echo "  deploy          Deploy specified lab (default: ssrf-metadata)"
	@echo "  destroy         Destroy specified lab"
	@echo "  status          Show lab deployment status"
	@echo "  output          Show lab connection details"
	@echo "  clean           Destroy all deployed labs"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy LAB=ssrf-metadata"
	@echo "  make destroy LAB=s3-privesc"
	@echo "  make list"

setup:
	@echo "Setting up lab environment..."
	@chmod +x scripts/*.sh
	@mkdir -p config modules shared
	@which terraform > /dev/null || (echo "Installing terraform..." && brew install terraform)
	@which aws > /dev/null || (echo "Installing AWS CLI..." && brew install awscli)
	@echo "Setup complete"

list:
	@$(LABCTL) list

deploy:
	@$(LABCTL) deploy $(LAB)

destroy:
	@$(LABCTL) destroy $(LAB)

status:
	@$(LABCTL) status $(LAB)

output:
	@$(LABCTL) output $(LAB)

clean:
	@$(LABCTL) cleanup-all

# Development targets
validate:
	@cd labs/$(LAB) && terraform fmt && terraform validate

fmt:
	@find labs -name "*.tf" -exec terraform fmt {} \;

cost:
	@$(LABCTL) cost $(LAB)

# Quick deployment shortcuts
ssrf: 
	@$(MAKE) deploy LAB=ssrf-metadata

s3:
	@$(MAKE) deploy LAB=s3-privesc

lambda:
	@$(MAKE) deploy LAB=lambda-injection