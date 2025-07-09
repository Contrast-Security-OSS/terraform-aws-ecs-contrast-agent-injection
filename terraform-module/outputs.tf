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
  description = "Path where the Contrast agent JAR is mounted in the application container"
  value       = var.enabled ? "${local.app_mount_path}/contrast-agent.jar" : null
}

output "java_tool_options" {
  description = "JAVA_TOOL_OPTIONS value for enabling the agent"
  value       = var.enabled ? "-javaagent:${local.app_mount_path}/contrast-agent.jar" : null
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
