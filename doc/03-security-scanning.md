# Security Scanning

This document explains the two security scanning tools used in this project: **Trivy** and **Checkov**.

## Overview

```mermaid
flowchart TB
    subgraph "Security Scanning Pipeline"
        A[Code Push] --> B{Security Gates}
        B --> C[Trivy<br/>Image Scanner]
        B --> D[Checkov<br/>IaC Scanner]
        
        C --> E{Vulnerabilities?}
        D --> F{Misconfigurations?}
        
        E -->|HIGH/CRITICAL| G[❌ Block]
        E -->|Pass| H[✅ Continue]
        
        F -->|Failed Checks| G
        F -->|Pass| I[✅ Continue]
        
        H --> J{Both Pass?}
        I --> J
        J -->|Yes| K[🚀 Deploy]
        J -->|No| G
    end
    
    style G fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style K fill:#51cf66,stroke:#2f9e44,color:#fff
```

---

## Trivy - Container Image Scanner

### What is Trivy?

**Trivy** (pronounced "trih-vee") is a comprehensive security scanner created by Aqua Security. It scans for:

- **OS vulnerabilities** (CVEs in Alpine, Ubuntu, etc.)
- **Language-specific vulnerabilities** (npm, pip, maven, etc.)
- **Secrets detection** (API keys, passwords in code)
- **Misconfigurations** (Dockerfile, Kubernetes, Terraform)

### How Trivy Works

```mermaid
flowchart LR
    subgraph "Input"
        IMG[Docker Image]
    end
    
    subgraph "Trivy Scanner"
        SCAN[Scan Engine]
        DB[Vulnerability DB]
        ANALYZE[Analyze Layers]
    end
    
    subgraph "Output"
        REPORT[Security Report]
        EXIT[Exit Code]
    end
    
    IMG --> SCAN
    DB --> SCAN
    SCAN --> ANALYZE
    ANALYZE --> REPORT
    ANALYZE --> EXIT
    
    EXIT -->|0| PASS[✅ Pass]
    EXIT -->|1| FAIL[❌ Fail]
```

### Trivy in Our Pipeline

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

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `image-ref` | `secure-scan-site:${{ github.sha }}` | The Docker image to scan |
| `format` | `table` | Output format (table, json, sarif) |
| `exit-code` | `1` | Exit with error if vulnerabilities found |
| `ignore-unfixed` | `true` | Skip vulnerabilities with no fix available |
| `vuln-type` | `os,library` | Scan OS packages and language libraries |
| `severity` | `HIGH,CRITICAL` | Only report HIGH and CRITICAL severity |

### Trivy Scan Process

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant Trivy as Trivy Scanner
    participant DB as CVE Database
    participant Image as Docker Image
    
    GH->>Trivy: Start scan
    Trivy->>DB: Download latest DB
    DB->>Trivy: CVE definitions
    Trivy->>Image: Analyze layers
    Image->>Trivy: Package list
    Trivy->>Trivy: Compare packages vs CVEs
    
    alt Vulnerabilities Found
        Trivy->>GH: Exit code 1 + Report
        GH->>GH: ❌ Block pipeline
    else No Issues
        Trivy->>GH: Exit code 0
        GH->>GH: ✅ Continue
    end
```

### Example Trivy Output

```
2024-01-15T10:30:00.000Z    INFO    Vulnerability scanning is enabled
2024-01-15T10:30:00.000Z    INFO    Detected OS: alpine
2024-01-15T10:30:00.000Z    INFO    Number of language-specific files: 0

alpine (linux/amd64)
=====================
Total: 0 (HIGH: 0, CRITICAL: 0)

nginx:alpine (nginx:alpine)
===========================
Total: 0 (HIGH: 0, CRITICAL: 0)
```

### Running Trivy Locally

```bash
# Scan a Docker image
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image secure-scan-site:latest

# Scan with JSON output
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --format json secure-scan-site:latest

# Scan only HIGH and CRITICAL
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL secure-scan-site:latest
```

---

## Checkov - Infrastructure as Code Scanner

### What is Checkov?

**Checkov** is a static analysis tool for infrastructure-as-code created by Bridgecrew (now Palo Alto Networks). It scans:

- **Terraform** (AWS, Azure, GCP, Kubernetes)
- **CloudFormation**
- **Kubernetes manifests**
- **Dockerfiles**
- **ARM templates**

### How Checkov Works

```mermaid
flowchart TB
    subgraph "Input"
        TF[Terraform Files]
    end
    
    subgraph "Checkov Scanner"
        PARSE[Parse IaC]
        POLICY[Policy Engine<br/>1000+ policies]
        EVAL[Evaluate Rules]
    end
    
    subgraph "Checks"
        CK1[CKV_K8S_XX<br/>Kubernetes Security]
        CK2[CKV_AWS_XX<br/>AWS Security]
        CK3[CKV_GCP_XX<br/>GCP Security]
    end
    
    subgraph "Output"
        REPORT[Compliance Report]
        EXIT[Exit Code]
    end
    
    TF --> PARSE
    PARSE --> POLICY
    POLICY --> CK1 & CK2 & CK3
    CK1 & CK2 & CK3 --> EVAL
    EVAL --> REPORT
    EVAL --> EXIT
```

### Checkov in Our Pipeline

```yaml
- name: Run Checkov action
  uses: bridgecrewio/checkov-action@master
  with:
    directory: terraform/
    framework: terraform
    soft_fail: false
    check: HIGH,CRITICAL
```

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `directory` | `terraform/` | Directory containing IaC files |
| `framework` | `terraform` | Type of IaC to scan |
| `soft_fail` | `false` | Fail pipeline on issues |
| `check` | `HIGH,CRITICAL` | Only run high/critical checks |

### Key Kubernetes Security Checks

Checkov validates many security best practices for Kubernetes:

| Check ID | What it Checks |
|-----------|---------------|
| `CKV_K8S_10` | Container runs as non-root |
| `CKV_K8S_11` | Container doesn't allow privilege escalation |
| `CKV_K8S_12` | Container drops all capabilities |
| `CKV_K8S_14` | Container has read-only root filesystem |
| `CKV_K8S_15` | Container has resource limits defined |
| `CKV_K8S_21` | Default namespace is not used |
| `CKV_K8S_22` | Container image uses specific tag (not `:latest`) |
| `CKV_K8S_23` | Container has liveness probe configured |
| `CKV_K8S_24` | Container has readiness probe configured |

### Checkov Scan Process

```mermaid
sequenceDiagram
    participant GH as GitHub Actions
    participant Checkov as Checkov Scanner
    participant Policy as Policy Library
    participant TF as Terraform Files
    
    GH->>Checkov: Start scan
    Checkov->>TF: Parse files
    Checkov->>Policy: Load policies
    Policy->>Checkov: Security rules
    
    loop For each resource
        Checkov->>Checkov: Evaluate against policies
    end
    
    alt Failed Checks Found
        Checkov->>GH: Exit code 1 + Report
        GH->>GH: ❌ Block pipeline
    else All Pass
        Checkov->>GH: Exit code 0
        GH->>GH: ✅ Continue
    end
```

### Example Checkov Output

```
       _               _              
      | |             | |             
   ___| |__   ___  ___| | _______  __
  / __| '_ \ / _ \/ __| |/ / _ \ \/ /
 | (__| | | |  __/ (__|   <  __/>  < 
  \___|_| |_|\___|\___|_|\_\___/_/\_\
  
By bridgecrew.io | version: 3.0.0

Terraform scan results:

Passed: 15
Failed: 0
Skipped: 0

Check: CKV_K8S_10: "Ensure container runs as non-root"
	PASSED for resource: kubernetes_deployment.site
	File: /terraform/main.tf:11-87

Check: CKV_K8S_11: "Ensure container doesn't allow privilege escalation"
	PASSED for resource: kubernetes_deployment.site
	File: /terraform/main.tf:11-87
```

### Running Checkov Locally

```bash
# Scan Terraform files
docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform

# Scan with JSON output
docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform --output json

# Scan only specific checks
docker run --rm -v $(pwd)/terraform:/terraform bridgecrew/checkov -d /terraform --check CKV_K8S_10,CKV_K8S_11
```

---

## Security Gate Logic

### Why Both Scanners?

```mermaid
flowchart TB
    subgraph "Different Security Domains"
        A[Trivy] --> B[Container Image<br/>Vulnerabilities]
        C[Checkov] --> D[Infrastructure Code<br/>Misconfigurations]
    end
    
    subgraph "Complementary Coverage"
        E[Trivy catches:]
        F[OS CVEs<br/>Library CVEs<br/>Known exploits]
        
        G[Checkov catches:]
        H[Root containers<br/>Missing limits<br/>Insecure configs]
    end
    
    B --> F
    D --> H
```

### What Each Scanner Catches

| Issue Type | Trivy | Checkov |
|------------|-------|---------|
| CVE in Alpine packages | ✅ | ❌ |
| CVE in npm packages | ✅ | ❌ |
| Container running as root | ❌ | ✅ |
| Missing resource limits | ❌ | ✅ |
| Hardcoded secrets | ✅ | ✅ |
| Insecure Kubernetes config | ❌ | ✅ |
| Outdated base image | ✅ | ❌ |

---

## Best Practices

### For Trivy

1. **Run on every build**: Scan all images before deployment
2. **Block HIGH/CRITICAL**: Don't deploy with known vulnerabilities
3. **Update base images regularly**: Use `apk upgrade` in Dockerfile
4. **Pin image versions**: Use specific tags/digests

### For Checkov

1. **Scan before commit**: Run locally during development
2. **Fix all failed checks**: Don't skip security policies
3. **Keep policies updated**: New checks are added regularly
4. **Custom policies**: Add organization-specific rules

### Pipeline Integration

```mermaid
flowchart LR
    subgraph "Development"
        A[Write Code] --> B[Local Scan]
        B --> C[Fix Issues]
        C --> D[Commit]
    end
    
    subgraph "CI/CD"
        D --> E[Build]
        E --> F[Trivy Scan]
        F --> G[Checkov Scan]
        G --> H{Pass?}
        H -->|Yes| I[Deploy]
        H -->|No| J[Block & Notify]
    end
    
    style J fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style I fill:#51cf66,stroke:#2f9e44,color:#fff
```

---

## Common Vulnerabilities Found

### Trivy Findings

| CVE | Package | Severity | Fix |
|-----|---------|----------|-----|
| CVE-2023-1234 | openssl | HIGH | Upgrade to 3.0.9 |
| CVE-2023-5678 | libssl | CRITICAL | Upgrade to 3.0.10 |

### Checkov Findings

| Check | Issue | Fix |
|-------|-------|-----|
| CKV_K8S_10 | Container runs as root | Add `run_as_non_root = true` |
| CKV_K8S_14 | Read-write filesystem | Add `read_only_root_filesystem = true` |
| CKV_K8S_15 | No resource limits | Add `resources { limits = {...} }` |

---

## Next Steps

- [Terraform](04-terraform.md) - Understand the infrastructure code
- [Workflow](05-workflow.md) - See how scans integrate into CI/CD
- [Commands](06-commands.md) - Learn how to run scans locally