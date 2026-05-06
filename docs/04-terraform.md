# Terraform Infrastructure

This document explains the Terraform configuration used to deploy the application to Kubernetes.

## Overview

```mermaid
flowchart TB
    subgraph "Terraform Configuration"
        TF[main.tf] --> PROVIDER[Kubernetes Provider]
        TF --> VARS[variables.tf]
    end
    
    subgraph "Resources Created"
        PROVIDER --> NS[Namespace]
        PROVIDER --> DEPLOY[Deployment]
        PROVIDER --> SVC[Service]
        PROVIDER --> ING[Ingress]
    end
    
    subgraph "Kubernetes Cluster"
        NS --> NS_NAME[secure-scan]
        DEPLOY --> POD[Pod: nginx container]
        SVC --> CLUSTER_IP[ClusterIP:80]
        ING --> HOST[secure-scan.local]
    end
    
    POD --> SVC
    SVC --> ING
```

---

## File Structure

```
terraform/
├── main.tf       # Main configuration with all resources
└── variables.tf  # Input variables
```

---

## Provider Configuration

### Code

```hcl
provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "kind-secure-scan-cluster"
}
```

### Explanation

```mermaid
flowchart LR
    subgraph "Terraform"
        P[Provider Block]
    end
    
    subgraph "Authentication"
        KC[kubeconfig<br/>~/.kube/config]
        CTX[Context<br/>kind-secure-scan-cluster]
    end
    
    subgraph "Target"
        K8S[Kubernetes API]
    end
    
    P --> KC
    KC --> CTX
    CTX --> K8S
```

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `config_path` | `~/.kube/config` | Path to kubeconfig file |
| `config_context` | `kind-secure-scan-cluster` | Specific context to use |

### Why These Settings?

1. **`config_path`**: Uses the default kubeconfig location
2. **`config_context`**: Explicitly sets the kind cluster context (avoids ambiguity when multiple clusters exist)
3. **`pathexpand()`**: Expands `~` to the home directory

---

## Variables

### File: `variables.tf`

```hcl
variable "image_name" {
  description = "The Docker image name to deploy"
  type        = string
  default     = "secure-scan-site:1.0.0@sha256:0e0dbff0379a2e524508add76f9f0d455be88133de61008b87b1e94e2426d5f7"
}
```

### Usage

```mermaid
flowchart LR
    subgraph "GitHub Actions"
        SHA[Git SHA]
        VAR[var="image_name=secure-scan-site:SHA"]
    end
    
    subgraph "Terraform"
        TF[terraform apply]
        V[variable "image_name"]
        R[resource kubernetes_deployment]
    end
    
    SHA --> VAR
    VAR --> TF
    TF --> V
    V --> R
```

| Attribute | Value | Purpose |
|-----------|-------|---------|
| `description` | Human-readable description | Documentation |
| `type` | `string` | Variable type |
| `default` | Default image | Used if not specified |

---

## Resources

### 1. Namespace

```hcl
resource "kubernetes_namespace_v1" "secure_scan" {
  metadata {
    name = "secure-scan"
  }
}
```

```mermaid
flowchart TB
    subgraph "Kubernetes Cluster"
        NS[Namespace: secure-scan]
    end
    
    subgraph "Isolation"
        NS --> RES1[Deployments]
        NS --> RES2[Services]
        NS --> RES3[Ingresses]
        NS --> RES4[Pods]
    end
    
    style NS fill:#339af0,stroke:#1971c2,color:#fff
```

**Purpose**: Creates an isolated environment for all resources.

**Why a separate namespace?**
- **Isolation**: Separates resources from other workloads
- **Security**: Can apply different policies per namespace
- **Organization**: Easier to manage and clean up
- **Checkov**: Passes `CKV_K8S_21` (don't use default namespace)

---

### 2. Deployment

```hcl
resource "kubernetes_deployment" "site" {
  metadata {
    name      = "secure-site"
    namespace = kubernetes_namespace_v1.secure_scan.metadata[0].name
    labels = {
      app = "secure-site"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "secure-site"
      }
    }

    template {
      metadata {
        labels = {
          app = "secure-site"
        }
      }

      spec {
        container {
          image             = var.image_name
          name              = "secure-site"
          image_pull_policy = "Never"

          port {
            container_port = 80
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 101
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          volume_mount {
            name       = "nginx-cache"
            mount_path = "/var/cache/nginx"
          }

          volume_mount {
            name       = "nginx-run"
            mount_path = "/var/run"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }

        volume {
          name = "nginx-cache"
          empty_dir {}
        }

        volume {
          name = "nginx-run"
          empty_dir {}
        }
      }
    }
  }
}
```

#### Deployment Architecture

```mermaid
flowchart TB
    subgraph "Deployment: secure-site"
        RS[ReplicaSet]
        RS --> POD1[Pod 1]
        
        subgraph "Pod Template"
            C[Container: secure-site]
            C --> IMG[Image: var.image_name]
            C --> PORT[Port: 80]
            C --> SEC[Security Context]
            C --> RES[Resources]
            C --> PROBE[Probes]
        end
    end
    
    POD1 --> C
```

#### Security Context Breakdown

```mermaid
flowchart TB
    subgraph "Security Context"
        SEC[Container Security]
        
        SEC --> ROOT[run_as_non_root: true<br/>✅ CKV_K8S_10]
        SEC --> USER[run_as_user: 101<br/>nginx user]
        SEC --> ESC[allow_privilege_escalation: false<br/>✅ CKV_K8S_11]
        SEC --> FS[read_only_root_filesystem: true<br/>✅ CKV_K8S_14]
        SEC --> CAP[capabilities: drop ALL<br/>✅ CKV_K8S_12]
    end
    
    style ROOT fill:#51cf66,stroke:#2f9e44
    style ESC fill:#51cf66,stroke:#2f9e44
    style FS fill:#51cf66,stroke:#2f9e44
    style CAP fill:#51cf66,stroke:#2f9e44
```

| Security Setting | Value | Checkov Check | Purpose |
|-----------------|-------|---------------|---------|
| `run_as_non_root` | `true` | CKV_K8S_10 | Prevents running as root user |
| `run_as_user` | `101` | - | Specific non-root UID (nginx) |
| `allow_privilege_escalation` | `false` | CKV_K8S_11 | Blocks gaining more privileges |
| `read_only_root_filesystem` | `true` | CKV_K8S_14 | Immutable container filesystem |
| `capabilities.drop` | `["ALL"]` | CKV_K8S_12 | Removes all Linux capabilities |
| `image_pull_policy` | `"Never"` | CKV_K8S_15 (skipped) | Uses pre-loaded kind image |

#### Volume Mounts for Read-Only Filesystem

When using `read_only_root_filesystem = true`, nginx needs writable directories for runtime operations. We add `emptyDir` volumes:

```hcl
# Volume mounts in container
volume_mount {
  name       = "tmp"
  mount_path = "/tmp"
}

volume_mount {
  name       = "nginx-cache"
  mount_path = "/var/cache/nginx"
}

volume_mount {
  name       = "nginx-run"
  mount_path = "/var/run"
}

# Volume definitions in spec
volume {
  name = "tmp"
  empty_dir {}
}

volume {
  name = "nginx-cache"
  empty_dir {}
}

volume {
  name = "nginx-run"
  empty_dir {}
}
```

**Why these directories are needed:**

| Mount Path | Purpose |
|------------|---------|
| `/tmp` | Temporary files for nginx worker processes |
| `/var/cache/nginx` | Nginx cache and proxy temp files |
| `/var/run` | PID file and runtime state |

#### Resource Limits

```mermaid
flowchart LR
    subgraph "Resource Allocation"
        REQ[Requests<br/>Guaranteed]
        LIM[Limits<br/>Maximum]
        
        REQ --> CPU1[CPU: 100m]
        REQ --> MEM1[Memory: 128Mi]
        
        LIM --> CPU2[CPU: 200m]
        LIM --> MEM2[Memory: 256Mi]
    end
    
    style REQ fill:#339af0,stroke:#1971c2,color:#fff
    style LIM fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

| Type | CPU | Memory | Purpose |
|------|-----|--------|---------|
| **Requests** | 100m | 128Mi | Guaranteed resources (scheduler uses this) |
| **Limits** | 200m | 256Mi | Maximum allowed (prevents runaway containers) |

**Why set limits?**
- Prevents DoS from runaway containers
- Ensures fair resource distribution
- Passes Checkov check `CKV_K8S_12` (Memory Limits)

#### Health Probes

```mermaid
sequenceDiagram
    participant K8s as Kubernetes
    participant Container as Container
    
    Note over K8s,Container: Liveness Probe
    K8s->>Container: GET / (every 3s)
    alt Success
        Container->>K8s: 200 OK
    else Failure
        Container->>K8s: Error/Timeout
        K8s->>Container: Restart Container
    end
    
    Note over K8s,Container: Readiness Probe
    K8s->>Container: GET / (every 3s)
    alt Success
        Container->>K8s: 200 OK
        K8s->>K8s: Mark Pod Ready
    else Failure
        Container->>K8s: Error/Timeout
        K8s->>K8s: Mark Pod Not Ready
    end
```

| Probe | Purpose | Checkov Check |
|-------|---------|---------------|
| **Liveness** | Restart container if unhealthy | CKV_K8S_23 |
| **Readiness** | Remove from service if not ready | CKV_K8S_24 |

---

### 3. Service

```hcl
resource "kubernetes_service" "site" {
  metadata {
    name      = "secure-site-service"
    namespace = kubernetes_namespace_v1.secure_scan.metadata[0].name
  }
  
  spec {
    selector = {
      app = "secure-site"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}
```

```mermaid
flowchart LR
    subgraph "Service: secure-site-service"
        SVC[ClusterIP Service<br/>Port 80]
    end
    
    subgraph "Pods"
        P1[Pod 1<br/>Port 80]
        P2[Pod 2<br/>Port 80]
    end
    
    SVC -->|selector: app=secure-site| P1
    SVC -->|selector: app=secure-site| P2
    
    CLIENT[Client] -->|Service IP| SVC
```

| Setting | Value | Purpose |
|---------|-------|---------|
| `type` | `ClusterIP` | Internal cluster access only |
| `port` | `80` | Service port |
| `target_port` | `80` | Container port |
| `selector` | `app=secure-site` | Selects pods with this label |

**Why ClusterIP?**
- Internal service (not exposed externally)
- Ingress handles external traffic
- More secure (no direct external access)

---

### 4. Ingress

```hcl
resource "kubernetes_ingress_v1" "site" {
  metadata {
    name      = "secure-site-ingress"
    namespace = kubernetes_namespace_v1.secure_scan.metadata[0].name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "secure-scan.local"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.site.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
```

```mermaid
flowchart TB
    subgraph "External"
        CLIENT[Client Browser]
    end
    
    subgraph "Ingress"
        ING[Ingress Controller<br/>nginx]
        RULE[Rule: secure-scan.local]
    end
    
    subgraph "Service"
        SVC[Service: secure-site-service<br/>Port 80]
    end
    
    subgraph "Pods"
        POD[Pod: nginx container]
    end
    
    CLIENT -->|Host: secure-scan.local| ING
    ING --> RULE
    RULE -->|Path: /| SVC
    SVC --> POD
```

| Setting | Value | Purpose |
|---------|-------|---------|
| `ingress_class_name` | `nginx` | Uses nginx ingress controller |
| `host` | `secure-scan.local` | Domain name for routing |
| `path` | `/` | Match all paths |
| `path_type` | `Prefix` | Prefix matching |

**Why Ingress?**
- Single entry point for multiple services
- SSL/TLS termination (can be added)
- URL-based routing
- Virtual hosting

---

## Resource Dependencies

```mermaid
flowchart TB
    NS[Namespace<br/>secure-scan]
    DEPLOY[Deployment<br/>secure-site]
    SVC[Service<br/>secure-site-service]
    ING[Ingress<br/>secure-site-ingress]
    
    NS --> DEPLOY
    NS --> SVC
    NS --> ING
    DEPLOY --> SVC
    SVC --> ING
    
    style NS fill:#339af0,stroke:#1971c2,color:#fff
    style DEPLOY fill:#51cf66,stroke:#2f9e44,color:#fff
    style SVC fill:#ffd43b,stroke:#fab005,color:#000
    style ING fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

Terraform automatically handles dependencies:
1. **Namespace** must exist first
2. **Deployment** and **Service** depend on Namespace
3. **Ingress** depends on Service

---

## Applying Terraform

### Local Development

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan changes
terraform plan -var="image_name=secure-scan-site:latest"

# Apply changes
terraform apply -var="image_name=secure-scan-site:latest"

# Destroy resources
terraform destroy
```

### In CI/CD Pipeline

```yaml
- name: Terraform Init
  run: terraform init
  working-directory: ./terraform

- name: Terraform Plan
  run: terraform plan -var="image_name=secure-scan-site:${{ github.sha }}"
  working-directory: ./terraform

- name: Terraform Apply
  run: terraform apply -auto-approve -var="image_name=secure-scan-site:${{ github.sha }}"
  working-directory: ./terraform
```

---

## Checkov Compliance

All resources pass the following Checkov checks:

| Check ID | Description | Status |
|----------|-------------|--------|
| CKV_K8S_10 | CPU requests should be set | ✅ Pass |
| CKV_K8S_11 | CPU Limits should be set | ✅ Pass |
| CKV_K8S_12 | Memory Limits should be set | ✅ Pass |
| CKV_K8S_14 | Image Tag should be fixed - not latest or blank | ✅ Pass |
| CKV_K8S_15 | Image Pull Policy should be Always | ⏭️ Skipped (see note below) |
| CKV_K8S_21 | The default namespace should not be used | ✅ Pass |
| CKV_K8S_23 | Liveness probe configured | ✅ Pass |
| CKV_K8S_24 | Readiness probe configured | ✅ Pass |

### Why CKV_K8S_15 is Skipped

The `CKV_K8S_15` check expects `imagePullPolicy: Always`, but our architecture uses `imagePullPolicy: Never` because:

1. **Pre-loaded Images**: The Docker image is built in GitHub Actions and loaded into the kind cluster using `kind load docker-image`
2. **No Remote Registry**: The image doesn't exist in Docker Hub or any remote registry
3. **Security**: The image is already scanned by Trivy before being loaded into kind
4. **Efficiency**: Avoids unnecessary pull attempts that would fail anyway

This skip is configured in `.github/workflows/security-scan.yml` by removing `CKV_K8S_15` from the check list.

---

## Next Steps

- [Workflow](05-workflow.md) - See how Terraform integrates into CI/CD
- [Commands](06-commands.md) - Learn Terraform commands
- [Troubleshooting](07-troubleshooting.md) - Solve common Terraform issues