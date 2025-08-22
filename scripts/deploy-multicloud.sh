#!/bin/bash

# Multi-Cloud Deployment Script
# Deploys microservices to AWS EKS, Google GKE, and edge locations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure/terraform"
K8S_DIR="$PROJECT_ROOT/kubernetes"

# Cloud providers
DEPLOY_AWS="${DEPLOY_AWS:-true}"
DEPLOY_GCP="${DEPLOY_GCP:-true}"
DEPLOY_EDGE="${DEPLOY_EDGE:-true}"

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_message "$BLUE" "🔍 Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v gcloud >/dev/null 2>&1 || missing_tools+=("gcloud")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_message "$RED" "❌ Missing required tools: ${missing_tools[*]}"
        print_message "$YELLOW" "Please install missing tools and try again."
        exit 1
    fi
    
    print_message "$GREEN" "✅ All prerequisites met"
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    local cloud=$1
    local env_dir="$TERRAFORM_DIR/environments/$cloud"
    
    print_message "$BLUE" "🏗️  Deploying infrastructure for $cloud..."
    
    if [ ! -d "$env_dir" ]; then
        print_message "$YELLOW" "⚠️  Terraform environment for $cloud not found, skipping..."
        return
    fi
    
    cd "$env_dir"
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Plan deployment
    terraform plan -out=tfplan
    
    # Apply with auto-approve for CI/CD (remove for manual approval)
    if [ "$CI" = "true" ]; then
        terraform apply -auto-approve tfplan
    else
        print_message "$YELLOW" "Review the plan above. Deploy? (yes/no)"
        read -r response
        if [[ "$response" == "yes" ]]; then
            terraform apply tfplan
        else
            print_message "$YELLOW" "Skipping $cloud deployment"
            return
        fi
    fi
    
    # Save outputs
    terraform output -json > "$env_dir/outputs.json"
    
    print_message "$GREEN" "✅ Infrastructure deployed for $cloud"
}

# Function to configure kubectl for AWS EKS
configure_aws_kubectl() {
    print_message "$BLUE" "🔧 Configuring kubectl for AWS EKS..."
    
    local region="${AWS_REGION:-us-east-1}"
    local cluster_name="${AWS_CLUSTER_NAME:-microservices-eks}"
    
    aws eks update-kubeconfig \
        --region "$region" \
        --name "$cluster_name" \
        --alias "aws-eks"
    
    kubectl config use-context "aws-eks"
    
    print_message "$GREEN" "✅ kubectl configured for AWS EKS"
}

# Function to configure kubectl for Google GKE
configure_gcp_kubectl() {
    print_message "$BLUE" "🔧 Configuring kubectl for Google GKE..."
    
    local region="${GCP_REGION:-us-central1}"
    local cluster_name="${GCP_CLUSTER_NAME:-microservices-gke}"
    local project="${GCP_PROJECT_ID}"
    
    gcloud container clusters get-credentials "$cluster_name" \
        --region "$region" \
        --project "$project"
    
    kubectl config rename-context "gke_${project}_${region}_${cluster_name}" "gcp-gke"
    kubectl config use-context "gcp-gke"
    
    print_message "$GREEN" "✅ kubectl configured for Google GKE"
}

# Function to deploy microservices to a cluster
deploy_microservices() {
    local context=$1
    local cloud=$2
    
    print_message "$BLUE" "📦 Deploying microservices to $cloud..."
    
    kubectl config use-context "$context"
    
    # Create namespace if it doesn't exist
    kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Kubernetes manifests
    kubectl apply -f "$K8S_DIR/base/" -n microservices
    
    # Apply cloud-specific overlays if they exist
    if [ -d "$K8S_DIR/multi-cloud/$cloud" ]; then
        kubectl apply -f "$K8S_DIR/multi-cloud/$cloud/" -n microservices
    fi
    
    # Deploy with Helm if charts exist
    if [ -d "$PROJECT_ROOT/helm/microservices" ]; then
        helm upgrade --install microservices \
            "$PROJECT_ROOT/helm/microservices" \
            --namespace microservices \
            --values "$PROJECT_ROOT/helm/microservices/values-$cloud.yaml" \
            --create-namespace \
            --wait
    fi
    
    print_message "$GREEN" "✅ Microservices deployed to $cloud"
}

# Function to setup monitoring
setup_monitoring() {
    local context=$1
    local cloud=$2
    
    print_message "$BLUE" "📊 Setting up monitoring for $cloud..."
    
    kubectl config use-context "$context"
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Prometheus and Grafana
    if [ -d "$K8S_DIR/monitoring" ]; then
        kubectl apply -f "$K8S_DIR/monitoring/" -n monitoring
    fi
    
    # Deploy cloud-specific monitoring if exists
    if [ -d "$K8S_DIR/multi-cloud/$cloud/monitoring" ]; then
        kubectl apply -f "$K8S_DIR/multi-cloud/$cloud/monitoring/" -n monitoring
    fi
    
    print_message "$GREEN" "✅ Monitoring deployed for $cloud"
}

# Function to verify deployment
verify_deployment() {
    local context=$1
    local cloud=$2
    
    print_message "$BLUE" "🔍 Verifying deployment on $cloud..."
    
    kubectl config use-context "$context"
    
    # Check pod status
    local not_ready=$(kubectl get pods -n microservices --no-headers | grep -v "Running\|Completed" | wc -l)
    
    if [ "$not_ready" -eq 0 ]; then
        print_message "$GREEN" "✅ All pods are running on $cloud"
    else
        print_message "$YELLOW" "⚠️  Some pods are not ready on $cloud:"
        kubectl get pods -n microservices | grep -v "Running\|Completed"
    fi
    
    # Get service endpoints
    print_message "$BLUE" "Service endpoints on $cloud:"
    kubectl get svc -n microservices
}

# Function to setup cross-cloud networking
setup_cross_cloud_networking() {
    print_message "$BLUE" "🌐 Setting up cross-cloud networking..."
    
    cd "$TERRAFORM_DIR/modules/networking"
    
    terraform init -upgrade
    terraform plan -out=tfplan
    
    if [ "$CI" = "true" ]; then
        terraform apply -auto-approve tfplan
    else
        print_message "$YELLOW" "Review the networking plan. Deploy? (yes/no)"
        read -r response
        if [[ "$response" == "yes" ]]; then
            terraform apply tfplan
        fi
    fi
    
    print_message "$GREEN" "✅ Cross-cloud networking configured"
}

# Function to deploy edge configurations
deploy_edge() {
    print_message "$BLUE" "🌍 Deploying edge configurations..."
    
    cd "$TERRAFORM_DIR/modules/edge"
    
    terraform init -upgrade
    terraform plan -out=tfplan
    
    if [ "$CI" = "true" ]; then
        terraform apply -auto-approve tfplan
    else
        print_message "$YELLOW" "Review the edge deployment plan. Deploy? (yes/no)"
        read -r response
        if [[ "$response" == "yes" ]]; then
            terraform apply tfplan
        fi
    fi
    
    print_message "$GREEN" "✅ Edge deployment configured"
}

# Function to display deployment summary
display_summary() {
    print_message "$BLUE" "📋 Deployment Summary"
    echo "================================="
    
    if [ "$DEPLOY_AWS" = "true" ]; then
        print_message "$GREEN" "AWS EKS: Deployed"
        if [ -f "$TERRAFORM_DIR/environments/aws/outputs.json" ]; then
            local aws_endpoint=$(jq -r '.cluster_endpoint.value' "$TERRAFORM_DIR/environments/aws/outputs.json")
            echo "  Endpoint: $aws_endpoint"
        fi
    fi
    
    if [ "$DEPLOY_GCP" = "true" ]; then
        print_message "$GREEN" "Google GKE: Deployed"
        if [ -f "$TERRAFORM_DIR/environments/gcp/outputs.json" ]; then
            local gcp_endpoint=$(jq -r '.cluster_endpoint.value' "$TERRAFORM_DIR/environments/gcp/outputs.json")
            echo "  Endpoint: $gcp_endpoint"
        fi
    fi
    
    if [ "$DEPLOY_EDGE" = "true" ]; then
        print_message "$GREEN" "Edge CDN: Deployed"
        if [ -f "$TERRAFORM_DIR/modules/edge/outputs.json" ]; then
            local cdn_domain=$(jq -r '.cloudfront_domain_name.value' "$TERRAFORM_DIR/modules/edge/outputs.json")
            echo "  CDN Domain: $cdn_domain"
        fi
    fi
    
    echo "================================="
    print_message "$GREEN" "🎉 Multi-cloud deployment complete!"
}

# Main deployment flow
main() {
    print_message "$BLUE" "🚀 Starting Multi-Cloud Deployment"
    echo "================================="
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy to AWS
    if [ "$DEPLOY_AWS" = "true" ]; then
        print_message "$YELLOW" "☁️  Deploying to AWS..."
        deploy_infrastructure "aws"
        configure_aws_kubectl
        deploy_microservices "aws-eks" "aws"
        setup_monitoring "aws-eks" "aws"
        verify_deployment "aws-eks" "aws"
    fi
    
    # Deploy to GCP
    if [ "$DEPLOY_GCP" = "true" ]; then
        print_message "$YELLOW" "☁️  Deploying to Google Cloud..."
        deploy_infrastructure "gcp"
        configure_gcp_kubectl
        deploy_microservices "gcp-gke" "gcp"
        setup_monitoring "gcp-gke" "gcp"
        verify_deployment "gcp-gke" "gcp"
    fi
    
    # Setup cross-cloud networking
    if [ "$DEPLOY_AWS" = "true" ] && [ "$DEPLOY_GCP" = "true" ]; then
        setup_cross_cloud_networking
    fi
    
    # Deploy edge configurations
    if [ "$DEPLOY_EDGE" = "true" ]; then
        deploy_edge
    fi
    
    # Display summary
    display_summary
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --aws-only)
            DEPLOY_GCP="false"
            DEPLOY_EDGE="false"
            shift
            ;;
        --gcp-only)
            DEPLOY_AWS="false"
            DEPLOY_EDGE="false"
            shift
            ;;
        --no-edge)
            DEPLOY_EDGE="false"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --aws-only    Deploy only to AWS"
            echo "  --gcp-only    Deploy only to GCP"
            echo "  --no-edge     Skip edge deployment"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            print_message "$RED" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main deployment
main