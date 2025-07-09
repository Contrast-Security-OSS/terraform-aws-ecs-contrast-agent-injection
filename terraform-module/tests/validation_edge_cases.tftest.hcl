# Test validation logic and edge cases

run "default_server_name_generation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "default-name-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "QA"
    log_group_name       = "test-log-group"
    server_name          = ""
  }

  assert {
    condition     = startswith(local.contrast_server_name, "default-name-app-")
    error_message = "Should generate server name with app name prefix when server_name is empty"
  }

  assert {
    condition     = length(split("-", local.contrast_server_name)) >= 2
    error_message = "Generated server name should include region suffix"
  }
}

run "different_environments" {
  command = plan

  variables {
    enabled              = true
    application_name     = "env-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "qa" # lowercase to test validation
    log_group_name       = "test-log-group"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__ENVIRONMENT" && env.value == "qa"
    ]) == 1
    error_message = "Should handle lowercase environment names"
  }
}

run "latest_agent_version" {
  command = plan

  variables {
    enabled                = true
    application_name       = "latest-agent-app"
    contrast_api_key       = "test-api-key"
    contrast_service_key   = "test-service-key"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    contrast_agent_version = "latest"
  }

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:latest"
    error_message = "Should use latest tag when agent version is latest"
  }
}

run "minimal_configuration" {
  command = plan

  variables {
    enabled              = true
    application_name     = "minimal-app"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-logs"
  }

  assert {
    condition     = length(local.init_container) == 1
    error_message = "Should work with minimal required configuration"
  }

  assert {
    condition     = local.init_container[0].cpu == 2
    error_message = "Should use default CPU value when not specified"
  }

  assert {
    condition     = local.init_container[0].memoryReservation == 6
    error_message = "Should use default memory value when not specified"
  }

  assert {
    condition     = output.module_version == "latest"
    error_message = "Should default to latest version"
  }
}

run "security_optimizations" {
  command = plan

  variables {
    enabled              = true
    application_name     = "security-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "PRODUCTION"
    log_group_name       = "test-log-group"
  }

  # Test that security-optimized settings are applied
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__JAVA__SCAN_ALL_CLASSES" && env.value == "false"
    ]) == 1
    error_message = "Should disable scanning all classes for performance"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__JAVA__SCAN_ALL_CODE_SOURCES" && env.value == "false"
    ]) == 1
    error_message = "Should disable scanning all code sources for performance"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__ASSESS__CACHE__HIERARCHY_ENABLE" && env.value == "false"
    ]) == 1
    error_message = "Should disable cache hierarchy for better performance"
  }
}

run "logging_configuration_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "logging-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "custom-log-group-name"
    contrast_log_level   = "TRACE"
  }

  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-group"] == "custom-log-group-name"
    error_message = "Should use provided log group name"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__LOGGER__LEVEL" && env.value == "TRACE"
    ]) == 1
    error_message = "Should set TRACE log level when specified"
  }
}

run "environment_variables_count" {
  command = plan

  variables {
    enabled              = true
    application_name     = "count-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Verify all required environment variables are present
  assert {
    condition     = length(local.contrast_env_vars) >= 15
    error_message = "Should have at least 15 Contrast environment variables when enabled"
  }

  # Verify specific required variables are present
  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__AGENT__JAVA__STANDALONE_APP_NAME")
    error_message = "Should include standalone app name environment variable"
  }
}
