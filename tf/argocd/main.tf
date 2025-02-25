data "azurerm_resource_group" "teleport_rg" {
  name = var.resource_group_name
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  resource_group_name = data.azurerm_resource_group.teleport_rg.name
}

data "azurerm_key_vault" "key_vault" {
  name                = "selfhosted-teleport"
  resource_group_name = data.azurerm_resource_group.teleport_rg.name
}

data "azurerm_key_vault_secret" "argo_repo_private_key_secret" {
  name         = "argo-repo-private-key"
  key_vault_id = data.azurerm_key_vault.key_vault.id
}

## Repository Secret
resource "kubernetes_secret" "argo_repo_secret" {
  metadata {
    name      = "teleport-self-hosted-azure"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type          = "git"
    url           = "git@github.com:think-ahead-technologies/blog-self-hosted-teleport.git"
    sshPrivateKey = data.azurerm_key_vault_secret.argo_repo_private_key_secret.value
  }

  depends_on = [
    data.azurerm_kubernetes_cluster.aks,
  ]
}

## ArgoCD App of Apps
resource "kubernetes_manifest" "argocd_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "self-hosted-teleport"
      namespace = "argocd"
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      destination = {
        namespace = "argocd"
        server    = "https://kubernetes.default.svc"
      }
      project = "default"
      source = {
        path           = "argocd/infra/self-hosted-teleport-root"
        repoURL        = "git@github.com:think-ahead-technologies/blog-self-hosted-teleport.git"
        targetRevision = "HEAD"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "PruneLast=true",
          "RespectIgnoreDifferences=true",
          "ApplyOutOfSyncOnly=true",
        ]
      }
    }
  }

  depends_on = [
    data.azurerm_kubernetes_cluster.aks,
  ]
}