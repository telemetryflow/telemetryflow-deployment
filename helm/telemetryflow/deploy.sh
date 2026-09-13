#!/bin/bash
##############################################################################
# TelemetryFlow Helm Deployment Script for RKE2
# Version: 1.0.0
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="observability"
RELEASE_NAME="telemetryflow"
ENVIRONMENT="${1:-demo}" # demo | staging | production

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TelemetryFlow Deployment Script${NC}"
echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
        exit 1
    fi

    # Check helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}helm not found. Please install helm 3.x.${NC}"
        exit 1
    fi

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Cannot connect to Kubernetes cluster. Check your kubeconfig.${NC}"
        exit 1
    fi

    # Check NGINX Ingress Controller
    if ! kubectl get ingressclass nginx &> /dev/null; then
        echo -e "${YELLOW}Warning: NGINX ingress class not found. Make sure NGINX Ingress Controller is installed.${NC}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo -e "${GREEN}✓ Prerequisites check passed${NC}\n"
}

# Function to create namespace
create_namespace() {
    echo -e "${YELLOW}Creating namespace...${NC}"

    if kubectl get namespace $NAMESPACE &> /dev/null; then
        echo -e "${GREEN}✓ Namespace $NAMESPACE already exists${NC}\n"
    else
        kubectl create namespace $NAMESPACE
        echo -e "${GREEN}✓ Namespace $NAMESPACE created${NC}\n"
    fi
}

# Function to generate secrets
generate_secrets() {
    echo -e "${YELLOW}Generating secrets...${NC}"

    # Check if secrets already exist
    if kubectl get secret tfo-backend-secrets -n $NAMESPACE &> /dev/null; then
        echo -e "${YELLOW}Secrets already exist. Skipping generation.${NC}"
        read -p "Do you want to regenerate secrets? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✓ Using existing secrets${NC}\n"
            return
        fi
        echo -e "${YELLOW}Deleting existing secrets...${NC}"
        kubectl delete secret tfo-backend-secrets tfo-postgresql-secret tfo-clickhouse-secret tfo-redis-secret tfo-nats-secret -n $NAMESPACE 2>/dev/null || true
    fi

    # Generate strong passwords
    PG_PASSWORD=$(openssl rand -base64 32)
    CH_PASSWORD=$(openssl rand -base64 32)
    REDIS_PASSWORD=$(openssl rand -base64 32)
    JWT_ACCESS_SECRET=$(openssl rand -base64 32)
    JWT_REFRESH_SECRET=$(openssl rand -base64 32)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    MFA_KEY=$(openssl rand -base64 32)
    NATS_PASSWORD=$(openssl rand -base64 32)

    # Create secrets
    kubectl create secret generic tfo-backend-secrets \
        --from-literal=DATABASE_PASSWORD="$PG_PASSWORD" \
        --from-literal=CLICKHOUSE_PASSWORD="$CH_PASSWORD" \
        --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
        --from-literal=JWT_ACCESS_TOKEN_SECRET="$JWT_ACCESS_SECRET" \
        --from-literal=JWT_REFRESH_TOKEN_SECRET="$JWT_REFRESH_SECRET" \
        --from-literal=ENCRYPTION_KEY="$ENCRYPTION_KEY" \
        --from-literal=MFA_ENCRYPTION_KEY="$MFA_KEY" \
        -n $NAMESPACE

    kubectl create secret generic tfo-postgresql-secret \
        --from-literal=postgres-password="$PG_PASSWORD" \
        --from-literal=password="$PG_PASSWORD" \
        --from-literal=replication-password="$PG_PASSWORD" \
        -n $NAMESPACE

    kubectl create secret generic tfo-clickhouse-secret \
        --from-literal=password="$CH_PASSWORD" \
        -n $NAMESPACE

    kubectl create secret generic tfo-redis-secret \
        --from-literal=redis-password="$REDIS_PASSWORD" \
        -n $NAMESPACE

    kubectl create secret generic tfo-nats-secret \
        --from-literal=nats-password="$NATS_PASSWORD" \
        -n $NAMESPACE

    echo -e "${GREEN}✓ Secrets generated and created${NC}\n"

    # Save passwords to file (optional)
    if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "production" || "$ENVIRONMENT" == "staging" ]]; then
        echo -e "${YELLOW}Saving passwords to secrets.txt (KEEP THIS FILE SAFE!)${NC}"
        cat > secrets.txt <<EOF
# TelemetryFlow Production Secrets
# Generated: $(date)
# WARNING: Keep this file secure and do not commit to git!

DATABASE_PASSWORD=$PG_PASSWORD
CLICKHOUSE_PASSWORD=$CH_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
NATS_PASSWORD=$NATS_PASSWORD
JWT_ACCESS_TOKEN_SECRET=$JWT_ACCESS_SECRET
JWT_REFRESH_TOKEN_SECRET=$JWT_REFRESH_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
MFA_ENCRYPTION_KEY=$MFA_KEY
EOF
        chmod 600 secrets.txt
        echo -e "${GREEN}✓ Passwords saved to secrets.txt${NC}\n"
    fi
}

# Function to deploy with Helm
deploy_helm() {
    echo -e "${YELLOW}Deploying TelemetryFlow with Helm...${NC}"

    # Layer order: chart values.yaml → values/tfo-<env>.yaml overlay
    BASE_VALUES="values.yaml"
    OVERLAY_DIR="../values/${ENVIRONMENT}"
    OVERLAY_VALUES="${OVERLAY_DIR}/tfo-${ENVIRONMENT}.yaml"

    HELM_VALUES_ARGS="--values $BASE_VALUES"
    if [[ ! -f "$OVERLAY_VALUES" ]]; then
        echo -e "${RED}Overlay values file not found: $OVERLAY_VALUES (env: demo|staging|production)${NC}"
        exit 1
    fi
    HELM_VALUES_ARGS="$HELM_VALUES_ARGS --values $OVERLAY_VALUES"
    echo -e "${YELLOW}Applying overlay: ${OVERLAY_VALUES}${NC}"

    if helm list -n $NAMESPACE | grep -q $RELEASE_NAME; then
        echo -e "${YELLOW}Release $RELEASE_NAME already exists. Upgrading...${NC}"
        helm upgrade $RELEASE_NAME . \
            --namespace $NAMESPACE \
            $HELM_VALUES_ARGS \
            --timeout 15m \
            --wait
        echo -e "${GREEN}✓ Helm upgrade completed${NC}\n"
    else
        echo -e "${YELLOW}Installing new release...${NC}"
        helm install $RELEASE_NAME . \
            --namespace $NAMESPACE \
            $HELM_VALUES_ARGS \
            --timeout 15m \
            --wait
        echo -e "${GREEN}✓ Helm install completed${NC}\n"
    fi
}

# Function to verify deployment
verify_deployment() {
    echo -e "${YELLOW}Verifying deployment...${NC}\n"

    echo -e "${YELLOW}Pods:${NC}"
    kubectl get pods -n $NAMESPACE
    echo

    echo -e "${YELLOW}Services:${NC}"
    kubectl get svc -n $NAMESPACE
    echo

    echo -e "${YELLOW}Ingress:${NC}"
    kubectl get ingress -n $NAMESPACE
    echo

    echo -e "${YELLOW}Waiting for all pods to be ready...${NC}"
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=telemetryflow -n $NAMESPACE --timeout=300s || true

    echo -e "${GREEN}✓ Deployment verification completed${NC}\n"
}

# Function to display access information
display_access_info() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}\n"

    # Get ingress hosts
    BACKEND_HOST=$(kubectl get ingress tfo-backend -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "api.telemetryflow.co.id")
    VIZ_HOST=$(kubectl get ingress tfo-viz -n $NAMESPACE -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "demo.telemetryflow.co.id")

    echo -e "${YELLOW}Access URLs:${NC}"
    echo -e "  Frontend: ${GREEN}https://${VIZ_HOST}${NC}"
    echo -e "  Backend API: ${GREEN}https://${BACKEND_HOST}${NC}"
    echo -e "  Health Check: ${GREEN}https://${BACKEND_HOST}/health${NC}"
    echo

    echo -e "${YELLOW}Default Credentials:${NC}"
    echo -e "  Email: ${GREEN}admin@telemetryflow.io${NC}"
    echo -e "  Password: ${GREEN}Admin@123${NC}"
    echo -e "  ${RED}⚠️  CHANGE THIS PASSWORD IMMEDIATELY!${NC}"
    echo

    echo -e "${YELLOW}Useful Commands:${NC}"
    echo -e "  Watch pods: ${GREEN}kubectl get pods -n $NAMESPACE -w${NC}"
    echo -e "  Backend logs: ${GREEN}kubectl logs -f deployment/tfo-backend -n $NAMESPACE${NC}"
    echo -e "  Collector logs: ${GREEN}kubectl logs -f deployment/tfo-collector -n $NAMESPACE${NC}"
    echo

    if [[ "$ENVIRONMENT" == "prod" ]]; then
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}IMPORTANT: Production Deployment${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}1. Passwords saved in secrets.txt - KEEP IT SAFE!${NC}"
        echo -e "${RED}2. Configure DNS records for:${NC}"
        echo -e "${RED}   - ${BACKEND_HOST}${NC}"
        echo -e "${RED}   - ${VIZ_HOST}${NC}"
        echo -e "${RED}3. Configure TLS certificates${NC}"
        echo -e "${RED}4. Change default admin password${NC}"
        echo -e "${RED}5. Review and adjust resource limits${NC}"
        echo -e "${RED}========================================${NC}"
    fi
}

# Main execution
main() {
    check_prerequisites
    create_namespace

    # demo/staging overlays create secrets via the chart (secrets.create: true).
    # production overlay expects pre-existing secrets (secrets.create: false).
    if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "production" ]]; then
        if ! kubectl get secret tfo-agent-secret -n $NAMESPACE &> /dev/null; then
            echo -e "${RED}tfo-agent-secret not found. Create it with valid TELEMETRYFLOW_API_KEY_ID / TELEMETRYFLOW_API_KEY_SECRET before deploying production.${NC}"
            exit 1
        fi
        generate_secrets
    fi

    deploy_helm
    verify_deployment
    display_access_info
}

# Run main function
main
