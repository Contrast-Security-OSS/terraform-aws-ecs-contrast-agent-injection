# Example with Proxy Configuration
# This example shows how to configure the Contrast agent with a corporate proxy

terraform {
  required_version = ">= 1.0"
}

module "contrast_agent_injection_with_proxy" {
  source = "../.."

  enabled                = true
  application_name       = "my-java-service"
  contrast_api_url       = "https://eval.contrastsecurity.com/Contrast"
  contrast_api_key       = var.contrast_api_key
  contrast_service_key   = var.contrast_service_key
  contrast_user_name     = var.contrast_user_name
  environment            = "PRODUCTION"
  contrast_log_level     = "INFO"
  contrast_agent_version = "4.0.0"
  log_group_name         = "/ecs/my-java-service"

  # Proxy configuration for corporate environments
  # Option 1: Using individual host, port, scheme settings
  proxy_settings = {
    host      = "proxy.company.com"
    port      = 8080
    scheme    = "http"
    username  = var.proxy_username
    password  = var.proxy_password
    auth_type = "Basic"
  }

  # Option 2: Using proxy URL (alternative to above)
  # proxy_settings = {
  #   url       = "http://proxy.company.com:8080"
  #   username  = var.proxy_username
  #   password  = var.proxy_password
  #   auth_type = "Basic"
  # }

  # Additional environment variables for custom configuration
  additional_env_vars = {
    "CONTRAST__ASSESS__SAMPLING__ENABLE"   = "true"
    "CONTRAST__ASSESS__SAMPLING__BASELINE" = "10"
    "CONTRAST__PROTECT__RULES__DISABLED"   = "sqli,xss"
    "CONTRAST__APPLICATION__TAGS"          = "production,critical"
  }
}

# Variables for proxy example
variable "contrast_api_key" {
  description = "Contrast API key"
  type        = string
  sensitive   = true
}

variable "contrast_service_key" {
  description = "Contrast service key"
  type        = string
  sensitive   = true
}

variable "contrast_user_name" {
  description = "Contrast user name"
  type        = string
  sensitive   = true
}

variable "proxy_username" {
  description = "Proxy username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxy_password" {
  description = "Proxy password"
  type        = string
  sensitive   = true
  default     = ""
}

# Example outputs
output "contrast_enabled" {
  value = module.contrast_agent_injection_with_proxy.agent_enabled
}

output "proxy_configured" {
  value     = module.contrast_agent_injection_with_proxy.proxy_configured
  sensitive = true
}

