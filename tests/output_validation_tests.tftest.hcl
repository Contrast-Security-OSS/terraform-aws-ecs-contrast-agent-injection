# Test outputs and computed values for accuracy and completeness

run "output_accuracy_validation" {
  command = plan

  variables {
    enabled                = true
    application_name       = "output-accuracy-test"
    contrast_api_key       = "test-key"
    contrast_service_key   = "test-service"
    contrast_user_name     = "test-user"
    environment            = "PRODUCTION"
    log_group_name         = "test-log-group"
    server_name            = "custom-server"
    contrast_agent_version = "3.15.0"
  }

  # Test that all outputs are computed correctly
  assert {
    condition     = output.init_container_name == "contrast-init"
    error_message = "Init container name should be 'contrast-init'"
  }

  assert {
    condition     = output.volume_name == "contrast-agent-storage"
    error_message = "Volume name should be 'contrast-agent-storage'"
  }

  assert {
    condition     = output.contrast_server_name == "custom-server"
    error_message = "Server name should match provided custom name"
  }

  assert {
    condition     = output.agent_type == "java"
    error_message = "Agent type should be 'java'"
  }

  assert {
    condition     = output.module_version == "3.15.0"
    error_message = "Module version should match provided version"
  }

  assert {
    condition     = output.agent_activation_env == "JAVA_TOOL_OPTIONS"
    error_message = "Agent activation environment should be JAVA_TOOL_OPTIONS"
  }

  assert {
    condition     = output.authentication_method == "three-key"
    error_message = "Authentication method should be 'three-key'"
  }

  assert {
    condition     = output.proxy_configured == false
    error_message = "Proxy should not be configured when no proxy settings provided"
  }

  assert {
    condition     = output.agent_path == "/opt/contrast/java/contrast-agent.jar"
    error_message = "Agent path should be correct for Java agent"
  }
}

run "output_validation_with_proxy" {
  command = plan

  variables {
    enabled            = true
    application_name   = "output-proxy-test"
    contrast_api_token = "test-token"
    environment        = "DEVELOPMENT"
    log_group_name     = "test-log-group"
    proxy_settings = {
      host = "proxy.example.com"
      port = 8080
    }
  }

  assert {
    condition     = output.proxy_configured == true
    error_message = "Proxy should be configured when proxy settings provided"
  }

  assert {
    condition     = output.authentication_method == "token"
    error_message = "Authentication method should be 'token' when using token auth"
  }
}

run "output_validation_when_disabled" {
  command = plan

  variables {
    enabled          = false
    application_name = "output-disabled-test"
    environment      = "DEVELOPMENT"
    log_group_name   = "test-log-group"
  }

  # When disabled, most outputs should be null
  assert {
    condition     = output.agent_enabled == false
    error_message = "Agent should be disabled"
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
    error_message = "Server name should be null when disabled"
  }

  assert {
    condition     = output.agent_activation_env == null
    error_message = "Agent activation env should be null when disabled"
  }

  assert {
    condition     = output.authentication_method == null
    error_message = "Authentication method should be null when disabled"
  }
}

run "output_additional_configuration_validation" {
  command = plan

  variables {
    enabled                = true
    application_name       = "output-additional-config-test"
    contrast_api_key       = "test-key"
    contrast_service_key   = "test-service"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    application_group      = "Backend Services"
    application_code       = "backend-001"
    application_version    = "2.1.0"
    application_tags       = "java,backend"
    application_metadata   = "team=backend,owner=john"
    application_session_id = "session-123"
    server_tags            = "production,critical"
    assess_tags            = "security,audit"
    inventory_tags         = "third-party,verified"
  }

  # Test additional configuration outputs
  assert {
    condition     = output.application_group == "Backend Services"
    error_message = "Application group output should match input"
  }

  assert {
    condition     = output.application_code == "backend-001"
    error_message = "Application code output should match input"
  }

  assert {
    condition     = output.application_version == "2.1.0"
    error_message = "Application version output should match input"
  }

  assert {
    condition     = output.application_tags == "java,backend"
    error_message = "Application tags output should match input"
  }

  assert {
    condition     = output.application_metadata == "team=backend,owner=john"
    error_message = "Application metadata output should match input"
  }

  assert {
    condition     = output.application_session_id == "session-123"
    error_message = "Application session ID output should match input"
  }

  assert {
    condition     = output.server_tags == "production,critical"
    error_message = "Server tags output should match input"
  }

  assert {
    condition     = output.assess_tags == "security,audit"
    error_message = "Assess tags output should match input"
  }

  assert {
    condition     = output.inventory_tags == "third-party,verified"
    error_message = "Inventory tags output should match input"
  }
}

run "output_empty_optional_values" {
  command = plan

  variables {
    enabled              = true
    application_name     = "output-empty-values-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    # All optional values left empty
    application_group            = ""
    application_code             = ""
    application_version          = ""
    application_tags             = ""
    application_metadata         = ""
    application_session_id       = ""
    application_session_metadata = ""
    server_tags                  = ""
    assess_tags                  = ""
    inventory_tags               = ""
  }

  # When optional values are empty, outputs should be null
  assert {
    condition     = output.application_group == null
    error_message = "Application group should be null when empty"
  }

  assert {
    condition     = output.application_code == null
    error_message = "Application code should be null when empty"
  }

  assert {
    condition     = output.application_version == null
    error_message = "Application version should be null when empty"
  }

  assert {
    condition     = output.application_tags == null
    error_message = "Application tags should be null when empty"
  }

  assert {
    condition     = output.application_metadata == null
    error_message = "Application metadata should be null when empty"
  }

  assert {
    condition     = output.application_session_id == null
    error_message = "Application session ID should be null when empty"
  }

  assert {
    condition     = output.application_session_metadata == null
    error_message = "Application session metadata should be null when empty"
  }

  assert {
    condition     = output.server_tags == null
    error_message = "Server tags should be null when empty"
  }

  assert {
    condition     = output.assess_tags == null
    error_message = "Assess tags should be null when empty"
  }

  assert {
    condition     = output.inventory_tags == null
    error_message = "Inventory tags should be null when empty"
  }
}

run "output_container_definitions_structure" {
  command = plan

  variables {
    enabled              = true
    application_name     = "output-container-def-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test init container definitions output structure
  assert {
    condition     = length(output.init_container_definitions) == 1
    error_message = "Should have exactly one init container definition"
  }

  assert {
    condition     = output.init_container_definitions[0].name == "contrast-init"
    error_message = "Init container name should be 'contrast-init'"
  }

  assert {
    condition     = output.init_container_definitions[0].essential == false
    error_message = "Init container should not be essential"
  }

  assert {
    condition     = output.init_container_definitions[0].user == "0"
    error_message = "Init container should run as root user"
  }
}

run "output_environment_variables_structure" {
  command = plan

  variables {
    enabled              = true
    application_name     = "output-env-vars-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    additional_env_vars = {
      "CUSTOM_VAR" = "custom_value"
    }
  }

  # Test environment variables output structure
  assert {
    condition     = length(output.environment_variables) > 15
    error_message = "Should have more than 15 environment variables when enabled"
  }

  # Should include both Contrast and additional environment variables
  assert {
    condition = contains([
      for env in output.environment_variables : env.name
    ], "CONTRAST_ENABLED")
    error_message = "Should include CONTRAST_ENABLED environment variable"
  }

  assert {
    condition = contains([
      for env in output.environment_variables : env.name
    ], "CUSTOM_VAR")
    error_message = "Should include additional environment variables"
  }
}

run "output_mount_points_structure" {
  command = plan

  variables {
    enabled              = true
    application_name     = "output-mount-points-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test mount points output structure
  assert {
    condition     = length(output.app_mount_points) == 1
    error_message = "Should have exactly one mount point"
  }

  assert {
    condition     = output.app_mount_points[0].sourceVolume == "contrast-agent-storage"
    error_message = "Mount point should reference correct volume"
  }

  assert {
    condition     = output.app_mount_points[0].containerPath == "/opt/contrast/java"
    error_message = "Mount point should use correct container path"
  }

  assert {
    condition     = output.app_mount_points[0].readOnly == true
    error_message = "Mount point should be read-only"
  }
}

run "output_container_dependencies_structure" {
  command = plan

  variables {
    enabled              = true
    application_name     = "output-dependencies-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test container dependencies output structure
  assert {
    condition     = length(output.container_dependencies) == 1
    error_message = "Should have exactly one container dependency"
  }

  assert {
    condition     = output.container_dependencies[0].containerName == "contrast-init"
    error_message = "Should depend on contrast-init container"
  }

  assert {
    condition     = output.container_dependencies[0].condition == "SUCCESS"
    error_message = "Should wait for SUCCESS condition"
  }
}

run "output_volume_config_structure" {
  command = plan

  variables {
    enabled              = true
    application_name     = "output-volume-config-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test volume config output structure
  assert {
    condition     = output.volume_config.name == "contrast-agent-storage"
    error_message = "Volume config should have correct name"
  }
}
