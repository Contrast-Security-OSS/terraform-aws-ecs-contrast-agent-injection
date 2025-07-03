# Variables for the example Java application

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the application will be deployed"
  type        = string
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
  default     = "development"
}

variable "team" {
  description = "Team name for tagging"
  type        = string
  default     = "platform"
}

# ECS Configuration
variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
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
  default     = 384
}

variable "app_memory" {
  description = "Memory for the application container in MB"
  type        = number
  default     = 896
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
  default     = "https://app.contrastsecurity.com"
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
