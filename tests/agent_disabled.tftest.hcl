# Test when Contrast agent is disabled

variables {
  enabled              = false
  application_name     = "test-app"
  contrast_api_key     = "dummy-key"
  contrast_service_key = "dummy-service-key"
  contrast_user_name   = "dummy-user"
  environment          = "DEVELOPMENT"
  log_group_name       = "test-log-group"
}

run "agent_disabled_no_containers" {
  command = plan

  assert {
    condition     = length(local.init_container) == 0
    error_message = "Init container should be empty when agent is disabled"
  }

  assert {
    condition     = length(local.app_mount_points) == 0
    error_message = "App mount points should be empty when agent is disabled"
  }

  assert {
    condition     = length(local.container_dependencies) == 0
    error_message = "Container dependencies should be empty when agent is disabled"
  }

  assert {
    condition     = local.volume_config == null
    error_message = "Volume config should be null when agent is disabled"
  }
}

run "agent_disabled_outputs" {
  command = plan

  assert {
    condition     = output.agent_enabled == false
    error_message = "Agent enabled output should be false when disabled"
  }

  assert {
    condition     = output.agent_path == null
    error_message = "Agent path should be null when disabled"
  }

  assert {
    condition     = output.init_container_name == null
    error_message = "Init container name should be null when disabled"
  }

  assert {
    condition     = output.volume_name == null
    error_message = "Volume name should be null when disabled"
  }

  assert {
    condition     = output.contrast_server_name == null
    error_message = "Contrast server name should be null when disabled"
  }
}

run "agent_disabled_env_vars" {
  command = plan

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST_ENABLED" && env.value == "false"
    ]) == 1
    error_message = "Should have CONTRAST_ENABLED=false when agent is disabled"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name != "CONTRAST_ENABLED"
    ]) == 0
    error_message = "Should only have CONTRAST_ENABLED env var when agent is disabled"
  }
}
