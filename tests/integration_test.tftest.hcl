# Integration test that validates the complete configuration outputs

variables {
  enabled                = true
  application_name       = "integration-test-app"
  contrast_api_key       = "integration-test-key"
  contrast_service_key   = "integration-test-service-key"
  contrast_user_name     = "integration-test-user"
  environment            = "PRODUCTION"
  log_group_name         = "integration-test-logs"
  server_name            = "integration-server"
  contrast_api_url       = "https://custom.contrastsecurity.com/Contrast"
  contrast_log_level     = "INFO"
  enable_stdout_logging  = true
  contrast_agent_version = "3.14.1"
  init_container_cpu     = 4
  init_container_memory  = 32
  additional_env_vars = {
    "INTEGRATION_TEST" = "true"
    "CUSTOM_CONFIG"    = "production-value"
  }
  proxy_settings = {
    host      = "corp-proxy.company.com"
    port      = 8080
    scheme    = "https"
    username  = "proxy-service-account"
    password  = "secure-proxy-password"
    auth_type = "Basic"
  }
}

run "integration_test_complete_setup" {
  command = plan

  # Validate init container configuration
  assert {
    condition     = length(local.init_container) == 1
    error_message = "Should have exactly one init container"
  }

  assert {
    condition     = local.init_container[0].name == "contrast-init"
    error_message = "Init container should be named contrast-init"
  }

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:3.14.1"
    error_message = "Init container should use specified agent version"
  }

  assert {
    condition     = local.init_container[0].essential == false
    error_message = "Init container should not be essential"
  }

  assert {
    condition     = local.init_container[0].cpu == 4
    error_message = "Init container should use specified CPU"
  }

  assert {
    condition     = local.init_container[0].memoryReservation == 32
    error_message = "Init container should use specified memory"
  }

  # Validate volume configuration
  assert {
    condition     = local.volume_config.name == "contrast-agent-storage"
    error_message = "Volume should be properly named"
  }

  # Validate mount points
  assert {
    condition     = length(local.app_mount_points) == 1
    error_message = "Should have exactly one mount point"
  }

  assert {
    condition     = local.app_mount_points[0].sourceVolume == "contrast-agent-storage"
    error_message = "Mount point should reference correct volume"
  }

  assert {
    condition     = local.app_mount_points[0].containerPath == "/opt/contrast/java"
    error_message = "Mount point should use correct path"
  }

  assert {
    condition     = local.app_mount_points[0].readOnly == true
    error_message = "App mount point should be read-only"
  }

  # Validate container dependencies
  assert {
    condition     = length(local.container_dependencies) == 1
    error_message = "Should have exactly one container dependency"
  }

  assert {
    condition     = local.container_dependencies[0].containerName == "contrast-init"
    error_message = "Should depend on contrast-init container"
  }

  assert {
    condition     = local.container_dependencies[0].condition == "SUCCESS"
    error_message = "Should wait for SUCCESS condition"
  }
}

run "integration_test_environment_variables" {
  command = plan

  # Test all core Contrast environment variables
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST_ENABLED" && env.value == "true"
    ]) == 1
    error_message = "Should enable Contrast agent"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__URL" && env.value == "https://custom.contrastsecurity.com/Contrast"
    ]) == 1
    error_message = "Should use custom API URL"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__NAME" && env.value == "integration-test-app"
    ]) == 1
    error_message = "Should set application name correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__NAME" && env.value == "integration-server"
    ]) == 1
    error_message = "Should use custom server name"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__ENVIRONMENT" && env.value == "PRODUCTION"
    ]) == 1
    error_message = "Should set environment to PRODUCTION"
  }

  # Test proxy environment variables
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__HOST" && env.value == "corp-proxy.company.com"
    ]) == 1
    error_message = "Should set proxy host"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT" && env.value == "8080"
    ]) == 1
    error_message = "Should set proxy port"
  }

  # Test additional environment variables
  assert {
    condition = length([
      for env in local.optional_env_vars : env
      if env.name == "INTEGRATION_TEST" && env.value == "true"
    ]) == 1
    error_message = "Should include custom integration test variable"
  }

  assert {
    condition = length([
      for env in local.optional_env_vars : env
      if env.name == "CUSTOM_CONFIG" && env.value == "production-value"
    ]) == 1
    error_message = "Should include custom config variable"
  }
}

run "integration_test_outputs_validation" {
  command = plan

  # Validate all outputs
  assert {
    condition     = output.agent_enabled == true
    error_message = "Agent should be enabled"
  }

  assert {
    condition     = output.agent_path == "/opt/contrast/java/contrast-agent.jar"
    error_message = "Agent path should be correct"
  }

  assert {
    condition     = output.init_container_name == "contrast-init"
    error_message = "Init container name should be correct"
  }

  assert {
    condition     = output.volume_name == "contrast-agent-storage"
    error_message = "Volume name should be correct"
  }

  assert {
    condition     = output.contrast_server_name == "integration-server"
    error_message = "Server name should match custom value"
  }

  assert {
    condition     = output.proxy_configured == true
    error_message = "Should indicate proxy is configured"
  }

  assert {
    condition     = output.module_version == "3.14.1"
    error_message = "Should output correct agent version"
  }

  # Validate init container definitions output
  assert {
    condition     = length(output.init_container_definitions) == 1
    error_message = "Should output one init container definition"
  }

  # Validate environment variables output
  assert {
    condition     = length(output.environment_variables) >= 17
    error_message = "Should output all environment variables (core + additional + proxy)"
  }

  # Validate mount points output
  assert {
    condition     = length(output.app_mount_points) == 1
    error_message = "Should output one mount point"
  }

  # Validate container dependencies output
  assert {
    condition     = length(output.container_dependencies) == 1
    error_message = "Should output one container dependency"
  }

  # Validate volume config output
  assert {
    condition     = output.volume_config != null
    error_message = "Should output volume configuration"
  }
}
