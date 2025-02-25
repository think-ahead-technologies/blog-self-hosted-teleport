data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "teleport_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_dns_zone" "public_dns_zone" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.teleport_rg.name
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.teleport_rg.location
  resource_group_name = azurerm_resource_group.teleport_rg.name
  dns_prefix          = "${var.cluster_name}-dns"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_B2s"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "basic"
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
}

# ArgoCD
## Github Access
resource "tls_private_key" "argo_repo_key" {
  algorithm = "ED25519"
}

resource "azurerm_key_vault" "key_vault" {
  name                = "selfhosted-teleport"
  location            = azurerm_resource_group.teleport_rg.location
  resource_group_name = azurerm_resource_group.teleport_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Access Policies
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Set",
      "Get",
      "List",
      "Delete",
      "Purge",
      "Recover",
      "Restore",
    ]
  }
}

resource "azurerm_key_vault_secret" "argo_repo_public_key_secret" {
  name         = "argo-repo-private-key"
  value        = tls_private_key.argo_repo_key.private_key_openssh
  key_vault_id = azurerm_key_vault.key_vault.id
}

resource "azurerm_key_vault_secret" "argo_repo_private_key_secret" {
  name         = "argo-repo-public-key"
  value        = tls_private_key.argo_repo_key.public_key_openssh
  key_vault_id = azurerm_key_vault.key_vault.id
}

# Cert-Manager
## Azure Identity
resource "azurerm_user_assigned_identity" "cert_manager_identity" {
  name                = "${var.cluster_name}-cert-manager"
  resource_group_name = azurerm_resource_group.teleport_rg.name
  location            = azurerm_resource_group.teleport_rg.location
}

resource "azurerm_federated_identity_credential" "cert_manager_identity" {
  name                = azurerm_user_assigned_identity.cert_manager_identity.name
  resource_group_name = azurerm_resource_group.teleport_rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.cert_manager_identity.id
  subject             = "system:serviceaccount:cert-manager:helm-cert-manager"
}

resource "azurerm_role_assignment" "dns_zone_contributor" {
  scope                = azurerm_dns_zone.public_dns_zone.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.cert_manager_identity.principal_id
}

# ExternalDNS
## Azure Identity
resource "azurerm_user_assigned_identity" "external_dns_identity" {
  name                = "${var.cluster_name}-external-dns"
  resource_group_name = azurerm_resource_group.teleport_rg.name
  location            = azurerm_resource_group.teleport_rg.location
}

resource "azurerm_federated_identity_credential" "external_dns_identity" {
  name                = azurerm_user_assigned_identity.external_dns_identity.name
  resource_group_name = azurerm_resource_group.teleport_rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_dns_identity.id
  subject             = "system:serviceaccount:external-dns:helm-external-dns"
}

resource "azurerm_role_assignment" "external_dns_dns_zone_contributor" {
  scope                = azurerm_dns_zone.public_dns_zone.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns_identity.principal_id
}

resource "azurerm_role_assignment" "external_dns_resource_group_reader" {
  scope                = azurerm_resource_group.teleport_rg.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.external_dns_identity.principal_id
}

# Teleport
resource "azurerm_user_assigned_identity" "teleport_identity" {
  name                = "${var.cluster_name}-teleport"
  resource_group_name = azurerm_resource_group.teleport_rg.name
  location            = azurerm_resource_group.teleport_rg.location
}

resource "azurerm_federated_identity_credential" "teleport_identity" {
  name                = azurerm_user_assigned_identity.teleport_identity.name
  resource_group_name = azurerm_resource_group.teleport_rg.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.teleport_identity.id
  subject             = "system:serviceaccount:teleport:helm-teleport"
}

## Database
resource "azurerm_postgresql_flexible_server" "teleport" {
  name                = "self-hosted-teleport-db"
  location            = azurerm_resource_group.teleport_rg.location
  resource_group_name = azurerm_resource_group.teleport_rg.name
  zone                = "2"
  version             = "15"

  sku_name = "GP_Standard_D2s_v3"

  public_network_access_enabled = true

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
  }

  high_availability {
    mode = "SameZone"
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "wal_level" {
  name      = "wal_level"
  server_id = azurerm_postgresql_flexible_server.teleport.id
  value     = "logical"
}

resource "azurerm_postgresql_flexible_server_database" "teleport" {
  name      = "teleport"
  server_id = azurerm_postgresql_flexible_server.teleport.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "teleport" {
  name             = "AllowAccessFromAzure"
  server_id        = azurerm_postgresql_flexible_server.teleport.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "teleport" {
  server_name         = azurerm_postgresql_flexible_server.teleport.name
  resource_group_name = azurerm_resource_group.teleport_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = "fa0bb52e-1e2b-40ac-baf5-7a218cd6eac7"
  principal_name      = "access"
  principal_type      = "Group"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "teleport_pg_admin" {
  server_name         = azurerm_postgresql_flexible_server.teleport.name
  resource_group_name = azurerm_resource_group.teleport_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.teleport_identity.principal_id
  principal_name      = azurerm_user_assigned_identity.teleport_identity.name
  principal_type      = "ServicePrincipal"
}

resource "azurerm_role_assignment" "teleport_pg_admin" {
  scope                = azurerm_postgresql_flexible_server.teleport.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.teleport_identity.principal_id
}

## Storage Account
resource "time_static" "timestamp" {
  triggers = {
    generate_time = "once"
  }
}

resource "azurerm_storage_account" "blob_storage" {
  name                     = "teleport${time_static.timestamp.unix}"
  resource_group_name      = azurerm_resource_group.teleport_rg.name
  location                 = azurerm_resource_group.teleport_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled = false
}

resource "azurerm_role_assignment" "blob_data_owner" {
  scope                = azurerm_storage_account.blob_storage.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.teleport_identity.principal_id
}