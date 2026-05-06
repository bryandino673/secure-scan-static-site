# Secure-Scan Static Site

A high-security static website deployment pipeline designed with a DevSecOps mindset. This project refuses to ship if any "High" or "Critical" security vulnerabilities are detected in the container image or infrastructure code.

##  Architecture

### CI/CD Pipeline Flow

```mermaid
graph TD
    A[Push to Main] --> B{CI/CD Pipeline}
    subgraph "Security Gates"
        B --> C[Trivy: Image Scan]
        B --> D[Checkov: IaC Scan]
    end
    C -->|Pass| E{Deployment}
    D -->|Pass| E
    C -->|Fail| F[Pipeline Blocked]
    D -->|Fail| F
    E --> G[Kubernetes Cluster]
    G --> H[Nginx Ingress]
    H --> I[https://secure-scan.local]
```

### System Architecture

```mermaid
flowchart TB
    subgraph "Development"
        DEV[Developer] --> PUSH[Git Push]
    end
    
    subgraph "CI/CD Pipeline"
        PUSH --> TRIGGER[GitHub Actions Trigger]
        TRIGGER --> BUILD[Build Docker Image]
        BUILD --> TRIVY[Trivy Scan]
        TRIVY --> CHECKOV[Checkov Scan]
    end
    
    subgraph "Security Gates"
        TRIVY --> GATE1{Vulnerabilities?}
        CHECKOV --> GATE2{Misconfigurations?}
        GATE1 -->|HIGH/CRITICAL| BLOCK[❌ Block Pipeline]
        GATE2 -->|Failed Checks| BLOCK
        GATE1 -->|Pass| PASS1[✅ Pass]
        GATE2 -->|Pass| PASS2[✅ Pass]
    end
    
    subgraph "Deployment"
        PASS1 --> DEPLOY{Both Pass?}
        PASS2 --> DEPLOY
        DEPLOY -->|Yes| KIND[Create K8s Cluster using kind]
        KIND --> INGRESS[Install Nginx Ingress Controller]
        INGRESS --> TF[Terraform Apply]
        TF --> K8S[Kubernetes Resources]
    end
    
    subgraph "Runtime"
        K8S --> NS[Namespace: secure-scan]
        NS --> DEPLOYMENT[Deployment: secure-site]
        DEPLOYMENT --> POD[Pod: nginx container]
        POD --> SVC[Service: ClusterIP]
        SVC --> ING[Ingress: secure-scan.local]
    end
    
    style BLOCK fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style DEPLOY fill:#51cf66,stroke:#2f9e44,color:#fff
```

### Kubernetes Resource Flow

```mermaid
flowchart LR
    subgraph "External"
        CLIENT[Client Browser]
    end
    
    subgraph "Kubernetes Cluster"
        ING[Ingress Controller - nginx]
        SVC[Service - ClusterIP:80]
        POD[Pod - nginx:alpine]
    end
    
    CLIENT -->|secure-scan.local| ING
    ING --> SVC
    SVC --> POD
    
    subgraph "Security Context"
        POD --> SEC[runAsNonRoot: true, readOnlyRootFS: true, capabilities: drop ALL]
    end
```

### Security Scanning Pipeline

```mermaid
flowchart TB
    subgraph "Trivy Scan"
        IMG[Docker Image] --> SCAN1[Vulnerability DB]
        SCAN1 --> CVE[CVE Database]
        CVE --> SEV1[Severity Check]
        SEV1 -->|HIGH/CRITICAL| FAIL1[❌ Fail]
        SEV1 -->|Pass| PASS1[✅ Pass]
    end
    
    subgraph "Checkov Scan"
        TF[Terraform Files] --> SCAN2[Policy Engine]
        SCAN2 --> POL[1000+ Policies]
        POL --> SEV2[Policy Check]
        SEV2 -->|Failed| FAIL2[❌ Fail]
        SEV2 -->|Pass| PASS2[✅ Pass]
    end
    
    PASS1 --> DEPLOY[Deploy]
    PASS2 --> DEPLOY
    
    style FAIL1 fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style FAIL2 fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style DEPLOY fill:#51cf66,stroke:#2f9e44,color:#fff
```

### Container Security Architecture

```mermaid
flowchart TB
    subgraph "Docker Image"
        BASE[nginx:alpine]
        BASE --> PKG[apk upgrade]
        PKG --> USER[Non-root User - UID 101]
    end
    
    subgraph "Security Context"
        USER --> ROOT[runAsNonRoot: true]
        USER --> FS[readOnlyRootFilesystem: true]
        USER --> ESC[allowPrivilegeEscalation: false]
        USER --> CAP[capabilities: drop ALL]
    end
    
    subgraph "Writable Volumes"
        FS --> TMP[emptyDir: /tmp]
        FS --> CACHE[emptyDir: /var/cache/nginx]
        FS --> RUN[emptyDir: /var/run]
    end
    
    style BASE fill:#339af0,stroke:#1971c2,color:#fff
    style USER fill:#51cf66,stroke:#2f9e44,color:#fff
    style ROOT fill:#51cf66,stroke:#2f9e44,color:#fff
    style FS fill:#51cf66,stroke:#2f9e44,color:#fff
    style ESC fill:#51cf66,stroke:#2f9e44,color:#fff
    style CAP fill:#51cf66,stroke:#2f9e44,color:#fff
```

### Network Architecture

```mermaid
flowchart LR
    subgraph "External"
        CLIENT[Client Browser]
    end
    
    subgraph "kind Cluster"
        subgraph "ingress-nginx Namespace"
            ING[Ingress Controller - NodePort 80/443]
        end
        
        subgraph "secure-scan Namespace"
            SVC[Service - ClusterIP 80]
            POD[Pod - Container 80]
        end
    end
    
    CLIENT -->|secure-scan.local| ING
    ING -->|Route| SVC
    SVC -->|Select| POD
    
    style CLIENT fill:#ffd43b,stroke:#fab005
    style ING fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style SVC fill:#339af0,stroke:#1971c2,color:#fff
    style POD fill:#51cf66,stroke:#2f9e44,color:#fff
```

### CI/CD Pipeline Architecture

```mermaid
flowchart TB
    subgraph "Phase 1: Security Scan"
        A1[Checkout] --> A2[Build Image]
        A2 --> A3[Trivy Scan]
        A3 --> A4[Checkov scan]
    end
    
    subgraph "Phase 2: Deploy"
        A4 -->|Pass| B1[Checkout]
        B1 --> B2[Build Image]
        B2 --> B3[Create kind Cluster]
        B3 --> B4[Install Ingress]
        B4 --> B5[Load Image]
        B5 --> B6[Terraform Init]
        B6 --> B7[Terraform Plan]
        B7 --> B8[Terraform Apply]
    end
    
    subgraph "Phase 3: Verify"
        B8 --> C1[Check Pods]
        C1 --> C2[Check Services]
        C2 --> C3[Check Ingress]
        C3 --> C4[Log Results]
    end
    
    A3 -->|Fail| BLOCK1[❌ Pipeline Blocked]
    A4 -->|Fail| BLOCK2[❌ Pipeline Blocked]
    
    style BLOCK1 fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style BLOCK2 fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style A3 fill:#ffd43b,stroke:#fab005
    style A4 fill:#ffd43b,stroke:#fab005
    style B8 fill:#51cf66,stroke:#2f9e44,color:#fff
```

##  Tech Stack
- **Site**: HTML5 + Vanilla CSS (Glassmorphism design)
- **Server**: Nginx (Alpine-based, non-root)
- **Infrastructure**: Terraform (Kubernetes Provider)
- **CI/CD**: GitHub Actions
- **Security Scanners**:
    - [Trivy](https://github.com/aquasecurity/trivy): Vulnerability scanner for container images.
    - [Checkov](https://github.com/bridgecrewio/checkov): Static analysis for infrastructure as code.
    - [kind](https://kind.sigs.k8s.io/): Kubernetes in Docker for CI/CD testing.

##  Security Features
### Container Hardening
- **Rootless**: Nginx runs as non-root user `nginx` (UID 101).
- **Immutable**: Pipeline pins images to specific SHAs/Digests.
- **Minimal**: Uses Alpine Linux to reduce attack surface.
- **Updated**: Automatic `apk upgrade` during build to mitigate CVEs.

### Infrastructure Hardening
- **Read-Only FS**: Containers run with a read-only root filesystem.
- **Resource Limits**: Enforced CPU and Memory quotas to prevent DoS.
- **Probes**: Configured Liveness and Readiness probes for health monitoring.
- **No Privilege**: Dropped all Linux capabilities and blocked privilege escalation.
- **Writable Volumes**: `emptyDir` volumes for `/tmp`, `/var/cache/nginx`, `/var/run` to support nginx runtime needs.

##  Getting Started

### Local Development
1. **Build the Image**:
   ```bash
   docker build -t secure-scan-site:latest .
   ```

2. **Run Security Scans**:
   ```bash
   # Image Scan
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image secure-scan-site:latest

   # Terraform Scan
   docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform
   ```

3. **Deploy Locally**:
   ```bash
   # Create kind cluster
   kind create cluster --name secure-scan-cluster
   
   # Load image
   kind load docker-image secure-scan-site:latest --name secure-scan-cluster
   
   # Install ingress
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   
   # Deploy with Terraform
   cd terraform
   terraform init
   terraform apply -auto-approve -var="image_name=secure-scan-site:latest"
   ```

4. **Access the Application**:
   ```bash
   # Port-forward to the deployment (quickest way to access)
   # Note: Container listens on port 8080 (non-root user can't bind to port 80)
   kubectl port-forward -n secure-scan deployment/secure-site 8080:8080 
   
   # Then open http://localhost:8080 in your browser
   ```

   ```bash
   # Or access via Ingress (requires local DNS or /etc/hosts entry)
   # Add to /etc/hosts: 127.0.0.1 secure-scan.local
   kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 80:80 &
   
   # Then open http://secure-scan.local
   ```

### Image Pull Policy Note

When using `kind load docker-image`, the image exists locally in the kind cluster but not in a remote registry. The Terraform config uses `image_pull_policy = "Never"` to ensure Kubernetes uses the local image instead of trying to pull from Docker Hub.

### View Running Services

```bash
# Check all resources in the secure-scan namespace
kubectl get all -n secure-scan

# Check pods and their status
kubectl get pods -n secure-scan

# Check services
kubectl get svc -n secure-scan

# Check ingress
kubectl get ingress -n secure-scan

# View pod logs
kubectl logs -n secure-scan deployment/secure-site

# View pod logs (follow mode - real-time)
kubectl logs -n secure-scan deployment/secure-site -f

# Describe a pod for detailed status/events
kubectl describe pod -n secure-scan -l app=secure-site
```

### Destroy Resources (Cleanup)

**Important:** Always clean up when you're done to free resources!

```bash
# Step 1: Destroy Terraform-managed resources (namespace, deployment, service, ingress)
cd terraform
terraform destroy -auto-approve -var="image_name=secure-scan-site:latest"

# Step 2: Delete the entire kind cluster (removes everything including ingress-nginx namespace)
kind delete cluster --name secure-scan-cluster
```

> **Note:** `terraform destroy` removes the `secure-scan` namespace and all resources inside it.
> `kind delete cluster` removes the entire cluster including the `ingress-nginx` namespace.
> No need to manually delete namespaces with `kubectl` - Terraform and kind handle cleanup.

### Deployment
The project is configured to deploy via GitHub Actions. Only if all security gates pass will Terraform apply the changes to your Kubernetes cluster.

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [Overview](docs/01-overview.md) | Project purpose, goals, and philosophy |
| [Architecture](docs/02-architecture.md) | System architecture with diagrams |
| [Security Scanning](docs/03-security-scanning.md) | Trivy and Checkov deep dive |
| [Terraform](docs/04-terraform.md) | Infrastructure as code explained |
| [Workflow](docs/05-workflow.md) | CI/CD pipeline breakdown |
| [Commands](docs/06-commands.md) | Complete command reference |
| [Troubleshooting](docs/07-troubleshooting.md) | Common issues and solutions |

