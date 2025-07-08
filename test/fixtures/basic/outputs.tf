output "app_name" {
  description = "Application name"
  value       = local.app_name
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.test.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.test.name
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.test.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.test.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.test.id
}

output "contrast_enabled" {
  description = "Whether Contrast agent is enabled"
  value       = module.contrast_agent_injection.agent_enabled
}

output "contrast_agent_path" {
  description = "Path to Contrast agent JAR"
  value       = module.contrast_agent_injection.agent_path
}

output "log_group_app" {
  description = "Application log group name"
  value       = aws_cloudwatch_log_group.app.name
}

output "log_group_contrast" {
  description = "Contrast init container log group name"
  value       = var.contrast_enabled ? aws_cloudwatch_log_group.contrast[0].name : null
}

output "unique_id" {
  description = "Unique test identifier"
  value       = var.unique_id
}
