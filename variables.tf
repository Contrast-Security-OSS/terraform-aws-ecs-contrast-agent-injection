# Variables for the ECS Contrast Agent Injection module

variable "enabled" {
  description = "Enable or disable the Contrast agent injection"
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
  default     = "https://app.contrastsecurity.com/Contrast"
}

variable "contrast_api_key" {
  description = "API key for Contrast agent authentication (use with service_key and user_name)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "contrast_service_key" {
  description = "Service key for the specific application profile (use with api_key and user_name)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "contrast_user_name" {
  description = "Agent user name for authentication (use with api_key and service_key)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "contrast_api_token" {
  description = "API token for Contrast agent authentication (alternative to api_key/service_key/user_name)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "environment" {
  description = "Environment name (e.g., PRODUCTION, QA, DEVELOPMENT)"
  type        = string
  validation {
    condition     = can(regex("^(PRODUCTION|QA|DEVELOPMENT)$", upper(var.environment)))
    error_message = "Environment must be one of: PRODUCTION, QA, DEVELOPMENT (case-insensitive)."
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
    condition     = can(regex("^(TRACE|DEBUG|INFO|WARN|ERROR)$", upper(var.contrast_log_level)))
    error_message = "Log level must be one of: TRACE, DEBUG, INFO, WARN, ERROR (case-insensitive)."
  }
}

variable "init_container_cpu" {
  description = "CPU units for the init container"
  type        = number
  default     = 2
  validation {
    condition     = var.init_container_cpu >= 2 && var.init_container_cpu <= 4096
    error_message = "Init container CPU must be between 2 and 4096 units."
  }
}

variable "init_container_memory" {
  description = "Memory (in MB) for the init container"
  type        = number
  default     = 6
  validation {
    condition     = var.init_container_memory >= 6 && var.init_container_memory <= 128
    error_message = "Init container memory must be between 6 and 128 MB."
  }
}

variable "log_group_name" {
  description = "CloudWatch log group name for the init container (must be created externally)"
  type        = string
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
    url       = optional(string, "")
    host      = optional(string, "")
    port      = optional(number, 0)
    scheme    = optional(string, "http")
    username  = optional(string, "")
    password  = optional(string, "")
    auth_type = optional(string, "")
  })
  default = null
  validation {
    condition = var.proxy_settings == null || (
      # Either use URL or host/port/scheme, but not both
      (try(var.proxy_settings.url, "") != "" && try(var.proxy_settings.host, "") == "" && try(var.proxy_settings.port, 0) == 0) ||
      (try(var.proxy_settings.url, "") == "" && try(var.proxy_settings.host, "") != "" && try(var.proxy_settings.port, 0) > 0)
    )
    error_message = "Either specify proxy_url OR host/port/scheme, but not both. If both URL and individual properties are set, an error will be thrown by the agent."
  }
  validation {
    condition     = var.proxy_settings == null || try(var.proxy_settings.url, "") == "" || can(regex("^https?://[a-zA-Z0-9.-]+:[0-9]+$", try(var.proxy_settings.url, "")))
    error_message = "Proxy URL must be in format scheme://host:port (e.g., http://proxy.company.com:8080)."
  }
  validation {
    condition = var.proxy_settings == null || try(var.proxy_settings.host, "") == "" || (
      can(regex("^[a-zA-Z0-9.-]+$", try(var.proxy_settings.host, ""))) &&
      try(var.proxy_settings.port, 0) > 0 && try(var.proxy_settings.port, 0) <= 65535 &&
      can(regex("^(http|https)$", try(var.proxy_settings.scheme, "http")))
    )
    error_message = "Proxy host must be a valid hostname/IP, port must be between 1-65535, and scheme must be http or https."
  }
  validation {
    condition     = var.proxy_settings == null || try(var.proxy_settings.auth_type, "") == "" || can(regex("^(NTLM|Digest|Basic)$", try(var.proxy_settings.auth_type, "")))
    error_message = "Proxy auth_type must be one of: NTLM, Digest, Basic."
  }
  sensitive = true
}

variable "agent_type" {
  description = "Type of Contrast agent to deploy (java)"
  type        = string
  default     = "java"
  validation {
    condition     = can(regex("^(java)$", var.agent_type))
    error_message = "Agent type must be one of: java."
  }
}

# Additional Application Configuration Variables
variable "application_group" {
  description = "Name of the application group with which this application should be associated in Contrast"
  type        = string
  default     = ""
}

variable "application_code" {
  description = "Application code this application should use in Contrast"
  type        = string
  default     = ""
}

variable "application_version" {
  description = "Override the reported application version"
  type        = string
  default     = ""
}

variable "application_tags" {
  description = "Apply labels to an application. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3"
  type        = string
  default     = ""
}

variable "application_metadata" {
  description = "Define a set of key=value pairs for specifying user-defined metadata associated with the application. The set must be formatted as a comma-delimited list of key=value pairs. Example: business-unit=accounting, office=Baltimore"
  type        = string
  default     = ""
}

variable "application_session_id" {
  description = "Provide the ID of a session that already exists in Contrast. Vulnerabilities discovered by the agent are associated with this session. Mutually exclusive with application_session_metadata"
  type        = string
  default     = ""
}

variable "application_session_metadata" {
  description = "Provide metadata that is used to create a new session ID in Contrast. This value should be formatted as key=value pairs (conforming to RFC 2253). Mutually exclusive with application_session_id"
  type        = string
  default     = ""
}

# Additional Server Configuration Variables
variable "server_tags" {
  description = "Apply a list of labels to the server. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3"
  type        = string
  default     = ""
}

# Assessment and Inventory Tags
variable "assess_tags" {
  description = "Apply a list of labels to vulnerabilities and preflight messages. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3"
  type        = string
  default     = ""
}

variable "inventory_tags" {
  description = "Apply a list of labels to libraries. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3"
  type        = string
  default     = ""
}
