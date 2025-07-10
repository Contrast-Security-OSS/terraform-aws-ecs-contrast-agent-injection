# Outputs for the ECS Contrast Agent Injection module

output "init_container_definitions" {
  description = "Container definitions for the Contrast init container"
  value       = local.init_container
}

output "environment_variables" {
  description = "Environment variables for the application container"
  value       = concat(local.contrast_env_vars, local.optional_env_vars)
  sensitive   = true
}

output "app_mount_points" {
  description = "Mount points for the application container"
  value       = local.app_mount_points
}

output "container_dependencies" {
  description = "Container dependencies for the application container"
  value       = local.container_dependencies
}

output "volume_config" {
  description = "Volume configuration for the task definition"
  value       = local.volume_config
}

output "agent_enabled" {
  description = "Whether the Contrast agent is enabled"
  value       = var.enabled
}

output "agent_path" {
  description = "Path where the Contrast agent is mounted in the application container"
  value       = var.enabled ? "${local.app_mount_path}/${local.current_agent_config.agent_filename}" : null
}

output "init_container_name" {
  description = "Name of the init container"
  value       = var.enabled ? "contrast-init" : null
}

output "volume_name" {
  description = "Name of the shared volume"
  value       = var.enabled ? local.volume_name : null
}

output "contrast_server_name" {
  description = "The computed Contrast server name"
  value       = var.enabled ? local.contrast_server_name : null
}

output "proxy_configured" {
  description = "Whether proxy settings are configured"
  value       = var.proxy_settings != null
  sensitive   = true
}

output "module_version" {
  description = "Version of the Contrast agent being used"
  value       = var.contrast_agent_version
}

output "agent_type" {
  description = "The type of Contrast agent being used"
  value       = var.agent_type
}

output "agent_activation_env" {
  description = "Environment variable name used to activate the agent"
  value       = var.enabled ? local.current_agent_config.activation_env : null
}

output "agent_activation_value" {
  description = "Environment variable value used to activate the agent"
  value       = var.enabled ? local.current_agent_config.activation_value : null
  sensitive   = true
}

output "authentication_method" {
  description = "The authentication method being used (token or three-key)"
  value       = var.enabled ? (local.using_token_auth ? "token" : "three-key") : null
  sensitive   = true
}

# Additional configuration outputs
output "application_group" {
  description = "The application group configured for this application"
  value       = var.application_group != "" ? var.application_group : null
}

output "application_code" {
  description = "The application code configured for this application"
  value       = var.application_code != "" ? var.application_code : null
}

output "application_version" {
  description = "The application version configured for this application"
  value       = var.application_version != "" ? var.application_version : null
}

output "application_tags" {
  description = "The application tags configured for this application"
  value       = var.application_tags != "" ? var.application_tags : null
}

output "application_metadata" {
  description = "The application metadata configured for this application"
  value       = var.application_metadata != "" ? var.application_metadata : null
  sensitive   = true
}

output "application_session_id" {
  description = "The application session ID configured for this application"
  value       = var.application_session_id != "" ? var.application_session_id : null
  sensitive   = true
}

output "application_session_metadata" {
  description = "The application session metadata configured for this application"
  value       = var.application_session_metadata != "" ? var.application_session_metadata : null
  sensitive   = true
}

output "server_tags" {
  description = "The server tags configured for this server"
  value       = var.server_tags != "" ? var.server_tags : null
}

output "assess_tags" {
  description = "The assess tags configured for vulnerabilities and preflight messages"
  value       = var.assess_tags != "" ? var.assess_tags : null
}

output "inventory_tags" {
  description = "The inventory tags configured for libraries"
  value       = var.inventory_tags != "" ? var.inventory_tags : null
}
