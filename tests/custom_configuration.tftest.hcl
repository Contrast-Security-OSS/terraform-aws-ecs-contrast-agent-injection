# Test custom server name and various configuration options

variables {
  enabled                = true
  application_name       = "my-custom-app"
  contrast_api_key       = "test-api-key"
  contrast_service_key   = "test-service-key"
  contrast_user_name     = "test-user"
  environment            = "PRODUCTION"
  log_group_name         = "custom-log-group"
  server_name            = "custom-server-name"
  contrast_log_level     = "DEBUG"
  enable_stdout_logging  = false
  contrast_agent_version = "3.12.2"
  init_container_cpu     = 4
  init_container_memory  = 64
  additional_env_vars = {
    "CUSTOM_VAR_1" = "value1"
    "CUSTOM_VAR_2" = "value2"
  }
}

run "custom_server_name" {
  command = plan

  assert {
    condition     = local.contrast_server_name == "custom-server-name"
    error_message = "Should use custom server name when provided"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__NAME" && env.value == "custom-server-name"
    ]) == 1
    error_message = "Should set CONTRAST__SERVER__NAME to custom value"
  }
}

run "production_environment" {
  command = plan

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__ENVIRONMENT" && env.value == "PRODUCTION"
    ]) == 1
    error_message = "Should set environment to PRODUCTION"
  }
}

run "custom_log_level_and_stdout" {
  command = plan

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__LOGGER__LEVEL" && env.value == "DEBUG"
    ]) == 1
    error_message = "Should set log level to DEBUG"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__LOGGER__STDOUT" && env.value == "false"
    ]) == 1
    error_message = "Should disable stdout logging when requested"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__SECURITY_LOGGER__LEVEL" && env.value == "DEBUG"
    ]) == 1
    error_message = "Should set security logger level to DEBUG"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__SECURITY_LOGGER__STDOUT" && env.value == "false"
    ]) == 1
    error_message = "Should disable security logger stdout when requested"
  }
}

run "custom_agent_version" {
  command = plan

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:3.12.2"
    error_message = "Should use custom agent version in init container image"
  }

  assert {
    condition     = output.module_version == "3.12.2"
    error_message = "Should output custom agent version"
  }
}

run "custom_resource_limits" {
  command = plan

  assert {
    condition     = local.init_container[0].cpu == 4
    error_message = "Should use custom CPU allocation"
  }

  assert {
    condition     = local.init_container[0].memoryReservation == 64
    error_message = "Should use custom memory allocation"
  }
}

run "additional_environment_variables" {
  command = plan

  assert {
    condition = length([
      for env in local.optional_env_vars : env
      if env.name == "CUSTOM_VAR_1" && env.value == "value1"
    ]) == 1
    error_message = "Should include custom environment variable 1"
  }

  assert {
    condition = length([
      for env in local.optional_env_vars : env
      if env.name == "CUSTOM_VAR_2" && env.value == "value2"
    ]) == 1
    error_message = "Should include custom environment variable 2"
  }

  assert {
    condition     = length(local.optional_env_vars) == 2
    error_message = "Should have exactly 2 additional environment variables"
  }
}

run "logging_configuration" {
  command = plan

  assert {
    condition     = local.init_container[0].logConfiguration.logDriver == "awslogs"
    error_message = "Should use awslogs driver for init container"
  }

  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-group"] == "custom-log-group"
    error_message = "Should use custom log group name"
  }

  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-stream-prefix"] == "contrast-init"
    error_message = "Should use correct stream prefix"
  }
}
