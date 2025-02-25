output "azure_dns_name_servers" {
  description = "Azure DNS name servers. Configure these in your domain registrar's NS records."
  value       = azurerm_dns_zone.public_dns_zone.name_servers
}

output "cert-manager-identity-id" {
  description = "The ID of the cert-manager identity."
  value       = azurerm_user_assigned_identity.cert_manager_identity.client_id
}

output "teleport-identity-id" {
  description = "The ID of the teleport identity."
  value       = azurerm_user_assigned_identity.teleport_identity.client_id
}

output "external-dns-identity-id" {
  description = "The ID of the external-dns identity."
  value       = azurerm_user_assigned_identity.external_dns_identity.client_id
}

output "storage-account-name" {
  description = "Storage account to be used by teleport."
  value       = azurerm_storage_account.blob_storage.name
}