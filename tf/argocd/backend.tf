terraform {
  backend "azurerm" {
    resource_group_name  = "selfhosted-teleport-mgmt"
    storage_account_name = "tfstate1740488375"
    container_name       = "terraform-state"
    key                  = "terraform-argocd.tfstate"
  }
}