variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to hold the DNS zone."
  default     = "selfhosted-teleport"
}

variable "cluster_name" {
  type        = string
  description = "Name of the selfhosted Teleport cluster."
  default     = "selfhosted-teleport-cluster"
}