######## Confluent variables ########
variable "ccloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
}

variable "ccloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "ccloud_environment_id" {
  description = "Target Confluent cloud environment ID"
  type        = string
}

variable "ccloud_cluster_availability" {
  description = "Availability of the Confluent cluster: SINGLE_ZONE or MULTI_ZONE"
  type        = string
  default     = "SINGLE_ZONE"
}

variable "ccloud_cluster_ckus" {
  description = "Number of CKUs for the cluster"
  type        = number
  default     = 1
}

######## Azure variables ########

variable "resource_group" {
  description = "The name of the Azure Resource Group that the virtual network belongs to"
  type        = string
}

variable "location" {
  description = "The region of your VNet"
  type        = string
}

variable "vnet_name" {
  description = "The name of your VNet that you want to connect to Confluent Cloud Cluster"
  type        = string
}

variable "subnet_name_by_zone" {
  description = "A map of Zone to Subnet Name"
  type        = map(string)
}

variable "subscription_id" {
  description = "The Azure subscription ID to enable for the Private Link Access where your VNet exists"
  type        = string
}

variable "client_id" {
  description = "The ID of the Client on Azure"
  type        = string
}

variable "client_secret" {
  description = "The Secret of the Client on Azure"
  type        = string
}

variable "tenant_id" {
  description = "The Azure tenant ID in which Subscription exists"
  type        = string
}

variable "key_vault_id" {
  description = "Azure Key Vault ID used for byok"
  type = string
}
