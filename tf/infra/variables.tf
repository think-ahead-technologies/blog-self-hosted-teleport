variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "domain_name" {
  type        = string
  description = "The domain name you registered (e.g. example.com)."
  default     = "selfhosted.teleport.think-ahead.tech"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to hold the DNS zone."
  default     = "selfhosted-teleport"
}

variable "location" {
  type        = string
  description = "Location/region for the resource group."
  default     = "germanywestcentral"
}

variable "cluster_name" {
  type        = string
  description = "Name of the selfhosted Teleport cluster."
  default     = "selfhosted-teleport-cluster"
}