.PHONY: help prereqs init check-image deploy destroy infra infra-plan destroy-infra configure generate-inventory bootstrap scale talos-reset status kubeconfig talos-health ssh-haproxy argocd-password

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Load environment variables
ifneq (,$(wildcard .env))
    include .env
    export
endif

help: ## Show all targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

prereqs: ## Install host dependencies (libvirt, qemu, talosctl, etc.)
	@scripts/prerequisites.sh

init: ## Initialize project: select versions, download Talos image
	@scripts/init.sh

check-image:
	@IMAGE_PATH=$$(grep -E '^talos_image_path\s*=' tofu/terraform.tfvars | sed 's/.*=\s*"\(.*\)"/\1/'); \
	if [ ! -f "$$IMAGE_PATH" ]; then echo "\033[31m[ERROR]\033[0m Talos image not found at $$IMAGE_PATH. Run 'make init' first."; exit 1; fi

deploy: check-image ## Full lifecycle: infra → configure → bootstrap
	$(MAKE) infra
	$(MAKE) configure
	$(MAKE) bootstrap

destroy: ## Full teardown: reset cluster → destroy VMs
	$(MAKE) talos-reset
	$(MAKE) destroy-infra

infra: ## OpenTofu apply (create NAT network + VMs)
	cd tofu && tofu init && tofu apply -auto-approve

infra-plan: ## OpenTofu plan (preview changes)
	cd tofu && tofu init && tofu plan

destroy-infra: ## OpenTofu destroy (remove VMs + NAT network)
	cd tofu && tofu destroy -auto-approve

configure: generate-inventory ## Generate inventory + configure HAProxy + apply Talos configs
	cd ansible && ansible-playbook playbooks/haproxy.yml
	cd ansible && ansible-playbook playbooks/talos-config.yml

generate-inventory: ## Generate Ansible inventory from tofu outputs
	@scripts/generate-inventory.sh

bootstrap: ## Bootstrap etcd + install Cilium + fetch kubeconfig + install ArgoCD
	cd ansible && ansible-playbook playbooks/talos-bootstrap.yml
	cd ansible && ansible-playbook playbooks/cilium.yml
	cd ansible && ansible-playbook playbooks/kubeconfig.yml
	cd ansible && ansible-playbook playbooks/argocd-bootstrap.yml

scale: infra generate-inventory ## Scale workers/CPs (after changing terraform.tfvars)
	cd ansible && ansible-playbook playbooks/haproxy.yml
	cd ansible && ansible-playbook playbooks/talos-config.yml

talos-reset: ## Reset all Talos nodes (wipe cluster state)
	cd ansible && ansible-playbook playbooks/talos-reset.yml || true

status: ## Show VM list + node status + pod status
	@echo "=== VMs ==="
	@virsh list --all 2>/dev/null || true
	@echo ""
	@echo "=== Nodes ==="
	@kubectl --kubeconfig kubeconfig get nodes -o wide 2>/dev/null || echo "Cluster not available"
	@echo ""
	@echo "=== Pods ==="
	@kubectl --kubeconfig kubeconfig get pods -A 2>/dev/null || echo "Cluster not available"

kubeconfig: ## Fetch fresh kubeconfig
	cd ansible && ansible-playbook playbooks/kubeconfig.yml

talos-health: ## Check Talos cluster health
	@HAPROXY_IP=$$(cd tofu && tofu output -raw haproxy_ip 2>/dev/null || echo "192.168.122.100"); \
	CP1_IP=$$(cd tofu && tofu output -json controlplane_ips 2>/dev/null | jq -r '.[0]' || echo "192.168.122.101"); \
	talosctl health --talosconfig ansible/talos-generated/talosconfig --nodes "$$CP1_IP"

ssh-haproxy: ## SSH into HAProxy VM
	@HAPROXY_IP=$$(cd tofu && tofu output -raw haproxy_ip 2>/dev/null || echo "192.168.122.100"); \
	ssh alpine@"$$HAPROXY_IP"

argocd-password: ## Get ArgoCD admin password
	@kubectl --kubeconfig kubeconfig -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
