# Test regional behavior and AWS-specific functionality

run "server_name_generation_with_region" {
  command = plan

  variables {
    enabled              = true
    application_name     = "region-test-app"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    server_name          = "" # Should auto-generate with region
  }

  # Test that server name includes region information
  assert {
    condition     = can(regex("^region-test-app-[a-z0-9-]+$", local.contrast_server_name))
    error_message = "Generated server name should include application name and region"
  }

  assert {
    condition     = startswith(local.contrast_server_name, "region-test-app-")
    error_message = "Generated server name should start with application name"
  }

  assert {
    condition     = length(local.contrast_server_name) > length("region-test-app-")
    error_message = "Generated server name should include region suffix"
  }
}

run "aws_region_data_source_usage" {
  command = plan

  variables {
    enabled              = true
    application_name     = "aws-region-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test that AWS region data source is used correctly
  assert {
    condition     = can(data.aws_region.current.id)
    error_message = "AWS region data source should be accessible"
  }

  assert {
    condition     = data.aws_region.current.id != ""
    error_message = "AWS region should not be empty"
  }
}

run "log_configuration_with_region" {
  command = plan

  variables {
    enabled              = true
    application_name     = "log-region-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test that log configuration includes region
  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-region"] == data.aws_region.current.id
    error_message = "Log configuration should use current AWS region"
  }

  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-group"] == "test-log-group"
    error_message = "Log configuration should use provided log group"
  }

  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-stream-prefix"] == "contrast-init"
    error_message = "Log configuration should use correct stream prefix"
  }
}

run "long_log_group_name_handling" {
  command = plan

  variables {
    enabled              = true
    application_name     = "long-log-group-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "very-long-log-group-name-that-might-be-used-in-some-organizations-with-detailed-naming-conventions"
  }

  # Test that long log group names are handled correctly
  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-group"] == "very-long-log-group-name-that-might-be-used-in-some-organizations-with-detailed-naming-conventions"
    error_message = "Should handle long log group names correctly"
  }
}

run "special_characters_in_log_group_name" {
  command = plan

  variables {
    enabled              = true
    application_name     = "special-chars-log-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group_with-special.chars"
  }

  # Test that special characters in log group names are handled
  assert {
    condition     = local.init_container[0].logConfiguration.options["awslogs-group"] == "test-log-group_with-special.chars"
    error_message = "Should handle special characters in log group names"
  }
}

run "init_container_environment_variables" {
  command = plan

  variables {
    enabled              = true
    application_name     = "init-env-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    agent_type           = "java"
  }

  # Test that init container has correct environment variables
  assert {
    condition = length([
      for env in local.init_container[0].environment : env
      if env.name == "CONTRAST_MOUNT_PATH" && env.value == "/mnt/contrast"
    ]) == 1
    error_message = "Init container should have CONTRAST_MOUNT_PATH environment variable"
  }

  assert {
    condition = length([
      for env in local.init_container[0].environment : env
      if env.name == "CONTRAST_AGENT_TYPE" && env.value == "java"
    ]) == 1
    error_message = "Init container should have CONTRAST_AGENT_TYPE environment variable"
  }
}

run "init_container_mount_points" {
  command = plan

  variables {
    enabled              = true
    application_name     = "init-mount-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test that init container has correct mount points
  assert {
    condition     = length(local.init_container[0].mountPoints) == 1
    error_message = "Init container should have exactly one mount point"
  }

  assert {
    condition     = local.init_container[0].mountPoints[0].sourceVolume == "contrast-agent-storage"
    error_message = "Init container mount point should reference correct volume"
  }

  assert {
    condition     = local.init_container[0].mountPoints[0].containerPath == "/mnt/contrast"
    error_message = "Init container mount point should use correct container path"
  }

  # Init container mount should not be read-only (needs to write agent)
  assert {
    condition     = try(local.init_container[0].mountPoints[0].readOnly, false) == false
    error_message = "Init container mount point should be writable"
  }
}

run "volume_configuration_properties" {
  command = plan

  variables {
    enabled              = true
    application_name     = "volume-config-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  # Test volume configuration properties
  assert {
    condition     = local.volume_config != null
    error_message = "Volume config should not be null when enabled"
  }

  assert {
    condition     = local.volume_config.name == "contrast-agent-storage"
    error_message = "Volume should have correct name"
  }

  # Volume should be a simple named volume (no additional properties expected)
  assert {
    condition     = length(keys(local.volume_config)) == 1
    error_message = "Volume config should only have name property"
  }
}

run "agent_image_selection_logic" {
  command = plan

  variables {
    enabled                = true
    application_name       = "agent-image-test"
    contrast_api_key       = "test-key"
    contrast_service_key   = "test-service"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    agent_type             = "java"
    contrast_agent_version = "latest"
  }

  # Test agent image selection logic
  assert {
    condition     = local.current_agent_config.image_name == "contrast/agent-java"
    error_message = "Should select correct agent image for Java"
  }

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:latest"
    error_message = "Should use latest tag when version is 'latest'"
  }
}

run "agent_activation_configuration" {
  command = plan

  variables {
    enabled              = true
    application_name     = "agent-activation-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    agent_type           = "java"
  }

  # Test agent activation configuration
  assert {
    condition     = local.current_agent_config.activation_env == "JAVA_TOOL_OPTIONS"
    error_message = "Should use correct activation environment for Java"
  }

  assert {
    condition     = local.current_agent_config.activation_value == "-javaagent:/opt/contrast/java/contrast-agent.jar"
    error_message = "Should use correct activation value for Java"
  }

  assert {
    condition     = local.current_agent_config.agent_filename == "contrast-agent.jar"
    error_message = "Should use correct agent filename for Java"
  }
}

run "java_specific_environment_variables" {
  command = plan

  variables {
    enabled              = true
    application_name     = "java-env-vars-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    agent_type           = "java"
  }

  # Test Java-specific environment variables
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__JAVA__STANDALONE_APP_NAME" && env.value == "java-env-vars-test"
    ]) == 1
    error_message = "Should set Java standalone app name"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__JAVA__SCAN_ALL_CLASSES" && env.value == "false"
    ]) == 1
    error_message = "Should disable scan all classes for performance"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__JAVA__SCAN_ALL_CODE_SOURCES" && env.value == "false"
    ]) == 1
    error_message = "Should disable scan all code sources for performance"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "JAVA_TOOL_OPTIONS" && env.value == "-javaagent:/opt/contrast/java/contrast-agent.jar"
    ]) == 1
    error_message = "Should set JAVA_TOOL_OPTIONS for agent activation"
  }
}
