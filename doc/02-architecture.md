# Architecture

## System Overview

The Secure-Scan Static Site follows a **security-first architecture** where every component is designed with security gates.

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
        DEPLOY -->|Yes| KIND[Create K8s Cluster<br/>(kind)]
        KIND --> INGRESS[Install Ingress<br/>Controller]
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

## Component Architecture

### 1. Source Code Components

```mermaid
flowchart LR
    subgraph "Static Site"
        HTML[index.html] --> CSS[Embedded CSS]
        CSS --> STYLE[Glassmorphism Design]
    end
    
    subgraph "Container"
        DOCKER[Dockerfile] --> BASE[nginx:alpine]
        BASE --> USER[Non-root: nginx]
        BASE --> FS[Read-only Filesystem]
    end
    
    subgraph "Infrastructure"
        TF[main.tf] --> NS[Namespace]
        TF --> DEPLOY[Deployment]
        TF --> SVC[Service]
        TF --> ING[Ingress]
    end
    
    HTML --> DOCKER
    DOCKER --> TF
```

### 2. CI/CD Pipeline Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant Actions as GitHub Actions
    participant Trivy as Trivy Scanner
    participant Checkov as Checkov Scanner
    participant Kind as kind Cluster
    participant TF as Terraform
    participant K8s as Kubernetes
    
    Dev->>GH: git push
    GH->>Actions: Trigger workflow
    
    Actions->>Actions: Build Docker Image
    
    Actions->>Trivy: Scan Image
    Trivy->>Trivy: Check CVE Database
    alt HIGH/CRITICAL Found
        Trivy->>Actions: Exit Code 1
        Actions->>GH: ❌ Pipeline Failed
    else No Issues
        Trivy->>Actions: Exit Code 0
    end
    
    Actions->>Checkov: Scan Terraform
    Checkov->>Checkov: Check Policies
    alt Misconfiguration Found
        Checkov->>Actions: Exit Code 1
        Actions->>GH: ❌ Pipeline Failed
    else No Issues
        Checkov->>Actions: Exit Code 0
    end
    
    Actions->>Kind: Create Cluster
    Actions->>Kind: Load Docker Image
    Actions->>TF: terraform apply
    TF->>K8s: Create Namespace
    TF->>K8s: Create Deployment
    TF->>K8s: Create Service
    TF->>K8s: Create Ingress
    
    Actions->>GH: ✅ Pipeline Success
```

### 3. Kubernetes Resources

```mermaid
flowchart TB
    subgraph "Kubernetes Cluster"
        subgraph "Namespace: secure-scan"
            ING[Ingress<br/>secure-site-ingress]
            SVC[Service<br/>secure-site-service<br/>ClusterIP:80]
            
            subgraph "Deployment: secure-site"
                POD1[Pod]
                subgraph "Container"
                    NGINX[nginx container<br/>Port: 80<br/>Non-root: UID 101]
                    NGINX --> SEC[Security Context:<br/>- runAsNonRoot: true<br/>- readOnlyRootFilesystem: true<br/>- allowPrivilegeEscalation: false<br/>- capabilities: drop ALL]
                end
            end
        end
    end
    
    ING --> SVC
    SVC --> POD1
    
    subgraph "External"
        CLIENT[Client Browser]
        CLIENT -->|secure-scan.local| ING
    end
```

## Security Architecture

### Container Security

```mermaid
flowchart TB
    subgraph "Docker Image Security"
        BASE[nginx:alpine] --> MINIMAL[Minimal Base Image]
        MINIMAL --> PKG[Package Upgrade<br/>apk upgrade]
        PKG --> USER[Non-root User<br/>UID 101]
        USER --> FS[Read-only Filesystem]
        FS --> CAP[Drop Capabilities<br/>ALL]
        CAP --> ESC[No Privilege<br/>Escalation]
    end
    
    style BASE fill:#339af0,stroke:#1971c2,color:#fff
    style USER fill:#51cf66,stroke:#2f9e44,color:#fff
    style FS fill:#51cf66,stroke:#2f9e44,color:#fff
    style CAP fill:#51cf66,stroke:#2f9e44,color:#fff
    style ESC fill:#51cf66,stroke:#2f9e44,color:#fff
```

### Pipeline Security Gates

```mermaid
flowchart LR
    subgraph "Trivy Scan"
        IMG[Docker Image] --> SCAN1[Vulnerability DB]
        SCAN1 --> CVE[CVE Database]
        CVE --> SEV1[Severity Check]
        SEV1 -->|HIGH/CRITICAL| FAIL1[❌ Fail]
        SEV1 -->|LOW/MEDIUM| PASS1[✅ Pass]
    end
    
    subgraph "Checkov Scan"
        TF[Terraform Files] --> SCAN2[Policy Engine]
        SCAN2 --> POL[1000+ Policies]
        POL --> SEV2[Policy Check]
        SEV2 -->|Failed| FAIL2[❌ Fail]
        SEV2 -->|Passed| PASS2[✅ Pass]
    end
    
    PASS1 --> DEPLOY[Deploy]
    PASS2 --> DEPLOY
```

## Data Flow

### Request Flow

```mermaid
sequenceDiagram
    participant User as User
    participant Ingress as Nginx Ingress
    participant Service as Service
    participant Pod as Pod (nginx)
    participant FS as Filesystem
    
    User->>Ingress: GET / HTTP/1.1<br/>Host: secure-scan.local
    Ingress->>Service: Route to service:80
    Service->>Pod: Load balance to pod
    Pod->>FS: Read /usr/share/nginx/html/index.html
    FS->>Pod: Return HTML content
    Pod->>Service: HTTP 200 + HTML
    Service->>Ingress: Response
    Ingress->>User: HTTP 200 + HTML
```

## Infrastructure Components

### GitHub Actions Runner

```mermaid
flowchart TB
    subgraph "GitHub Actions Runner (ubuntu-latest)"
        DOCKER[Docker Engine]
        KIND[kind Cluster]
        KUBECTL[kubectl]
        TF[Terraform]
        
        DOCKER --> |load image| KIND
        KIND --> |kubeconfig| KUBECTL
        KUBECTL --> |apply| TF
    end
```

### kind Cluster

```mermaid
flowchart TB
    subgraph "kind: secure-scan-cluster"
        CONTROL[Control Plane]
        NODE[Worker Node]
        
        CONTROL --> API[API Server<br/>:6443]
        CONTROL --> ETCD[etcd]
        CONTROL --> SCHED[Scheduler]
        
        NODE --> KUBELET[kubelet]
        NODE --> PROXY[kube-proxy]
        NODE --> PODS[Pods]
        
        subgraph "Ingress"
            NGINX_ING[nginx-ingress-controller]
        end
    end
```

## File Structure Explained

| File | Purpose | Security Relevance |
|------|---------|-------------------|
| `Dockerfile` | Defines container image | Non-root user, read-only FS |
| `site/index.html` | Static website content | No server-side code = smaller attack surface |
| `terraform/main.tf` | Kubernetes resources | Security contexts, network policies |
| `terraform/variables.tf` | Input variables | Configurable image reference |
| `.github/workflows/security-scan.yml` | CI/CD pipeline | Security gates, automated scanning |

## Network Architecture

```mermaid
flowchart TB
    subgraph "External Network"
        CLIENT[Client]
    end
    
    subgraph "Kubernetes Network"
        INGRESS[Ingress Controller<br/>Port 80/443]
        SERVICE[Service<br/>ClusterIP Port 80]
        POD[Pod<br/>Container Port 80]
    end
    
    CLIENT -->|HTTP| INGRESS
    INGRESS -->|secure-scan.local| SERVICE
    SERVICE -->|ClusterIP| POD
    
    subgraph "Security Boundaries"
        BOUNDARY1[Network Policy<br/>(Future Enhancement)]
    end
```

## Next Steps

- [Security Scanning](03-security-scanning.md) - Learn about Trivy and Checkov
- [Terraform](04-terraform.md) - Understand infrastructure as code
- [Workflow](05-workflow.md) - Explore the CI/CD pipeline