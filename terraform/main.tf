provider "kubernetes" {
  config_path    = pathexpand("~/.kube/config")
  config_context = "kind-secure-scan-cluster"
}

resource "kubernetes_namespace_v1" "secure_scan" {
  metadata {
    name = "secure-scan"
  }
}

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
          image = var.image_name
          name  = "secure-site"

          port {
            container_port = 80
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 101 # nginx user in alpine
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
