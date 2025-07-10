# Test input validation for additional configuration options

run "application_session_validation_both_set_in_variables" {
  command = plan

  variables {
    enabled                      = true
    application_name             = "session-var-validation-app"
    contrast_api_key             = "test-api-key"
    contrast_service_key         = "test-service-key"
    contrast_user_name           = "test-user"
    environment                  = "DEVELOPMENT"
    log_group_name               = "test-log-group"
    application_session_id       = "test-session-123"
    application_session_metadata = "buildNumber=456"
  }

  # This should fail due to lifecycle precondition validation
  expect_failures = [
    terraform_data.session_configuration_validation
  ]
}

run "environment_variable_validation_case_insensitive" {
  command = plan

  variables {
    enabled              = true
    application_name     = "env-validation-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "production" # lowercase
    log_group_name       = "test-log-group"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__ENVIRONMENT" && env.value == "production"
    ]) == 1
    error_message = "Should handle lowercase environment values"
  }
}

run "log_level_validation_case_insensitive" {
  command = plan

  variables {
    enabled              = true
    application_name     = "log-level-validation-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    contrast_log_level   = "debug" # lowercase
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__LOGGER__LEVEL" && env.value == "debug"
    ]) == 1
    error_message = "Should handle lowercase log level values"
  }
}

run "agent_version_validation_semantic_version" {
  command = plan

  variables {
    enabled                = true
    application_name       = "agent-version-validation-app"
    contrast_api_key       = "test-api-key"
    contrast_service_key   = "test-service-key"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    contrast_agent_version = "4.2.15"
  }

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:4.2.15"
    error_message = "Should use semantic version in container image"
  }
}

run "init_container_resource_limits_validation" {
  command = plan

  variables {
    enabled               = true
    application_name      = "resource-limits-validation-app"
    contrast_api_key      = "test-api-key"
    contrast_service_key  = "test-service-key"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_cpu    = 4
    init_container_memory = 64
  }

  assert {
    condition     = local.init_container[0].cpu == 4
    error_message = "Should use custom CPU value within valid range"
  }

  assert {
    condition     = local.init_container[0].memoryReservation == 64
    error_message = "Should use custom memory value within valid range"
  }
}

run "empty_string_handling_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "empty-string-validation-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    server_name          = ""
    application_group    = ""
    application_code     = ""
    application_version  = ""
    application_tags     = ""
    application_metadata = ""
    server_tags          = ""
    assess_tags          = ""
    inventory_tags       = ""
  }

  # Test that empty strings are handled correctly and don't create environment variables
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__GROUP"
    ]) == 0
    error_message = "Empty application_group should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__CODE"
    ]) == 0
    error_message = "Empty application_code should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__VERSION"
    ]) == 0
    error_message = "Empty application_version should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__TAGS"
    ]) == 0
    error_message = "Empty application_tags should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__METADATA"
    ]) == 0
    error_message = "Empty application_metadata should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__TAGS"
    ]) == 0
    error_message = "Empty server_tags should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__ASSESS__TAGS"
    ]) == 0
    error_message = "Empty assess_tags should not create environment variable"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__INVENTORY__TAGS"
    ]) == 0
    error_message = "Empty inventory_tags should not create environment variable"
  }
}

run "server_name_auto_generation_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "server-name-auto-gen-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    server_name          = ""
  }

  assert {
    condition     = startswith(local.contrast_server_name, "server-name-auto-gen-app-")
    error_message = "Should generate server name starting with application name"
  }

  assert {
    condition     = length(split("-", local.contrast_server_name)) >= 3
    error_message = "Generated server name should include application name and region"
  }
}

run "agent_type_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "agent-type-validation-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    agent_type           = "java"
  }

  assert {
    condition     = local.current_agent_config.image_name == "contrast/agent-java"
    error_message = "Should use correct agent configuration for java agent type"
  }

  assert {
    condition     = local.current_agent_config.mount_path == "/opt/contrast/java"
    error_message = "Should use correct mount path for java agent type"
  }

  assert {
    condition     = local.current_agent_config.activation_env == "JAVA_TOOL_OPTIONS"
    error_message = "Should use correct activation environment variable for java agent type"
  }
}

run "additional_env_vars_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "additional-env-vars-validation-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    additional_env_vars = {
      "CUSTOM_VAR_1"              = "value1"
      "CUSTOM_VAR_2"              = "value2"
      "CONTRAST__CUSTOM__SETTING" = "custom-value"
    }
  }

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
    condition = length([
      for env in local.optional_env_vars : env
      if env.name == "CONTRAST__CUSTOM__SETTING" && env.value == "custom-value"
    ]) == 1
    error_message = "Should include custom Contrast setting"
  }
}

run "boolean_variable_validation" {
  command = plan

  variables {
    enabled               = true
    application_name      = "boolean-validation-app"
    contrast_api_key      = "test-api-key"
    contrast_service_key  = "test-service-key"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    enable_stdout_logging = false
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__LOGGER__STDOUT" && env.value == "false"
    ]) == 1
    error_message = "Should handle boolean false value correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__SECURITY_LOGGER__STDOUT" && env.value == "false"
    ]) == 1
    error_message = "Should handle boolean false value for security logger stdout"
  }
}
