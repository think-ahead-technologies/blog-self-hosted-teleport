data "azurerm_resource_group" "teleport_rg" {
  name = var.resource_group_name
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  resource_group_name = data.azurerm_resource_group.teleport_rg.name
}

## Helm Chart
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  create_namespace = true

  depends_on = [
    data.azurerm_kubernetes_cluster.aks
  ]
}