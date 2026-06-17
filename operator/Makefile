# TelemetryFlow Operator - Makefile
#
# TelemetryFlow Operator - Community Enterprise Observability Platform (CEOP)
# Copyright (c) 2024-2026 Telemetri Data Indonesia. All rights reserved.
#
# Kubernetes Operator for managing TelemetryFlow deployments (Kubebuilder / Go 1.26)

# =============================================================================
# Build Configuration
# =============================================================================
PRODUCT_NAME            := TelemetryFlow Operator
BINARY_NAME             := manager
VERSION                 ?= 1.4.2
IMG                     ?= controller:latest
GIT_COMMIT              := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH              := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_TIME              := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
GO_VERSION              := $(shell go version | cut -d ' ' -f 3)

# =============================================================================
# Directories
# =============================================================================
BUILD_DIR               := ./bin
CONFIG_DIR              := ./config

# =============================================================================
# Go Parameters
# =============================================================================
GOCMD                   := go
GOBUILD                 := $(GOCMD) build
GOCLEAN                 := $(GOCMD) clean
GOTEST                  := $(GOCMD) test
GOMOD                   := $(GOCMD) mod

# =============================================================================
# Build Flags
# =============================================================================
LDFLAGS                 := -s -w \
	-X 'main.Version=$(VERSION)' \
	-X 'main.GitCommit=$(GIT_COMMIT)' \
	-X 'main.GitBranch=$(GIT_BRANCH)' \
	-X 'main.BuildTime=$(BUILD_TIME)'

# =============================================================================
# Tool Configuration
# =============================================================================
ENVTEST_K8S_VERSION      = 1.31.0
CONTAINER_TOOL          ?= docker
PLATFORMS               ?= linux/arm64,linux/amd64,linux/s390x,linux/ppc64le

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# =============================================================================
# Tool Binaries & Versions
# =============================================================================
LOCALBIN                ?= $(shell pwd)/bin
KUSTOMIZE               ?= $(LOCALBIN)/kustomize
CONTROLLER_GEN          ?= $(LOCALBIN)/controller-gen
ENVTEST                 ?= $(LOCALBIN)/setup-envtest
GOLANGCI_LINT           ?= $(LOCALBIN)/golangci-lint

KUSTOMIZE_VERSION       ?= v5.4.2
CONTROLLER_TOOLS_VERSION ?= v0.16.1
ENVTEST_VERSION         ?= release-0.19
GOLANGCI_LINT_VERSION   ?= v1.59.0

# =============================================================================
# Colors for Output
# =============================================================================
GREEN                   := \033[0;32m
YELLOW                  := \033[0;33m
RED                     := \033[0;31m
BLUE                    := \033[0;34m
CYAN                    := \033[0;36m
NC                      := \033[0m

# =============================================================================
# Shell Configuration
# =============================================================================
SHELL                   = /usr/bin/env bash -o pipefail
.SHELLFLAGS             = -ec

# =============================================================================
# Phony Targets
# =============================================================================
.PHONY: all help version info \
	build run \
	manifests generate generate-manifests \
	fmt fmt-check vet staticcheck lint lint-fix \
	test test-e2e test-coverage check \
	deps tidy verify \
	install uninstall deploy undeploy \
	docker-build docker-push docker-buildx docker-run \
	clean \
	controller-gen kustomize envtest golangci-lint

# =============================================================================
# Default Target
# =============================================================================
.DEFAULT_GOAL := help
all: build

# =============================================================================
# Help Target
# =============================================================================
help:
	@echo "$(GREEN)$(PRODUCT_NAME) - Build System$(NC)"
	@echo ""
	@echo "$(YELLOW)Primary Build:$(NC)"
	@echo "  make                  - Build operator (default)"
	@echo "  make build            - Build operator binary for current platform"
	@echo "  make run              - Build and run operator locally"
	@echo "  make tidy             - Tidy go modules"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make manifests        - Generate CRD, RBAC, Webhook manifests"
	@echo "  make generate         - Generate DeepCopy methods"
	@echo "  make generate-manifests - Generate all manifests and code"
	@echo ""
	@echo "$(YELLOW)Testing:$(NC)"
	@echo "  make test             - Run unit tests (envtest, no cluster needed)"
	@echo "  make test-e2e         - Run e2e tests (build + envtest)"
	@echo "  make test-coverage    - Generate coverage report"
	@echo "  make check            - Run all checks (fmt, vet, lint, test)"
	@echo ""
	@echo "$(YELLOW)Code Quality:$(NC)"
	@echo "  make fmt              - Format code (go fmt)"
	@echo "  make fmt-check        - Check code formatting (CI)"
	@echo "  make vet              - Run go vet"
	@echo "  make staticcheck      - Run staticcheck"
	@echo "  make lint             - Run golangci-lint"
	@echo "  make lint-fix         - Run golangci-lint with auto-fix"
	@echo ""
	@echo "$(YELLOW)Dependencies:$(NC)"
	@echo "  make deps             - Download dependencies"
	@echo "  make tidy             - Tidy go modules"
	@echo "  make verify           - Verify dependencies"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  make install          - Install CRDs into cluster"
	@echo "  make uninstall        - Uninstall CRDs from cluster"
	@echo "  make deploy           - Deploy operator to cluster"
	@echo "  make undeploy         - Undeploy operator from cluster"
	@echo ""
	@echo "$(YELLOW)Docker:$(NC)"
	@echo "  make docker-build     - Build Docker image"
	@echo "  make docker-push      - Push Docker image"
	@echo "  make docker-buildx    - Build multi-platform Docker image"
	@echo "  make docker-run       - Run Docker container"
	@echo ""
	@echo "$(YELLOW)Other:$(NC)"
	@echo "  make clean            - Clean build artifacts"
	@echo "  make version          - Show version information"
	@echo "  make info             - Show build configuration"
	@echo ""
	@echo "$(YELLOW)Configuration:$(NC)"
	@echo "  VERSION=$(VERSION)"
	@echo "  IMG=$(IMG)"
	@echo "  ENVTEST_K8S_VERSION=$(ENVTEST_K8S_VERSION)"
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
	@echo "  Go Version:       $(GO_VERSION)"
	@echo "  Envtest K8s:      $(ENVTEST_K8S_VERSION)"

## Show build configuration
info:
	@echo "$(GREEN)Build Configuration$(NC)"
	@echo ""
	@echo "$(YELLOW)Product:$(NC)"
	@echo "  Name:             $(PRODUCT_NAME)"
	@echo "  Binary:           $(BINARY_NAME)"
	@echo "  Version:          $(VERSION)"
	@echo "  Image:            $(IMG)"
	@echo ""
	@echo "$(YELLOW)Versions:$(NC)"
	@echo "  Go:               $(GO_VERSION)"
	@echo "  Envtest K8s:      $(ENVTEST_K8S_VERSION)"
	@echo "  Kustomize:        $(KUSTOMIZE_VERSION)"
	@echo "  Controller Tools: $(CONTROLLER_TOOLS_VERSION)"
	@echo "  Golangci-lint:    $(GOLANGCI_LINT_VERSION)"
	@echo ""
	@echo "$(YELLOW)Git:$(NC)"
	@echo "  Commit:           $(GIT_COMMIT)"
	@echo "  Branch:           $(GIT_BRANCH)"
	@echo "  Build Time:       $(BUILD_TIME)"
	@echo ""
	@echo "$(YELLOW)Directories:$(NC)"
	@echo "  Build:            $(BUILD_DIR)"
	@echo "  Config:           $(CONFIG_DIR)"
	@echo "  Local Bin:        $(LOCALBIN)"

# =============================================================================
# Build Targets
# =============================================================================

## Build operator binary for current platform
build: manifests generate fmt vet
	@echo "$(GREEN)Building $(BINARY_NAME) v$(VERSION)...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@$(GOBUILD) -ldflags "$(LDFLAGS)" -o $(BUILD_DIR)/$(BINARY_NAME) main.go
	@echo "$(GREEN)Build complete: $(BUILD_DIR)/$(BINARY_NAME)$(NC)"

## Build and run operator locally
run: manifests generate fmt vet
	@echo "$(GREEN)Starting $(BINARY_NAME) locally...$(NC)"
	@$(GOCMD) run main.go

# =============================================================================
# Code Generation Targets
# =============================================================================

## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects
manifests: controller-gen
	@echo "$(GREEN)Generating manifests...$(NC)"
	$(CONTROLLER_GEN) rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases

## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyList method implementations
generate: controller-gen
	@echo "$(GREEN)Generating code...$(NC)"
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

## Generate manifests and code
generate-manifests: manifests generate
	@echo "$(GREEN)All manifests and code generated$(NC)"

# =============================================================================
# Testing Targets
# =============================================================================

## Run unit tests (envtest, no cluster needed)
test: manifests generate fmt vet envtest
	@echo "$(GREEN)Running unit tests (envtest)...$(NC)"
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" $(GOTEST) ./tests/unit/... -coverprofile cover.out
	@echo "$(GREEN)Unit tests complete$(NC)"

## Run e2e tests (requires envtest binaries)
test-e2e: manifests generate fmt vet envtest
	@echo "$(GREEN)Running e2e tests...$(NC)"
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use $(ENVTEST_K8S_VERSION) --bin-dir $(LOCALBIN) -p path)" $(GOTEST) ./tests/e2e/ -v -timeout 30m
	@echo "$(GREEN)E2E tests complete$(NC)"

## Generate coverage report
test-coverage:
	@echo "$(GREEN)Generating coverage report...$(NC)"
	@$(GOCMD) tool cover -html=cover.out -o coverage.html 2>/dev/null || true
	@$(GOCMD) tool cover -func=cover.out | tee coverage-summary.txt
	@echo "$(GREEN)Coverage report generated$(NC)"

# =============================================================================
# Code Quality Targets
# =============================================================================

## Format code
fmt:
	@echo "$(GREEN)Formatting code...$(NC)"
	@$(GOCMD) fmt ./...
	@echo "$(GREEN)Code formatted$(NC)"

## Check code formatting (fails if code needs formatting)
fmt-check:
	@echo "$(GREEN)Checking code formatting...$(NC)"
	@if [ -n "$$(gofmt -l .)" ]; then \
		echo "$(RED)The following files need formatting:$(NC)"; \
		gofmt -l .; \
		exit 1; \
	fi
	@echo "$(GREEN)Code formatting OK$(NC)"

## Run go vet
vet:
	@echo "$(GREEN)Running go vet...$(NC)"
	@$(GOCMD) vet ./...
	@echo "$(GREEN)Vet complete$(NC)"

## Run staticcheck
staticcheck:
	@echo "$(GREEN)Running staticcheck...$(NC)"
	@STATICCHECK="$$(go env GOPATH)/bin/staticcheck"; \
	if ! $$STATICCHECK -version 2>/dev/null | grep -q "v0\.7\|2026\."; then \
		echo "$(YELLOW)Installing staticcheck v0.7.0...$(NC)"; \
		$(GOCMD) install honnef.co/go/tools/cmd/staticcheck@v0.7.0; \
	fi; \
	$$STATICCHECK ./...

## Run golangci-lint
lint: golangci-lint
	@echo "$(GREEN)Running golangci-lint...$(NC)"
	$(GOLANGCI_LINT) run ./...

## Run golangci-lint with auto-fix
lint-fix: golangci-lint
	@echo "$(GREEN)Running golangci-lint with auto-fix...$(NC)"
	$(GOLANGCI_LINT) run --fix ./...

## Run all checks (fmt, vet, lint, test)
check: fmt vet lint test
	@echo "$(GREEN)All checks passed$(NC)"

# =============================================================================
# Dependencies Targets
# =============================================================================

## Download dependencies
deps:
	@echo "$(GREEN)Downloading dependencies...$(NC)"
	@$(GOMOD) download
	@$(GOMOD) tidy
	@echo "$(GREEN)Dependencies downloaded$(NC)"

## Tidy go modules
tidy:
	@echo "$(GREEN)Tidying go modules...$(NC)"
	@$(GOMOD) tidy
	@echo "$(GREEN)Go modules tidied$(NC)"

## Verify dependencies
verify:
	@echo "$(GREEN)Verifying dependencies...$(NC)"
	@$(GOMOD) verify
	@echo "$(GREEN)Dependencies verified$(NC)"

# =============================================================================
# Deployment Targets
# =============================================================================

ifndef ignore-not-found
  ignore-not-found = false
endif

## Install CRDs into the K8s cluster
install: manifests kustomize
	@echo "$(GREEN)Installing CRDs into cluster...$(NC)"
	$(KUSTOMIZE) build config/crd | kubectl apply -f -
	@echo "$(GREEN)CRDs installed$(NC)"

## Uninstall CRDs from the K8s cluster
uninstall: manifests kustomize
	@echo "$(YELLOW)Uninstalling CRDs from cluster...$(NC)"
	$(KUSTOMIZE) build config/crd | kubectl delete --ignore-not-found=$(ignore-not-found) -f -
	@echo "$(GREEN)CRDs uninstalled$(NC)"

## Deploy controller to the K8s cluster
deploy: manifests kustomize
	@echo "$(GREEN)Deploying operator to cluster...$(NC)"
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -
	@echo "$(GREEN)Operator deployed$(NC)"

## Undeploy controller from the K8s cluster
undeploy:
	@echo "$(YELLOW)Undeploying operator from cluster...$(NC)"
	$(KUSTOMIZE) build config/default | kubectl delete --ignore-not-found=$(ignore-not-found) -f -
	@echo "$(GREEN)Operator undeployed$(NC)"

# =============================================================================
# Docker Targets
# =============================================================================

## Build Docker image
docker-build:
	@echo "$(GREEN)Building Docker image...$(NC)"
	$(CONTAINER_TOOL) build -t ${IMG} .
	@echo "$(GREEN)Docker image built: ${IMG}$(NC)"

## Push Docker image
docker-push:
	@echo "$(GREEN)Pushing Docker image...$(NC)"
	$(CONTAINER_TOOL) push ${IMG}
	@echo "$(GREEN)Docker image pushed: ${IMG}$(NC)"

## Build multi-platform Docker image
docker-buildx:
	@echo "$(GREEN)Building multi-platform Docker image...$(NC)"
	sed -e '1 s/\(^FROM\)/FROM --platform=\$$\{BUILDPLATFORM\}/; t' -e ' 1,// s//FROM --platform=\$$\{BUILDPLATFORM\}/' Dockerfile > Dockerfile.cross
	- $(CONTAINER_TOOL) buildx create --name telemetryflow-operator-builder
	$(CONTAINER_TOOL) buildx use telemetryflow-operator-builder
	- $(CONTAINER_TOOL) buildx build --push --platform=$(PLATFORMS) --tag ${IMG} -f Dockerfile.cross .
	- $(CONTAINER_TOOL) buildx rm telemetryflow-operator-builder
	rm Dockerfile.cross
	@echo "$(GREEN)Multi-platform build complete$(NC)"

## Run Docker container
docker-run:
	@echo "$(GREEN)Running operator Docker container...$(NC)"
	$(CONTAINER_TOOL) run -it --rm ${IMG}

# =============================================================================
# Clean Target
# =============================================================================

## Clean build artifacts
clean:
	@echo "$(GREEN)Cleaning build artifacts...$(NC)"
	@$(GOCLEAN)
	@rm -rf $(BUILD_DIR)
	@rm -f cover.out coverage.html coverage-summary.txt
	@echo "$(GREEN)Clean complete$(NC)"

# =============================================================================
# Tool Installation Targets
# =============================================================================

$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Download kustomize locally if necessary
kustomize: $(KUSTOMIZE)
$(KUSTOMIZE): $(LOCALBIN)
	@test -s $(LOCALBIN)/kustomize || \
	GOBIN=$(LOCALBIN) go install sigs.k8s.io/kustomize/kustomize/v5@$(KUSTOMIZE_VERSION)

## Download controller-gen locally if necessary
controller-gen: $(CONTROLLER_GEN)
$(CONTROLLER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/controller-gen && $(LOCALBIN)/controller-gen --version | grep -q $(CONTROLLER_TOOLS_VERSION) || \
	GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION)

## Download setup-envtest locally if necessary
envtest: $(ENVTEST)
$(ENVTEST): $(LOCALBIN)
	test -s $(LOCALBIN)/setup-envtest || \
	GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

## Download golangci-lint locally if necessary
golangci-lint: $(GOLANGCI_LINT)
$(GOLANGCI_LINT): $(LOCALBIN)
	test -s $(LOCALBIN)/golangci-lint && $(LOCALBIN)/golangci-lint --version | grep -q $(GOLANGCI_LINT_VERSION) || \
	GOBIN=$(LOCALBIN) go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
