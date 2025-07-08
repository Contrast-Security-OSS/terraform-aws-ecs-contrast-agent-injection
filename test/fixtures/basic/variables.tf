variable "unique_id" {
  description = "Unique identifier for test resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region for testing"
  type        = string
  default     = "us-east-1"
}

variable "contrast_enabled" {
  description = "Enable or disable the Contrast agent"
  type        = bool
  default     = true
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

variable "app_image" {
  description = "Application Docker image"
  type        = string
  default     = "nginx:latest"
}

variable "task_cpu" {
  description = "Task CPU units"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Task memory (MB)"
  type        = string
  default     = "1024"
}

variable "app_cpu" {
  description = "Application container CPU units"
  type        = number
  default     = 384
}

variable "app_memory" {
  description = "Application container memory (MB)"
  type        = number
  default     = 896
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 0
    error_message = "desired_count must be greater than or equal to 0"
  }
}

variable "contrast_agent_version" {
  description = "Contrast agent version"
  type        = string
  default     = "latest"
}
