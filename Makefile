# Home lab on a MacBook: Colima VM -> k3d (k3s in Docker) -> Flux syncing this repo from GitHub.
CLUSTER        ?= lab
KUBE_CONTEXT   ?= k3d-$(CLUSTER)
GITHUB_OWNER   ?= Hawuawu
GITHUB_REPO    ?= homelab
FLUX_PATH      ?= clusters/lab
COLIMA_CPU     ?= 4
COLIMA_MEMORY  ?= 8
COLIMA_DISK    ?= 60
export SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt

.PHONY: help deps up vm cluster sops-key bootstrap status open stop start destroy validate lint test e2e

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

deps: ## Install the CLI tools with Homebrew
	brew install colima docker kubectl k3d fluxcd/tap/flux sops age kubeconform kube-linter yamllint shellcheck

vm: ## Start the Colima Linux VM (Apple Virtualization framework)
	colima status >/dev/null 2>&1 || colima start --vm-type vz --cpu $(COLIMA_CPU) --memory $(COLIMA_MEMORY) --disk $(COLIMA_DISK)

cluster: ## Create the k3d cluster (1 server + 2 agents)
	k3d cluster list $(CLUSTER) >/dev/null 2>&1 || k3d cluster create $(CLUSTER) --config bootstrap/k3d-lab.yaml

up: vm cluster ## Start the VM and create the cluster

sops-key: ## Create the lab age key (once) and write its public key to .sops.yaml
	@mkdir -p $(dir $(SOPS_AGE_KEY_FILE))
	@test -f $(SOPS_AGE_KEY_FILE) || age-keygen -o $(SOPS_AGE_KEY_FILE)
	@perl -pi -e "s/age: .*/age: $$(age-keygen -y $(SOPS_AGE_KEY_FILE))/" .sops.yaml
	@echo "Recipient written to .sops.yaml. Back up $(SOPS_AGE_KEY_FILE) (e.g. in your password manager)."

bootstrap: ## Install Flux and connect it to GitHub (needs GITHUB_TOKEN)
	@test -n "$$GITHUB_TOKEN" || (echo "export GITHUB_TOKEN first" && exit 1)
	@test -f $(SOPS_AGE_KEY_FILE) || (echo "run 'make sops-key' first" && exit 1)
	kubectl --context $(KUBE_CONTEXT) create namespace flux-system --dry-run=client -o yaml \
	  | kubectl --context $(KUBE_CONTEXT) apply -f -
	kubectl --context $(KUBE_CONTEXT) -n flux-system create secret generic sops-age \
	  --from-file=age.agekey=$(SOPS_AGE_KEY_FILE) --dry-run=client -o yaml | kubectl --context $(KUBE_CONTEXT) apply -f -
	flux bootstrap github --context=$(KUBE_CONTEXT) --owner=$(GITHUB_OWNER) --repository=$(GITHUB_REPO) --branch=main \
	  --path=$(FLUX_PATH) --personal

status: ## Show Flux sources and reconciliations
	flux get all -A

open: ## Open the sample app
	open http://podinfo.localhost:8080

stop: ## Stop the cluster and the VM (state is kept)
	k3d cluster stop $(CLUSTER)
	colima stop

start: ## Start the VM and the stopped cluster
	colima start
	k3d cluster start $(CLUSTER)

destroy: ## Delete the cluster (Git stays the source of truth)
	k3d cluster delete $(CLUSTER)

validate: ## Render and schema-validate all manifests, check secrets are encrypted
	scripts/validate.sh
	scripts/check-secrets.sh

lint: validate ## yamllint, shellcheck and kube-linter
	yamllint --strict .
	shellcheck scripts/*.sh
	kube-linter lint --config .kube-linter.yaml .tmp/rendered

test: ## Unit tests for the repo tooling
	scripts/test-check-secrets.sh

e2e: ## Create the cluster and deploy (MODE=flux|kustomize)
	scripts/e2e.sh
