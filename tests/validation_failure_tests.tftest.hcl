# Test validation failures for input variables - these tests should fail

run "environment_invalid_value_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "env-invalid-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "INVALID_ENV" # Invalid environment value
    log_group_name       = "test-log-group"
  }

  # This should fail validation
  expect_failures = [
    var.environment
  ]
}

run "log_level_invalid_value_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "log-level-invalid-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    contrast_log_level   = "INVALID_LEVEL" # Invalid log level
  }

  # This should fail validation
  expect_failures = [
    var.contrast_log_level
  ]
}

run "init_container_cpu_below_minimum_should_fail" {
  command = plan

  variables {
    enabled               = true
    application_name      = "cpu-below-min-test"
    contrast_api_key      = "test-key"
    contrast_service_key  = "test-service"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_cpu    = 1 # Below minimum of 2
  }

  # This should fail validation
  expect_failures = [
    var.init_container_cpu
  ]
}

run "init_container_cpu_above_maximum_should_fail" {
  command = plan

  variables {
    enabled               = true
    application_name      = "cpu-above-max-test"
    contrast_api_key      = "test-key"
    contrast_service_key  = "test-service"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_cpu    = 4097 # Above maximum of 4096
  }

  # This should fail validation
  expect_failures = [
    var.init_container_cpu
  ]
}

run "init_container_memory_below_minimum_should_fail" {
  command = plan

  variables {
    enabled               = true
    application_name      = "memory-below-min-test"
    contrast_api_key      = "test-key"
    contrast_service_key  = "test-service"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_memory = 5 # Below minimum of 6
  }

  # This should fail validation
  expect_failures = [
    var.init_container_memory
  ]
}

run "init_container_memory_above_maximum_should_fail" {
  command = plan

  variables {
    enabled               = true
    application_name      = "memory-above-max-test"
    contrast_api_key      = "test-key"
    contrast_service_key  = "test-service"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_memory = 129 # Above maximum of 128
  }

  # This should fail validation
  expect_failures = [
    var.init_container_memory
  ]
}

run "agent_version_invalid_format_should_fail" {
  command = plan

  variables {
    enabled                = true
    application_name       = "agent-version-invalid-test"
    contrast_api_key       = "test-key"
    contrast_service_key   = "test-service"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    contrast_agent_version = "invalid-version" # Invalid version format
  }

  # This should fail validation
  expect_failures = [
    var.contrast_agent_version
  ]
}

run "proxy_url_invalid_format_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-url-invalid-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      url = "invalid-url-format" # Invalid URL format
    }
  }

  # This should fail validation
  expect_failures = [
    var.proxy_settings
  ]
}

run "proxy_both_url_and_individual_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-both-config-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      url    = "http://proxy.example.com:8080"
      host   = "proxy.example.com" # Should not be set with url
      port   = 8080                # Should not be set with url
      scheme = "http"              # Should not be set with url
    }
  }

  # This should fail validation
  expect_failures = [
    var.proxy_settings
  ]
}

run "proxy_auth_type_invalid_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-auth-invalid-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host      = "proxy.example.com"
      port      = 8080
      auth_type = "INVALID_AUTH" # Invalid auth type
    }
  }

  # This should fail validation
  expect_failures = [
    var.proxy_settings
  ]
}

run "agent_type_invalid_should_fail" {
  command = plan

  variables {
    enabled              = true
    application_name     = "agent-type-invalid-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    agent_type           = "invalid_agent" # Invalid agent type
  }

  # This should fail validation
  expect_failures = [
    var.agent_type
  ]
}
