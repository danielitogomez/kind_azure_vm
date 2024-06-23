variable "resource_group_name" {
  type        = string
  default     = ""
  description = "Resource group name in your Azure subscription."
}

# The best option is to manage them by secrets in a CICD or exporting them locally
variable "subscription_id" {
  type    = string
  default = ""
  description = "SubscriptionID based on your Mgmt group."
}

variable "client_id" {
  type    = string
  default = ""
  description = "AppID or ClientID in your Azure subscription."
}

variable "client_secret" {
  type    = string
  default = ""
  description = "SubscriptionID in your Azure subscription."
}

variable "tenant_id" {
  type    = string
  default = ""
  description = "TenantID in your Azure subscription."
}