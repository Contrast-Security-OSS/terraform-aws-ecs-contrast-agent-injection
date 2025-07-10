# Test session configuration validation and mutual exclusivity

run "session_configuration_both_set_should_fail" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "session-validation-fail-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "DEVELOPMENT"
    log_group_name                 = "test-log-group"
    application_session_id         = "test-session-123"
    application_session_metadata   = "buildNumber=456,branchName=main"
  }

  expect_failures = [
    terraform_data.session_configuration_validation
  ]
}

run "session_configuration_only_session_id_should_pass" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "session-id-only-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "DEVELOPMENT"
    log_group_name                 = "test-log-group"
    application_session_id         = "test-session-456"
    application_session_metadata   = ""
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_ID" && env.value == "test-session-456"
    ]) == 1
    error_message = "Should set session ID when only session_id is provided"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA"
    ]) == 0
    error_message = "Should not set session metadata when only session_id is provided"
  }
}

run "session_configuration_only_session_metadata_should_pass" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "session-metadata-only-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "DEVELOPMENT"
    log_group_name                 = "test-log-group"
    application_session_id         = ""
    application_session_metadata   = "buildNumber=789,branchName=feature/new-feature,commitHash=xyz789"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA" && env.value == "buildNumber=789,branchName=feature/new-feature,commitHash=xyz789"
    ]) == 1
    error_message = "Should set session metadata when only session_metadata is provided"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_ID"
    ]) == 0
    error_message = "Should not set session ID when only session_metadata is provided"
  }
}

run "session_configuration_neither_set_should_pass" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "no-session-config-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "DEVELOPMENT"
    log_group_name                 = "test-log-group"
    application_session_id         = ""
    application_session_metadata   = ""
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_ID"
    ]) == 0
    error_message = "Should not set session ID when neither session configuration is provided"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA"
    ]) == 0
    error_message = "Should not set session metadata when neither session configuration is provided"
  }
}

run "session_metadata_with_ci_cd_variables" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "cicd-session-metadata-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "PRODUCTION"
    log_group_name                 = "test-log-group"
    application_session_id         = ""
    application_session_metadata   = "commitHash=abc123def456,committer=john.doe@company.com,branchName=main,gitTag=v2.1.0,repository=backend-service,testRun=integration-test-123,version=2.1.0,buildNumber=456"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__APPLICATION__SESSION_METADATA" && env.value == "commitHash=abc123def456,committer=john.doe@company.com,branchName=main,gitTag=v2.1.0,repository=backend-service,testRun=integration-test-123,version=2.1.0,buildNumber=456"
    ]) == 1
    error_message = "Should handle complex CI/CD session metadata with all commonly used fields"
  }
}

run "session_configuration_outputs_validation" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "session-outputs-test-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "DEVELOPMENT"
    log_group_name                 = "test-log-group"
    application_session_id         = "test-session-output-123"
    application_session_metadata   = ""
  }

  assert {
    condition     = output.application_session_id == "test-session-output-123"
    error_message = "Should output session ID correctly"
  }

  assert {
    condition     = output.application_session_metadata == null
    error_message = "Should output null for empty session metadata"
  }
}

run "session_metadata_outputs_validation" {
  command = plan

  variables {
    enabled                        = true
    application_name               = "session-metadata-outputs-test-app"
    contrast_api_key               = "test-api-key"
    contrast_service_key           = "test-service-key"
    contrast_user_name             = "test-user"
    environment                    = "DEVELOPMENT"
    log_group_name                 = "test-log-group"
    application_session_id         = ""
    application_session_metadata   = "buildNumber=999,branchName=test-branch"
  }

  assert {
    condition     = output.application_session_metadata == "buildNumber=999,branchName=test-branch"
    error_message = "Should output session metadata correctly"
  }

  assert {
    condition     = output.application_session_id == null
    error_message = "Should output null for empty session ID"
  }
}
