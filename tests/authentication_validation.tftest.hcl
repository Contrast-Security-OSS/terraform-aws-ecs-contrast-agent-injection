# Test authentication validation logic

run "authentication_validation_both_methods_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "validation-fail-app"
    contrast_api_token   = "test-token"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  expect_failures = [
    terraform_data.authentication_validation
  ]
}

run "authentication_validation_partial_three_key_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "validation-partial-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    # Missing contrast_user_name
    environment    = "DEVELOPMENT"
    log_group_name = "test-log-group"
  }

  expect_failures = [
    terraform_data.authentication_validation
  ]
}

run "authentication_validation_empty_values_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "validation-empty-app"
    contrast_api_token   = ""
    contrast_api_key     = ""
    contrast_service_key = ""
    contrast_user_name   = ""
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  expect_failures = [
    terraform_data.authentication_validation
  ]
}

run "authentication_validation_token_only_should_pass" {
  command = plan

  variables {
    enabled            = true
    application_name   = "validation-token-only-app"
    contrast_api_token = "test-token-only"
    environment        = "DEVELOPMENT"
    log_group_name     = "test-log-group"
  }

  assert {
    condition     = output.authentication_method == "token"
    error_message = "Should successfully use token authentication when only token is provided"
  }
}

run "authentication_validation_three_key_only_should_pass" {
  command = plan

  variables {
    enabled              = true
    application_name     = "validation-three-key-only-app"
    contrast_api_key     = "test-api-key-only"
    contrast_service_key = "test-service-key-only"
    contrast_user_name   = "test-user-only"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  assert {
    condition     = output.authentication_method == "three-key"
    error_message = "Should successfully use three-key authentication when all three keys are provided"
  }
}
