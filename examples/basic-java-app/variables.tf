# Variables for the example Java application

# NOTE: When using the Contrast agent injection, remember that the sum of all container
# CPU and memory values cannot exceed the task limits, even for init containers.
# The init container uses 128 CPU units and 128 MB memory by default.

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones. If not specified, will use first 2 AZs in the region."
  type        = list(string)
  default     = []
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "java-example-app"
}

variable "app_image" {
  description = "Docker image for the application"
  type        = string
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "DEVELOPMENT"
  validation {
    condition     = contains(["PRODUCTION", "QA", "DEVELOPMENT"], upper(var.environment))
    error_message = "Environment must be one of: PRODUCTION, QA, DEVELOPMENT"
  }
}

variable "team" {
  description = "Team name for tagging"
  type        = string
  default     = "platform"
}

# ECS Configuration
# Note: When Contrast is enabled, the init container uses 128 CPU + 128 MB
# Adjust app_cpu and app_memory accordingly to stay within task limits
variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = string
  default     = "1024"
}

variable "app_cpu" {
  description = "CPU units for the application container"
  type        = number
  default     = 510
}

variable "app_memory" {
  description = "Memory for the application container in MB"
  type        = number
  default     = 1018
}

# Contrast Configuration
variable "contrast_enabled" {
  description = "Enable Contrast agent"
  type        = bool
  default     = false
}

variable "contrast_api_url" {
  description = "Contrast API URL"
  type        = string
  default     = "https://app.contrastsecurity.com/Contrast"
}

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

variable "contrast_log_level" {
  description = "Log level for the Contrast agent"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR"], upper(var.contrast_log_level))
    error_message = "Log level must be one of: TRACE, DEBUG, INFO, WARN, ERROR"
  }
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

# Additional Contrast Configuration Variables
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
  description = "Define a set of key=value pairs for specifying user-defined metadata associated with the application. Example: business-unit=accounting, office=Baltimore"
  type        = string
  default     = ""
}

variable "server_tags" {
  description = "Apply a list of labels to the server. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3"
  type        = string
  default     = ""
}

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
