# Commands Reference

This document provides a comprehensive reference for all commands used in this project.

---

## Docker Commands

### Build Image

```bash
# Build with default tag
docker build -t secure-scan-site:latest .

# Build with Git SHA tag
docker build -t secure-scan-site:$(git rev-parse HEAD) .

# Build with specific version
docker build -t secure-scan-site:1.0.0 .
```

### Run Container Locally

```bash
# Run in foreground
docker run -p 8080:80 secure-scan-site:latest

# Run in background
docker run -d -p 8080:80 secure-scan-site:latest

# Run with specific tag
docker run -d -p 8080:80 secure-scan-site:$(git rev-parse HEAD)
```

### Inspect Image

```bash
# View image layers
docker history secure-scan-site:latest

# Inspect image metadata
docker inspect secure-scan-site:latest

# View running containers
docker ps

# View container logs
docker logs <container_id>
```

### Clean Up

```bash
# Remove all unused images
docker image prune -a

# Remove specific image
docker rmi secure-scan-site:latest

# Stop all containers
docker stop $(docker ps -q)
```

---

## Trivy Commands

### Scan Docker Image

```bash
# Basic scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image secure-scan-site:latest

# Scan with specific severity
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL secure-scan-site:latest

# Scan with JSON output
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --format json secure-scan-site:latest

# Scan ignoring unfixed vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --ignore-unfixed secure-scan-site:latest
```

### Scan Filesystem

```bash
# Scan current directory
trivy fs .

# Scan specific directory
trivy fs ./terraform
```

### Install Trivy Locally

```bash
# macOS
brew install aquasecurity/trivy/trivy

# Linux (Debian/Ubuntu)
sudo apt-get install wget apt-transport-https gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Using go
go install github.com/aquasecurity/trivy@latest
```

---

## Checkov Commands

### Scan Terraform Files

```bash
# Basic scan
checkov -d ./terraform

# Scan with specific framework
checkov -d ./terraform --framework terraform

# Scan with JSON output
checkov -d ./terraform --output json

# Scan specific file
checkov -f ./terraform/main.tf

# Skip specific checks
checkov -d ./terraform --skip-check CKV_K8S_10
```

### Docker-based Scan

```bash
# Run Checkov in Docker
docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform

# Run with specific output format
docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform --output json
```

### Install Checkov Locally

```bash
# Using pip
pip install checkov

# Using pipx
pipx install checkov
```

---

## kind Commands

### Create Cluster

```bash
# Create default cluster
kind create cluster

# Create named cluster
kind create cluster --name secure-scan-cluster

# Create cluster with specific Kubernetes version
kind create cluster --name secure-scan-cluster --image kindest/node:v1.28.0
```

### Delete Cluster

```bash
# Delete named cluster
kind delete cluster --name secure-scan-cluster

# Delete default cluster
kind delete cluster
```

### Load Image

```bash
# Load Docker image into kind
kind load docker-image secure-scan-site:latest --name secure-scan-cluster

# Load from tar archive
kind load image-archive image.tar --name secure-scan-cluster
```

### Get Clusters

```bash
# List all kind clusters
kind get clusters

# Get kubeconfig
kind get kubeconfig --name secure-scan-cluster
```

### Install kind

```bash
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Using go
go install sigs.k8s.io/kind@latest
```

---

## kubectl Commands

### Cluster Information

```bash
# Get cluster info
kubectl cluster-info

# Get nodes
kubectl get nodes

# Get namespaces
kubectl get namespaces
```

### View Resources

```bash
# Get all resources in namespace
kubectl get all -n secure-scan

# Get specific resource types
kubectl get pods -n secure-scan
kubectl get deployments -n secure-scan
kubectl get services -n secure-scan
kubectl get ingress -n secure-scan

# Get detailed information
kubectl describe pod <pod-name> -n secure-scan
kubectl describe deployment secure-site -n secure-scan

# Get resource in YAML format
kubectl get pod <pod-name> -n secure-scan -o yaml
```

### Logs

```bash
# View pod logs
kubectl logs <pod-name> -n secure-scan

# Follow logs in real-time
kubectl logs -f <pod-name> -n secure-scan

# View logs from specific container
kubectl logs <pod-name> -c secure-site -n secure-scan
```

### Execute Commands

```bash
# Shell into container
kubectl exec -it <pod-name> -n secure-scan -- sh

# Run command in container
kubectl exec <pod-name> -n secure-scan -- ls /usr/share/nginx/html
```

### Port Forwarding

```bash
# Forward local port to service
kubectl port-forward svc/secure-site-service 8080:80 -n secure-scan

# Forward to specific pod
kubectl port-forward <pod-name> 8080:80 -n secure-scan
```

### Delete Resources

```bash
# Delete namespace (and all resources in it)
kubectl delete namespace secure-scan

# Delete specific resource
kubectl delete pod <pod-name> -n secure-scan
kubectl delete deployment secure-site -n secure-scan
```

---

## Terraform Commands

### Initialize

```bash
# Initialize Terraform
cd terraform
terraform init

# Initialize with upgrade
terraform init -upgrade
```

### Plan

```bash
# Show planned changes
terraform plan

# Plan with variable
terraform plan -var="image_name=secure-scan-site:latest"

# Plan with variable file
terraform plan -var-file="variables.tfvars"
```

### Apply

```bash
# Apply changes (interactive)
terraform apply

# Apply with auto-approve
terraform apply -auto-approve

# Apply with variable
terraform apply -var="image_name=secure-scan-site:latest"

# Apply with variable file
terraform apply -var-file="variables.tfvars"
```

### Destroy

```bash
# Destroy all resources
terraform destroy

# Destroy with auto-approve
terraform destroy -auto-approve
```

### State Management

```bash
# Show current state
terraform state list

# Show specific resource
terraform state show kubernetes_deployment.site

# Import existing resource
terraform import kubernetes_namespace.secure_scan secure-scan
```

### Validate

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt

# Format recursively
terraform fmt -recursive
```

---

## Git Commands

### Branch Management

```bash
# Create new branch
git checkout -b fix/ci-kubernetes-deployment

# Push branch to remote
git push -u origin fix/ci-kubernetes-deployment

# Switch to main
git checkout main

# Merge branch
git merge fix/ci-kubernetes-deployment
```

### Commit

```bash
# Stage all changes
git add .

# Commit with message
git commit -m "fix: add Kubernetes cluster setup for CI/CD deployment"

# Push to remote
git push origin fix/ci-kubernetes-deployment
```

---

## Complete Workflow Commands

### Local Development

```bash
# 1. Build image
docker build -t secure-scan-site:latest .

# 2. Run Trivy scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL secure-scan-site:latest

# 3. Run Checkov scan
docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform

# 4. Create kind cluster
kind create cluster --name secure-scan-cluster

# 5. Load image
kind load docker-image secure-scan-site:latest --name secure-scan-cluster

# 6. Install ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 7. Deploy with Terraform
cd terraform
terraform init
terraform apply -auto-approve -var="image_name=secure-scan-site:latest"

# 8. Access site
kubectl port-forward svc/secure-site-service 8080:80 -n secure-scan
curl http://localhost:8080

# 9. Clean up
cd ..
terraform destroy -auto-approve
kind delete cluster --name secure-scan-cluster
```

---

## Quick Reference Table

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `docker build` | Build container image | Before scanning or deploying |
| `trivy image` | Scan for vulnerabilities | Before deployment |
| `checkov -d` | Scan IaC for misconfigurations | Before deployment |
| `kind create cluster` | Create local K8s cluster | For testing/deployment |
| `kubectl get all` | View all resources | For debugging |
| `terraform apply` | Create K8s resources | For deployment |
| `terraform destroy` | Remove all resources | For cleanup |
| `kubectl port-forward` | Access service locally | For testing |