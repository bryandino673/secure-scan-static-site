# GitHub Actions Workflow

This document explains the CI/CD pipeline defined in [`.github/workflows/security-scan.yml`](../.github/workflows/security-scan.yml).

## Workflow Overview

```mermaid
flowchart TB
    subgraph "Trigger"
        PUSH[Push to main]
        PR[Pull Request to main]
    end
    
    subgraph "Job 1: security-scan"
        CHECKOUT1[Checkout Code]
        BUILD1[Build Docker Image]
        TRIVY[Trivy Scan]
        CHECKOV[Checkov Scan]
        
        CHECKOUT1 --> BUILD1
        BUILD1 --> TRIVY
        TRIVY --> CHECKOV
    end
    
    subgraph "Job 2: deploy"
        CHECKOUT2[Checkout Code]
        BUILD2[Build Docker Image]
        KIND[Setup kind Cluster]
        INGRESS[Install Nginx Ingress]
        LOAD[Load Docker Image]
        TF_INIT[Terraform Init]
        TF_PLAN[Terraform Plan]
        TF_APPLY[Terraform Apply]
        
        CHECKOUT2 --> BUILD2
        BUILD2 --> KIND
        KIND --> INGRESS
        INGRESS --> LOAD
        LOAD --> TF_INIT
        TF_INIT --> TF_PLAN
        TF_PLAN --> TF_APPLY
    end
    
    PUSH --> CHECKOUT1
    PR --> CHECKOUT1
    
    CHECKOV -->|Pass| CHECKOUT2
    CHECKOV -->|Fail| BLOCK[Pipeline Failed]
    
    style BLOCK fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

---

## Workflow Structure

The workflow is split into **two jobs**:

| Job | Purpose | Runs On |
|-----|---------|---------|
| `security-scan` | Build image and run security scans | ubuntu-latest |
| `deploy` | Deploy to Kubernetes cluster | ubuntu-latest |

### Job Dependency

```mermaid
flowchart LR
    A[security-scan] -->|needs: security-scan| B[deploy]
    
    style A fill:#339af0,stroke:#1971c2,color:#fff
    style B fill:#51cf66,stroke:#2f9e44,color:#fff
```

The `deploy` job **only runs** if:
1. The `security-scan` job **passes**
2. The event is a **push to main** (not a PR)

---

## Triggers

```yaml
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
```

| Event | What Happens |
|-------|--------------|
| `push` to `main` | Both jobs run (scan + deploy) |
| `pull_request` to `main` | Only `security-scan` runs (no deploy) |

---

## Job 1: security-scan

### Step 1: Checkout Code

```yaml
- name: Checkout code
  uses: actions/checkout@v3
```

**Purpose**: Downloads the repository code to the runner.

### Step 2: Build Docker Image

```yaml
- name: Build Docker image
  run: docker build -t secure-scan-site:${{ github.sha }} .
```

**Purpose**: Builds the container image using the [`Dockerfile`](../Dockerfile).

**Image Tagging**: Uses the Git SHA (`${{ github.sha }}`) for unique identification.

```mermaid
flowchart LR
    A[Dockerfile] --> B[docker build]
    C[site/index.html] --> B
    B --> D[secure-scan-site:abc123]
```

### Step 3: Trivy Scan

```yaml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'secure-scan-site:${{ github.sha }}'
    format: 'table'
    exit-code: '1'
    ignore-unfixed: true
    vuln-type: 'os,library'
    severity: 'HIGH,CRITICAL'
```

**Purpose**: Scans the Docker image for known vulnerabilities.

| Parameter | Value | Effect |
|-----------|-------|--------|
| `image-ref` | Built image | What to scan |
| `format` | `table` | Human-readable output |
| `exit-code` | `1` | Fail pipeline on findings |
| `ignore-unfixed` | `true` | Skip unpatched CVEs |
| `vuln-type` | `os,library` | Scan OS and app dependencies |
| `severity` | `HIGH,CRITICAL` | Only block on serious issues |

**What happens if vulnerabilities are found?**

```mermaid
flowchart TB
    A[Trivy Scan] --> B{HIGH/CRITICAL?}
    B -->|Yes| C[Exit Code 1]
    B -->|No| D[Exit Code 0]
    C --> E[Pipeline Fails]
    D --> F[Continue to Checkov]
    
    style E fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style F fill:#51cf66,stroke:#2f9e44,color:#fff
```

### Step 4: Checkov Scan

```yaml
- name: Run Checkov action
  uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    framework: terraform
    soft_fail: false
    check: HIGH,CRITICAL
```

**Purpose**: Scans Terraform files for security misconfigurations.

| Parameter | Value | Effect |
|-----------|-------|--------|
| `directory` | `terraform/` | What to scan |
| `framework` | `terraform` | Type of IaC |
| `soft_fail` | `false` | Hard fail on issues |
| `check` | `HIGH,CRITICAL` | Only critical checks |

**What happens if misconfigurations are found?**

```mermaid
flowchart TB
    A[Checkov Scan] --> B{Failed Checks?}
    B -->|Yes| C[Exit Code 1]
    B -->|No| D[Exit Code 0]
    C --> E[Pipeline Fails]
    D --> F[Security Scan Job Complete]
    
    style E fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style F fill:#51cf66,stroke:#2f9e44,color:#fff
```

---

## Job 2: deploy

### Condition

```yaml
needs: security-scan
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

**This job only runs when:**
1. `security-scan` job **passed**
2. Event is a **push** (not PR)
3. Branch is **main**

### Step 1: Checkout Code

```yaml
- name: Checkout code
  uses: actions/checkout@v3
```

### Step 2: Build Docker Image

```yaml
- name: Build Docker image
  run: docker build -t secure-scan-site:${{ github.sha }} .
```

### Step 3: Setup kind Cluster

```yaml
- name: Setup Kubernetes cluster (kind)
  uses: helm/kind-action@v1
  with:
    cluster_name: secure-scan-cluster
```

**Purpose**: Creates a local Kubernetes cluster using Docker.

```mermaid
flowchart TB
    subgraph "GitHub Actions Runner"
        DOCKER[Docker Engine]
        KIND[kind Cluster]
    end
    
    DOCKER -->|Creates| KIND
    KIND --> API[API Server]
    KIND --> NODE[Worker Node]
    KIND --> KUBE[kubeconfig]
    
    style KIND fill:#339af0,stroke:#1971c2,color:#fff
```

**What kind does:**
- Creates a Kubernetes cluster inside Docker containers
- Generates `~/.kube/config` automatically
- Sets context to `kind-secure-scan-cluster`

### Step 4: Install Nginx Ingress Controller

```yaml
- name: Install Nginx Ingress Controller
  run: |
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
```

**Purpose**: Installs the ingress controller needed for external access.

```mermaid
flowchart TB
    subgraph "ingress-nginx Namespace"
        CTRL[Ingress Controller Pod]
    end
    
    subgraph "External Traffic"
        CLIENT[Client]
    end
    
    CLIENT -->|secure-scan.local| CTRL
    CTRL -->|Routes to| SVC[Service]
    
    style CTRL fill:#ffd43b,stroke:#fab005
```

### Step 5: Load Docker Image

```yaml
- name: Load Docker image into kind
  run: kind load docker-image secure-scan-site:${{ github.sha }} --name secure-scan-cluster
```

**Purpose**: Makes the built Docker image available to the kind cluster.

```mermaid
flowchart LR
    subgraph "Runner"
        IMG[Docker Image<br/>secure-scan-site:SHA]
    end
    
    subgraph "kind Cluster"
        NODE[Worker Node]
    end
    
    IMG -->|kind load| NODE
    
    style IMG fill:#339af0,stroke:#1971c2,color:#fff
    style NODE fill:#51cf66,stroke:#2f9e44,color:#fff
```

**Why this is needed:** kind runs Docker-in-Docker, so images built on the runner aren't automatically available inside the cluster.

### Step 6: Terraform Init

```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v2

- name: Terraform Init
  run: terraform init
  working-directory: ./terraform
```

**Purpose**: Downloads required providers (kubernetes).

### Step 7: Terraform Plan

```yaml
- name: Terraform Plan
  run: terraform plan -var="image_name=secure-scan-site:${{ github.sha }}"
  working-directory: ./terraform
```

**Purpose**: Shows what changes will be made (dry run).

### Step 8: Terraform Apply

```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve -var="image_name=secure-scan-site:${{ github.sha }}"
  working-directory: ./terraform
```

**Purpose**: Creates all Kubernetes resources.

```mermaid
flowchart TB
    subgraph "Terraform Apply"
        TF[terraform apply]
    end
    
    subgraph "Kubernetes Resources"
        NS[Namespace: secure-scan]
        DEPLOY[Deployment: secure-site]
        SVC[Service: secure-site-service]
        ING[Ingress: secure-site-ingress]
    end
    
    TF --> NS
    NS --> DEPLOY
    DEPLOY --> SVC
    SVC --> ING
    
    style TF fill:#339af0,stroke:#1971c2,color:#fff
    style NS fill:#51cf66,stroke:#2f9e44,color:#fff
    style DEPLOY fill:#51cf66,stroke:#2f9e44,color:#fff
    style SVC fill:#ffd43b,stroke:#fab005
    style ING fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

---

## Pipeline Flow Summary

```mermaid
flowchart TB
    subgraph "Phase 1: Security"
        A[Push Code] --> B[Build Image]
        B --> C[Trivy Scan]
        C --> D[Checkov Scan]
    end
    
    subgraph "Phase 2: Deploy"
        D --> E[Create kind Cluster]
        E --> F[Install Ingress]
        F --> G[Load Image]
        G --> H[Terraform Apply]
    end
    
    subgraph "Phase 3: Verify"
        H --> I[Resources Created]
        I --> J[Site Accessible]
    end
    
    style A fill:#339af0,stroke:#1971c2,color:#fff
    style C fill:#ffd43b,stroke:#fab005
    style D fill:#ffd43b,stroke:#fab005
    style H fill:#51cf66,stroke:#2f9e44,color:#fff
    style J fill:#51cf66,stroke:#2f9e44,color:#fff
```

---

## Workflow Variables

| Variable | Source | Usage |
|----------|--------|-------|
| `${{ github.sha }}` | Git commit SHA | Image tag |
| `${{ github.ref }}` | Git ref (branch) | Condition check |
| `${{ github.event_name }}` | Event type | Condition check |

---

## Failure Scenarios

### Trivy Fails

```mermaid
flowchart LR
    A[Trivy Finds HIGH CVE] --> B[Exit Code 1]
    B --> C[Pipeline Fails]
    C --> D[Deploy Job Skipped]
    
    style A fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style C fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

### Checkov Fails

```mermaid
flowchart LR
    A[Checkov Finds Misconfig] --> B[Exit Code 1]
    B --> C[Pipeline Fails]
    C --> D[Deploy Job Skipped]
    
    style A fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style C fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

### Terraform Fails

```mermaid
flowchart LR
    A[TF Apply Error] --> B[Exit Code 1]
    B --> C[Pipeline Fails]
    C --> D[Resources Not Created]
    
    style A fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style C fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

---

## Next Steps

- [Commands](06-commands.md) - Learn all CLI commands
- [Troubleshooting](07-troubleshooting.md) - Solve common issues