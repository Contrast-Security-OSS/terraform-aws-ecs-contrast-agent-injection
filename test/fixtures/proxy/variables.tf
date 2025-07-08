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

variable "proxy_settings" {
  description = "Proxy configuration settings"
  type = object({
    host     = optional(string)
    port     = optional(number)
    username = optional(string)
    password = optional(string)
    ssl      = optional(bool, false)
  })
  default = {}
}

variable "app_image" {
  description = "Application container image"
  type        = string
  default     = "nginx:latest"
}

variable "task_cpu" {
  description = "Task CPU units"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = string
  default     = "512"
}

variable "app_cpu" {
  description = "Application container CPU units"
  type        = number
  default     = 128
}

variable "app_memory" {
  description = "Application container memory in MB"
  type        = number
  default     = 384
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}
