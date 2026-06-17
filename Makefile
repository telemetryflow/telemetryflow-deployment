# TelemetryFlow Deployment - Makefile
#
# TelemetryFlow Deployment - Community Enterprise Observability Platform (CEOP)
# Copyright (c) 2024-2026 Telemetri Data Indonesia. All rights reserved.
#
# Build, deploy, and manage TelemetryFlow infrastructure across environments

# =============================================================================
# Build Configuration
# =============================================================================
PRODUCT_NAME    := TelemetryFlow Deployment
VERSION         ?= 1.4.2
GIT_COMMIT      := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH      := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_TIME      := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

# =============================================================================
# Deployment Configuration
# =============================================================================
HELM_CHART      ?= ./helm/telemetryflow
RELEASE_NAME    ?= telemetryflow
NAMESPACE       ?= telemetryflow
KUBE_CONTEXT    ?= $(shell kubectl config current-context 2>/dev/null)
HELM_ENV        ?= staging
MANIFEST_DIR    ?= ./manifest

# =============================================================================
# Ansible Configuration
# =============================================================================
ANSIBLE_DIR     ?= ./ansible
ANSIBLE_K8S_DIR ?= ./ansible-k8s
INVENTORY       ?= $(ANSIBLE_DIR)/inventory.yml
INVENTORY_K8S   ?= $(ANSIBLE_K8S_DIR)/inventory/hosts.yml

# =============================================================================
# Docker Configuration
# =============================================================================
DOCKER_COMPOSE  ?= docker-compose.yml
ENV_FILE        ?= .env
ENV_EXAMPLE     ?= .env.example

# =============================================================================
# Operator Configuration
# =============================================================================
OPERATOR_DIR    ?= ./operator

# =============================================================================
# Colors for Output
# =============================================================================
GREEN           := \033[0;32m
YELLOW          := \033[0;33m
RED             := \033[0;31m
BLUE            := \033[0;34m
CYAN            := \033[0;36m
NC              := \033[0m

# =============================================================================
# Phony Targets
# =============================================================================
.PHONY: all help version info \
	env-setup secrets-generate \
	ansible-vm-ping ansible-vm-deploy ansible-vm-teardown ansible-vm-status \
	ansible-k8s-deploy ansible-k8s-teardown ansible-k8s-status \
	helm-lint helm-template helm-install helm-uninstall helm-upgrade helm-diff \
	helm-install-staging helm-install-production \
	helm-install-eks-staging helm-install-eks-production \
	operator-install operator-uninstall operator-run operator-deploy \
	operator-build operator-test operator-test-e2e operator-lint \
	docker-up docker-down docker-logs docker-ps docker-restart \
	docker-up-core docker-up-all docker-build docker-push \
	lint verify check \
	init clean

# =============================================================================
# Default Target
# =============================================================================
.DEFAULT_GOAL := help
all: help

# =============================================================================
# Help Target
# =============================================================================
help:
	@echo "$(GREEN)$(PRODUCT_NAME) - Build & Deployment System$(NC)"
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  make init                       - First-time setup (dirs, env, secrets)"
	@echo "  make verify                     - Check prerequisites"
	@echo "  make version                    - Show version information"
	@echo ""
	@echo "$(YELLOW)Environment & Secrets:$(NC)"
	@echo "  make env-setup                  - Copy .env.example to .env"
	@echo "  make secrets-generate           - Generate random secrets"
	@echo ""
	@echo "$(YELLOW)Ansible — VM / Bare Metal:$(NC)"
	@echo "  make ansible-vm-ping            - Ping all VM hosts"
	@echo "  make ansible-vm-deploy          - Deploy TelemetryFlow to VMs"
	@echo "  make ansible-vm-teardown        - Tear down VM deployment"
	@echo "  make ansible-vm-status          - Show VM service status"
	@echo ""
	@echo "$(YELLOW)Ansible — Kubernetes (RKE2):$(NC)"
	@echo "  make ansible-k8s-deploy         - Deploy K8s cluster via Ansible"
	@echo "  make ansible-k8s-teardown       - Tear down K8s deployment"
	@echo "  make ansible-k8s-status         - Show K8s cluster status"
	@echo ""
	@echo "$(YELLOW)Helm — Kubernetes:$(NC)"
	@echo "  make helm-lint                  - Lint the Helm chart"
	@echo "  make helm-template              - Render Helm templates locally"
	@echo "  make helm-install               - Install Helm chart (set HELM_ENV=)"
	@echo "  make helm-uninstall             - Uninstall the Helm release"
	@echo "  make helm-upgrade               - Upgrade the Helm release"
	@echo "  make helm-diff                  - Show diff (requires helm-diff plugin)"
	@echo "  make helm-install-staging       - Install to on-prem staging"
	@echo "  make helm-install-production    - Install to on-prem production"
	@echo "  make helm-install-eks-staging   - Install to EKS staging"
	@echo "  make helm-install-eks-production - Install to EKS production"
	@echo ""
	@echo "$(YELLOW)Operator — Kubernetes:$(NC)"
	@echo "  make operator-install           - Install CRDs into cluster"
	@echo "  make operator-uninstall         - Uninstall CRDs from cluster"
	@echo "  make operator-run               - Run operator locally (dev mode)"
	@echo "  make operator-deploy            - Deploy operator to cluster"
	@echo "  make operator-build             - Build operator binary"
	@echo "  make operator-test              - Run operator unit tests (envtest)"
	@echo "  make operator-test-e2e          - Run operator e2e tests (real cluster)"
	@echo "  make operator-lint              - Run operator linter"
	@echo ""
	@echo "$(YELLOW)Docker Compose — Local Development:$(NC)"
	@echo "  make docker-up-core             - Start core services only"
	@echo "  make docker-up-all              - Start all services + agents"
	@echo "  make docker-up                  - Start all services (no profile)"
	@echo "  make docker-down                - Stop all services"
	@echo "  make docker-logs                - Tail Docker Compose logs"
	@echo "  make docker-ps                  - List running services"
	@echo "  make docker-restart             - Restart all services"
	@echo "  make docker-build               - Build operator Docker image"
	@echo "  make docker-push                - Push operator Docker image"
	@echo ""
	@echo "$(YELLOW)Code Quality:$(NC)"
	@echo "  make lint                       - Run all linters (Helm + Ansible + Operator)"
	@echo "  make verify                     - Verify all prerequisites"
	@echo "  make check                      - Run all checks (lint + verify)"
	@echo ""
	@echo "$(YELLOW)Other:$(NC)"
	@echo "  make init                       - First-time repository setup"
	@echo "  make clean                      - Clean build artifacts"
	@echo "  make info                       - Show build configuration"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  VERSION=$(VERSION)"
	@echo "  HELM_ENV=$(HELM_ENV)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo "  RELEASE_NAME=$(RELEASE_NAME)"
	@echo "  GIT_COMMIT=$(GIT_COMMIT)"
	@echo "  GIT_BRANCH=$(GIT_BRANCH)"

# =============================================================================
# Info Targets
# =============================================================================

## Show version information
version:
	@echo "$(GREEN)$(PRODUCT_NAME)$(NC)"
	@echo "  Version:          $(VERSION)"
	@echo "  Git Commit:       $(GIT_COMMIT)"
	@echo "  Git Branch:       $(GIT_BRANCH)"
	@echo "  Build Time:       $(BUILD_TIME)"

## Show build configuration
info:
	@echo "$(GREEN)Build Configuration$(NC)"
	@echo ""
	@echo "$(YELLOW)Product:$(NC)"
	@echo "  Name:             $(PRODUCT_NAME)"
	@echo "  Version:          $(VERSION)"
	@echo ""
	@echo "$(YELLOW)Git:$(NC)"
	@echo "  Commit:           $(GIT_COMMIT)"
	@echo "  Branch:           $(GIT_BRANCH)"
	@echo "  Build Time:       $(BUILD_TIME)"
	@echo ""
	@echo "$(YELLOW)Helm:$(NC)"
	@echo "  Chart:            $(HELM_CHART)"
	@echo "  Release:          $(RELEASE_NAME)"
	@echo "  Namespace:        $(NAMESPACE)"
	@echo "  Environment:      $(HELM_ENV)"
	@echo ""
	@echo "$(YELLOW)Ansible:$(NC)"
	@echo "  VM Inventory:     $(INVENTORY)"
	@echo "  K8s Inventory:    $(INVENTORY_K8S)"
	@echo ""
	@echo "$(YELLOW)Docker:$(NC)"
	@echo "  Compose File:     $(DOCKER_COMPOSE)"
	@echo "  Env File:         $(ENV_FILE)"

# =============================================================================
# Environment & Secrets
# =============================================================================

## Copy .env.example to .env (if .env does not exist)
env-setup:
	@if [ ! -f $(ENV_FILE) ]; then \
		cp $(ENV_EXAMPLE) $(ENV_FILE); \
		echo "$(GREEN)Created $(ENV_FILE) from $(ENV_EXAMPLE)$(NC)"; \
	else \
		echo "$(YELLOW)$(ENV_FILE) already exists — skipping$(NC)"; \
	fi

## Generate random secrets using openssl
secrets-generate:
	@echo "$(GREEN)Generating random secrets…$(NC)"
	@echo "POSTGRES_PASSWORD=$(shell openssl rand -hex 24)"
	@echo "CLICKHOUSE_PASSWORD=$(shell openssl rand -hex 24)"
	@echo "REDIS_PASSWORD=$(shell openssl rand -hex 24)"
	@echo "NATS_PASSWORD=$(shell openssl rand -hex 24)"
	@echo "JWT_SECRET=$(shell openssl rand -hex 32)"
	@echo "$(GREEN)Copy the values above into your .env file$(NC)"

# =============================================================================
# Ansible — VM / Bare Metal
# =============================================================================

## Ping all VM hosts
ansible-vm-ping:
	@echo "$(GREEN)Pinging VM hosts…$(NC)"
	ansible all -i $(INVENTORY) -m ping

## Deploy TelemetryFlow to VMs
ansible-vm-deploy:
	@echo "$(GREEN)Deploying TelemetryFlow to VMs…$(NC)"
	ansible-playbook $(ANSIBLE_DIR)/playbooks/site.yml -i $(INVENTORY)

## Tear down VM deployment
ansible-vm-teardown:
	@echo "$(YELLOW)Tearing down VM deployment…$(NC)"
	ansible-playbook $(ANSIBLE_DIR)/playbooks/cleanup-platform.yml -i $(INVENTORY)

## Show VM service status
ansible-vm-status:
	@echo "$(GREEN)Checking VM service status…$(NC)"
	ansible all -i $(INVENTORY) -m shell -a "systemctl status telemetryflow --no-pager"

# =============================================================================
# Ansible — Kubernetes (RKE2)
# =============================================================================

## Deploy K8s cluster via Ansible
ansible-k8s-deploy:
	@echo "$(GREEN)Deploying Kubernetes cluster via Ansible…$(NC)"
	ansible-playbook $(ANSIBLE_K8S_DIR)/playbooks/site.yml -i $(INVENTORY_K8S)

## Tear down K8s deployment via Ansible
ansible-k8s-teardown:
	@echo "$(YELLOW)Tearing down Kubernetes deployment…$(NC)"
	ansible-playbook $(ANSIBLE_K8S_DIR)/playbooks/04-maintenance.yml -i $(INVENTORY_K8S) -e "action=teardown"

## Show K8s cluster status
ansible-k8s-status:
	@echo "$(GREEN)Checking K8s cluster status…$(NC)"
	ansible k8s_masters -i $(INVENTORY_K8S) -m shell -a "kubectl get nodes -o wide"

# =============================================================================
# Helm — Kubernetes
# =============================================================================

## Lint the Helm chart
helm-lint:
	@echo "$(GREEN)Linting Helm chart…$(NC)"
	helm lint $(HELM_CHART)

## Render Helm templates locally
helm-template:
	@echo "$(GREEN)Rendering Helm templates…$(NC)"
	helm template $(RELEASE_NAME) $(HELM_CHART) --namespace $(NAMESPACE)

## Install Helm chart (set HELM_ENV=staging|production)
helm-install:
	@echo "$(GREEN)Installing Helm release $(RELEASE_NAME) ($(HELM_ENV))…$(NC)"
	helm upgrade $(RELEASE_NAME) $(HELM_CHART) \
		--install \
		--namespace $(NAMESPACE) --create-namespace \
		-f $(HELM_CHART)/values.yaml \
		-f $(MANIFEST_DIR)/tfo-$(HELM_ENV).yaml \
		--timeout 5m --wait

## Uninstall the Helm release
helm-uninstall:
	@echo "$(YELLOW)Uninstalling Helm release $(RELEASE_NAME)…$(NC)"
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

## Upgrade the Helm release
helm-upgrade:
	@echo "$(GREEN)Upgrading Helm release $(RELEASE_NAME) ($(HELM_ENV))…$(NC)"
	helm upgrade $(RELEASE_NAME) $(HELM_CHART) \
		--namespace $(NAMESPACE) \
		-f $(HELM_CHART)/values.yaml \
		-f $(MANIFEST_DIR)/tfo-$(HELM_ENV).yaml \
		--timeout 5m --wait

## Show diff between deployed and local chart (requires helm-diff plugin)
helm-diff:
	@echo "$(GREEN)Showing Helm diff ($(HELM_ENV))…$(NC)"
	helm diff upgrade $(RELEASE_NAME) $(HELM_CHART) \
		--namespace $(NAMESPACE) \
		-f $(HELM_CHART)/values.yaml \
		-f $(MANIFEST_DIR)/tfo-$(HELM_ENV).yaml

## Install to on-prem staging
helm-install-staging:
	@echo "$(GREEN)Installing to on-prem staging…$(NC)"
	$(MAKE) helm-install HELM_ENV=staging

## Install to on-prem production
helm-install-production:
	@echo "$(GREEN)Installing to on-prem production…$(NC)"
	$(MAKE) helm-install HELM_ENV=production

## Install to EKS staging
helm-install-eks-staging:
	@echo "$(GREEN)Installing to EKS staging…$(NC)"
	$(MAKE) helm-install HELM_ENV=eks-staging

## Install to EKS production
helm-install-eks-production:
	@echo "$(GREEN)Installing to EKS production…$(NC)"
	$(MAKE) helm-install HELM_ENV=eks-production

# =============================================================================
# Operator — Kubernetes
# =============================================================================

## Install CRDs into the active cluster
operator-install:
	@echo "$(GREEN)Installing CRDs…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) install

## Uninstall CRDs from the active cluster
operator-uninstall:
	@echo "$(YELLOW)Uninstalling CRDs…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) uninstall

## Run the operator locally (dev mode)
operator-run:
	@echo "$(GREEN)Starting operator in dev mode…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) run

## Deploy operator to cluster
operator-deploy:
	@echo "$(GREEN)Deploying operator to cluster…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) deploy

## Build operator binary
operator-build:
	@echo "$(GREEN)Building operator…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) build

## Run operator unit tests (envtest)
operator-test:
	@echo "$(GREEN)Running operator unit tests…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) test

## Run operator e2e tests (real cluster)
operator-test-e2e:
	@echo "$(GREEN)Running operator e2e tests…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) test-e2e

## Run operator linter
operator-lint:
	@echo "$(GREEN)Running operator linter…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) lint

# =============================================================================
# Docker Compose — Local Development
# =============================================================================

## Start all Docker Compose services
docker-up:
	@echo "$(GREEN)Starting Docker Compose services…$(NC)"
	docker compose -f $(DOCKER_COMPOSE) --env-file $(ENV_FILE) up -d

## Stop all Docker Compose services
docker-down:
	@echo "$(YELLOW)Stopping Docker Compose services…$(NC)"
	docker compose -f $(DOCKER_COMPOSE) --env-file $(ENV_FILE) down

## Tail Docker Compose logs
docker-logs:
	docker compose -f $(DOCKER_COMPOSE) logs -f

## List running Docker Compose services
docker-ps:
	docker compose -f $(DOCKER_COMPOSE) ps

## Restart all Docker Compose services
docker-restart:
	@echo "$(GREEN)Restarting Docker Compose services…$(NC)"
	docker compose -f $(DOCKER_COMPOSE) --env-file $(ENV_FILE) restart

## Start only core services (backend, datastore)
docker-up-core:
	@echo "$(GREEN)Starting core services…$(NC)"
	docker compose -f $(DOCKER_COMPOSE) --env-file $(ENV_FILE) --profile core up -d

## Start all services including agents
docker-up-all:
	@echo "$(GREEN)Starting all services (core + agents)…$(NC)"
	docker compose -f $(DOCKER_COMPOSE) --env-file $(ENV_FILE) --profile core --profile agents up -d

## Build operator Docker image
docker-build:
	@echo "$(GREEN)Building operator Docker image…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) docker-build

## Push operator Docker image
docker-push:
	@echo "$(GREEN)Pushing operator Docker image…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) docker-push

# =============================================================================
# Code Quality
# =============================================================================

## Run all linters (Helm + Ansible + Operator)
lint:
	@echo "$(GREEN)Running all linters…$(NC)"
	@echo "$(BLUE)Linting Helm chart…$(NC)"
	helm lint $(HELM_CHART)
	@echo "$(BLUE)Linting Ansible playbooks…$(NC)"
	-cd $(ANSIBLE_DIR) && ansible-lint 2>/dev/null || echo "$(YELLOW)ansible-lint not found, skipping$(NC)"
	@echo "$(BLUE)Linting operator…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) lint 2>/dev/null || echo "$(YELLOW)Operator lint skipped$(NC)"
	@echo "$(GREEN)All linters complete$(NC)"

## Verify all prerequisites are installed
verify:
	@echo "$(GREEN)Checking prerequisites…$(NC)"
	@command -v kubectl  >/dev/null 2>&1 && echo "  $(GREEN)✔$(NC) kubectl  ($$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1))" || echo "  $(RED)✘$(NC) kubectl  not found"
	@command -v helm     >/dev/null 2>&1 && echo "  $(GREEN)✔$(NC) helm     ($$(helm version --short))" || echo "  $(RED)✘$(NC) helm     not found"
	@command -v ansible  >/dev/null 2>&1 && echo "  $(GREEN)✔$(NC) ansible  ($$(ansible --version | head -1))" || echo "  $(RED)✘$(NC) ansible  not found"
	@command -v docker   >/dev/null 2>&1 && echo "  $(GREEN)✔$(NC) docker   ($$(docker --version))" || echo "  $(RED)✘$(NC) docker   not found"
	@command -v go       >/dev/null 2>&1 && echo "  $(GREEN)✔$(NC) go       ($$(go version))" || echo "  $(RED)✘$(NC) go       not found"
	@command -v make     >/dev/null 2>&1 && echo "  $(GREEN)✔$(NC) make" || echo "  $(RED)✘$(NC) make     not found"

## Run all checks (lint + verify)
check: verify lint
	@echo "$(GREEN)All checks passed$(NC)"

# =============================================================================
# Init & Clean
# =============================================================================

## First-time setup — create directories, copy env, generate secrets
init: env-setup
	@echo "$(GREEN)Initializing TelemetryFlow deployment repository…$(NC)"
	@mkdir -p ansible/inventory/group_vars ansible/roles ansible/host_vars
	@mkdir -p ansible-k8s/inventory/group_vars ansible-k8s/inventory/host_vars ansible-k8s/roles
	@mkdir -p helm/telemetryflow/templates helm/telemetryflow/manifest
	@mkdir -p operator
	@mkdir -p scripts docs
	@echo "$(BLUE)Running prerequisites check…$(NC)"
	@$(MAKE) verify
	@echo ""
	@echo "$(GREEN)TelemetryFlow deployment repo is ready.$(NC)"
	@echo "$(YELLOW)Edit $(ENV_FILE) with your configuration, then run 'make secrets-generate'.$(NC)"

## Clean build artifacts
clean:
	@echo "$(GREEN)Cleaning build artifacts…$(NC)"
	$(MAKE) -C $(OPERATOR_DIR) clean 2>/dev/null || true
	@echo "$(GREEN)Clean complete$(NC)"
