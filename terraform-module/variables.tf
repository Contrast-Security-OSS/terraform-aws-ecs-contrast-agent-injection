# Variables for the ECS Contrast Agent Sidecar module

variable "enabled" {
  description = "Enable or disable the Contrast agent sidecar"
  type        = bool
  default     = false
}

variable "application_name" {
  description = "Name of the application as it will appear in Contrast"
  type        = string
}

variable "contrast_api_url" {
  description = "URL of the Contrast TeamServer instance"
  type        = string
  default     = "https://app.contrastsecurity.com"
}

variable "contrast_api_key" {
  description = "API key for Contrast agent authentication"
  type        = string
  sensitive   = true
}

variable "contrast_service_key" {
  description = "Service key for the specific application profile"
  type        = string
  sensitive   = true
}

variable "contrast_user_name" {
  description = "Agent user name for authentication"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (e.g., production, staging, qa)"
  type        = string
  validation {
    condition     = contains(["production", "staging", "qa", "development", "test"], lower(var.environment))
    error_message = "Environment must be one of: production, staging, qa, development, test"
  }
}

variable "server_name" {
  description = "Server name in Contrast UI (defaults to app-name-region if not specified)"
  type        = string
  default     = ""
}

variable "contrast_log_level" {
  description = "Logging verbosity of the Contrast agent"
  type        = string
  default     = "WARN"
  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR"], upper(var.contrast_log_level))
    error_message = "Log level must be one of: TRACE, DEBUG, INFO, WARN, ERROR"
  }
}

variable "init_container_image" {
  description = "Docker image for the Contrast init container"
  type        = string
  default     = "contrast/agent-java:latest"
}

variable "init_container_cpu" {
  description = "CPU units for the init container"
  type        = number
  default     = 128
}

variable "init_container_memory" {
  description = "Memory (in MB) for the init container"
  type        = number
  default     = 128
}

variable "log_group_name" {
  description = "CloudWatch log group name for the init container (defaults to /ecs/contrast-init)"
  type        = string
  default     = ""
}

variable "additional_env_vars" {
  description = "Additional environment variables for Contrast configuration"
  type        = map(string)
  default     = {}
}

variable "contrast_agent_version" {
  description = "Specific version of the Contrast agent to use"
  type        = string
  default     = "latest"
  validation {
    condition     = can(regex("^(latest|[0-9]+\\.[0-9]+\\.[0-9]+)$", var.contrast_agent_version))
    error_message = "Agent version must be 'latest' or a semantic version (e.g., 3.12.2)"
  }
}

variable "enable_stdout_logging" {
  description = "Enable agent logging to stdout for container logs"
  type        = bool
  default     = true
}

variable "proxy_settings" {
  description = "Proxy settings for the Contrast agent"
  type = object({
    host     = string
    port     = number
    username = optional(string, "")
    password = optional(string, "")
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to the Contrast configuration"
  type        = map(string)
  default     = {}
}
