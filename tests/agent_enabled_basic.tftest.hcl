# Test when Contrast agent is enabled with basic configuration

variables {
  enabled               = true
  application_name      = "test-app"
  contrast_api_key      = "dummy-key"
  contrast_service_key  = "dummy-service-key"
  contrast_user_name    = "dummy-user"
  environment           = "DEVELOPMENT"
  log_group_name        = "test-log-group"
  contrast_api_url      = "https://app.contrastsecurity.com/Contrast"
  contrast_log_level    = "INFO"
  enable_stdout_logging = true
}

run "agent_enabled_basic_config" {
  command = plan

  assert {
    condition     = length(local.init_container) == 1
    error_message = "Should have exactly one init container when agent is enabled"
  }

  assert {
    condition     = local.init_container[0].name == "contrast-init"
    error_message = "Init container should be named 'contrast-init'"
  }

  assert {
    condition     = local.init_container[0].essential == false
    error_message = "Init container should not be essential"
  }

  assert {
    condition     = local.init_container[0].user == "0"
    error_message = "Init container should run as root user"
  }

  assert {
    condition     = contains([for env in local.init_container[0].environment : env.name], "CONTRAST_MOUNT_PATH")
    error_message = "Init container should have CONTRAST_MOUNT_PATH environment variable"
  }
}

run "agent_enabled_volume_config" {
  command = plan

  assert {
    condition     = local.volume_config != null
    error_message = "Volume config should not be null when agent is enabled"
  }

  assert {
    condition     = local.volume_config.name == "contrast-agent-storage"
    error_message = "Volume should be named 'contrast-agent-storage'"
  }

  assert {
    condition     = length(local.app_mount_points) == 1
    error_message = "Should have exactly one app mount point when agent is enabled"
  }

  assert {
    condition     = local.app_mount_points[0].sourceVolume == "contrast-agent-storage"
    error_message = "App mount point should reference the correct volume"
  }

  assert {
    condition     = local.app_mount_points[0].containerPath == "/opt/contrast/java"
    error_message = "App mount point should have correct container path"
  }

  assert {
    condition     = local.app_mount_points[0].readOnly == true
    error_message = "App mount point should be read-only"
  }
}

run "agent_enabled_dependencies" {
  command = plan

  assert {
    condition     = length(local.container_dependencies) == 1
    error_message = "Should have exactly one container dependency when agent is enabled"
  }

  assert {
    condition     = local.container_dependencies[0].containerName == "contrast-init"
    error_message = "Should depend on contrast-init container"
  }

  assert {
    condition     = local.container_dependencies[0].condition == "SUCCESS"
    error_message = "Should depend on SUCCESS condition"
  }
}

run "agent_enabled_environment_variables" {
  command = plan

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST_ENABLED")
    error_message = "Should have CONTRAST_ENABLED environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST_ENABLED" && env.value == "true"
    ]) == 1
    error_message = "CONTRAST_ENABLED should be set to true"
  }

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__API__URL")
    error_message = "Should have CONTRAST__API__URL environment variable"
  }

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__APPLICATION__NAME")
    error_message = "Should have CONTRAST__APPLICATION__NAME environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__NAME" && env.value == "test-app"
    ]) == 1
    error_message = "Application name should be set correctly"
  }
}

run "agent_enabled_outputs" {
  command = plan

  assert {
    condition     = output.agent_enabled == true
    error_message = "Agent enabled output should be true when enabled"
  }

  assert {
    condition     = output.agent_path == "/opt/contrast/java/contrast-agent.jar"
    error_message = "Agent path should be correct when enabled"
  }

  assert {
    condition     = output.init_container_name == "contrast-init"
    error_message = "Init container name should be correct when enabled"
  }

  assert {
    condition     = output.volume_name == "contrast-agent-storage"
    error_message = "Volume name should be correct when enabled"
  }

  assert {
    condition     = output.module_version == "latest"
    error_message = "Module version should default to latest"
  }
}
