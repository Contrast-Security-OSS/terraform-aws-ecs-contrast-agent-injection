# Test for comprehensive additional configuration options coverage

variables {
  enabled               = true
  application_name      = "config-test-app"
  contrast_api_key      = "test-api-key"
  contrast_service_key  = "test-service-key"
  contrast_user_name    = "test-user"
  environment           = "DEVELOPMENT"
  log_group_name        = "test-log-group"
  contrast_api_url      = "https://app.contrastsecurity.com/Contrast"
  contrast_log_level    = "INFO"
  enable_stdout_logging = true

  # Additional application configuration variables
  application_group            = "Backend Services"
  application_code             = "backend-001"
  application_version          = "2.1.0"
  application_tags             = "java,microservice,backend"
  application_metadata         = "business-unit=engineering,cost-center=12345,owner=backend-team"
  application_session_id       = ""
  application_session_metadata = ""

  # Server configuration
  server_tags = "production,east-region,critical"

  # Assessment and inventory tags
  assess_tags    = "security,compliance,audit"
  inventory_tags = "third-party,open-source,critical"
}

run "application_configuration_variables" {
  command = plan

  # Test application_group
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__GROUP" && env.value == "Backend Services"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__GROUP correctly"
  }

  # Test application_code
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__CODE" && env.value == "backend-001"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__CODE correctly"
  }

  # Test application_version
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__VERSION" && env.value == "2.1.0"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__VERSION correctly"
  }

  # Test application_tags
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__TAGS" && env.value == "java,microservice,backend"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__TAGS correctly"
  }

  # Test application_metadata
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__METADATA" && env.value == "business-unit=engineering,cost-center=12345,owner=backend-team"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__METADATA correctly"
  }
}

run "server_configuration_variables" {
  command = plan

  # Test server_tags
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__TAGS" && env.value == "production,east-region,critical"
    ]) == 1
    error_message = "Should set CONTRAST__SERVER__TAGS correctly"
  }
}

run "assessment_and_inventory_tags" {
  command = plan

  # Test assess_tags
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__ASSESS__TAGS" && env.value == "security,compliance,audit"
    ]) == 1
    error_message = "Should set CONTRAST__ASSESS__TAGS correctly"
  }

  # Test inventory_tags
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__INVENTORY__TAGS" && env.value == "third-party,open-source,critical"
    ]) == 1
    error_message = "Should set CONTRAST__INVENTORY__TAGS correctly"
  }
}

run "session_configuration_with_session_id" {
  command = plan

  variables {
    enabled                      = true
    application_name             = "session-id-test-app"
    contrast_api_key             = "test-api-key"
    contrast_service_key         = "test-service-key"
    contrast_user_name           = "test-user"
    environment                  = "DEVELOPMENT"
    log_group_name               = "test-log-group"
    application_session_id       = "test-session-12345"
    application_session_metadata = ""
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_ID" && env.value == "test-session-12345"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__SESSION_ID correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__SESSION_METADATA when session_id is used"
  }
}

run "session_configuration_with_session_metadata" {
  command = plan

  variables {
    enabled                      = true
    application_name             = "session-metadata-test-app"
    contrast_api_key             = "test-api-key"
    contrast_service_key         = "test-service-key"
    contrast_user_name           = "test-user"
    environment                  = "DEVELOPMENT"
    log_group_name               = "test-log-group"
    application_session_id       = ""
    application_session_metadata = "buildNumber=123,branchName=main,commitHash=abc123"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA" && env.value == "buildNumber=123,branchName=main,commitHash=abc123"
    ]) == 1
    error_message = "Should set CONTRAST__APPLICATION__SESSION_METADATA correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_ID"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__SESSION_ID when session_metadata is used"
  }
}

run "empty_optional_configuration_variables" {
  command = plan

  variables {
    enabled              = true
    application_name     = "empty-config-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"

    # Set all optional variables to empty
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

  # Verify that empty variables don't create environment variables
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__GROUP"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__GROUP when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__CODE"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__CODE when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__VERSION"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__VERSION when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__TAGS"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__TAGS when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__METADATA"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__METADATA when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_ID"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__SESSION_ID when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA"
    ]) == 0
    error_message = "Should not set CONTRAST__APPLICATION__SESSION_METADATA when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__TAGS"
    ]) == 0
    error_message = "Should not set CONTRAST__SERVER__TAGS when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__ASSESS__TAGS"
    ]) == 0
    error_message = "Should not set CONTRAST__ASSESS__TAGS when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__INVENTORY__TAGS"
    ]) == 0
    error_message = "Should not set CONTRAST__INVENTORY__TAGS when empty"
  }
}

run "configuration_outputs_validation" {
  command = plan

  # Test that outputs return correct values
  assert {
    condition     = output.application_group == "Backend Services"
    error_message = "Should output application_group correctly"
  }

  assert {
    condition     = output.application_code == "backend-001"
    error_message = "Should output application_code correctly"
  }

  assert {
    condition     = output.application_version == "2.1.0"
    error_message = "Should output application_version correctly"
  }

  assert {
    condition     = output.application_tags == "java,microservice,backend"
    error_message = "Should output application_tags correctly"
  }

  assert {
    condition     = output.server_tags == "production,east-region,critical"
    error_message = "Should output server_tags correctly"
  }

  assert {
    condition     = output.assess_tags == "security,compliance,audit"
    error_message = "Should output assess_tags correctly"
  }

  assert {
    condition     = output.inventory_tags == "third-party,open-source,critical"
    error_message = "Should output inventory_tags correctly"
  }
}

run "configuration_outputs_empty_values" {
  command = plan

  variables {
    enabled              = true
    application_name     = "empty-outputs-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"

    # Set all optional variables to empty
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

  # Test that outputs return null for empty values
  assert {
    condition     = output.application_group == null
    error_message = "Should output null for empty application_group"
  }

  assert {
    condition     = output.application_code == null
    error_message = "Should output null for empty application_code"
  }

  assert {
    condition     = output.application_version == null
    error_message = "Should output null for empty application_version"
  }

  assert {
    condition     = output.application_tags == null
    error_message = "Should output null for empty application_tags"
  }

  assert {
    condition     = output.server_tags == null
    error_message = "Should output null for empty server_tags"
  }

  assert {
    condition     = output.assess_tags == null
    error_message = "Should output null for empty assess_tags"
  }

  assert {
    condition     = output.inventory_tags == null
    error_message = "Should output null for empty inventory_tags"
  }
}

run "complex_metadata_and_tags_formatting" {
  command = plan

  variables {
    enabled              = true
    application_name     = "complex-metadata-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "PRODUCTION"
    log_group_name       = "test-log-group"

    # Test complex metadata with special characters
    application_metadata = "business-unit=engineering,cost-center=12345,owner=backend-team,location=Baltimore,project=contrast-security"
    application_tags     = "java,microservice,backend,security,production"
    server_tags          = "production,east-region,critical,monitored"
    assess_tags          = "security,compliance,audit,priority-high"
    inventory_tags       = "third-party,open-source,critical,verified"

    # Test session metadata with build information
    application_session_metadata = "buildNumber=456,branchName=release/v2.1.0,commitHash=def456,buildDate=2025-01-10,environment=production"
  }

  # Test complex metadata formatting
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__METADATA" && env.value == "business-unit=engineering,cost-center=12345,owner=backend-team,location=Baltimore,project=contrast-security"
    ]) == 1
    error_message = "Should handle complex application metadata with multiple key-value pairs"
  }

  # Test complex tags formatting
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__TAGS" && env.value == "java,microservice,backend,security,production"
    ]) == 1
    error_message = "Should handle complex application tags with multiple values"
  }

  # Test complex server tags
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__TAGS" && env.value == "production,east-region,critical,monitored"
    ]) == 1
    error_message = "Should handle complex server tags with multiple values"
  }

  # Test complex session metadata
  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA" && env.value == "buildNumber=456,branchName=release/v2.1.0,commitHash=def456,buildDate=2025-01-10,environment=production"
    ]) == 1
    error_message = "Should handle complex session metadata with build information"
  }
}

run "environment_variables_count_with_all_options" {
  command = plan

  # When all additional configuration options are set, verify the total count
  assert {
    condition     = length(local.contrast_env_vars) >= 20
    error_message = "Should have at least 20 environment variables when all configuration options are set"
  }

  # Verify that the environment variables include all the expected core variables
  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST_ENABLED")
    error_message = "Should include CONTRAST_ENABLED"
  }

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__API__URL")
    error_message = "Should include CONTRAST__API__URL"
  }

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__APPLICATION__NAME")
    error_message = "Should include CONTRAST__APPLICATION__NAME"
  }

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__SERVER__NAME")
    error_message = "Should include CONTRAST__SERVER__NAME"
  }

  assert {
    condition = contains([
      for env in local.contrast_env_vars : env.name
    ], "CONTRAST__SERVER__ENVIRONMENT")
    error_message = "Should include CONTRAST__SERVER__ENVIRONMENT"
  }
}
