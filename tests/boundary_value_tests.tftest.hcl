# Test boundary values and edge cases for variable validation

run "init_container_cpu_minimum_boundary" {
  command = plan

  variables {
    enabled              = true
    application_name     = "cpu-min-boundary-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    init_container_cpu   = 2 # Minimum valid value
  }

  assert {
    condition     = local.init_container[0].cpu == 2
    error_message = "Should accept minimum CPU value of 2"
  }
}

run "init_container_cpu_maximum_boundary" {
  command = plan

  variables {
    enabled              = true
    application_name     = "cpu-max-boundary-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    init_container_cpu   = 4096 # Maximum valid value
  }

  assert {
    condition     = local.init_container[0].cpu == 4096
    error_message = "Should accept maximum CPU value of 4096"
  }
}

run "init_container_memory_minimum_boundary" {
  command = plan

  variables {
    enabled               = true
    application_name      = "memory-min-boundary-test"
    contrast_api_key      = "test-key"
    contrast_service_key  = "test-service"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_memory = 6 # Minimum valid value
  }

  assert {
    condition     = local.init_container[0].memoryReservation == 6
    error_message = "Should accept minimum memory value of 6"
  }
}

run "init_container_memory_maximum_boundary" {
  command = plan

  variables {
    enabled               = true
    application_name      = "memory-max-boundary-test"
    contrast_api_key      = "test-key"
    contrast_service_key  = "test-service"
    contrast_user_name    = "test-user"
    environment           = "DEVELOPMENT"
    log_group_name        = "test-log-group"
    init_container_memory = 128 # Maximum valid value
  }

  assert {
    condition     = local.init_container[0].memoryReservation == 128
    error_message = "Should accept maximum memory value of 128"
  }
}

run "environment_case_variations" {
  command = plan

  variables {
    enabled              = true
    application_name     = "env-case-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "Development" # Mixed case
    log_group_name       = "test-log-group"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__SERVER__ENVIRONMENT" && env.value == "Development"
    ]) == 1
    error_message = "Should handle mixed case environment values"
  }
}

run "log_level_case_variations" {
  command = plan

  variables {
    enabled              = true
    application_name     = "log-level-case-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    contrast_log_level   = "Debug" # Mixed case
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__AGENT__LOGGER__LEVEL" && env.value == "Debug"
    ]) == 1
    error_message = "Should handle mixed case log level values"
  }
}

run "agent_version_semantic_version_patterns" {
  command = plan

  variables {
    enabled                = true
    application_name       = "agent-version-patterns-test"
    contrast_api_key       = "test-key"
    contrast_service_key   = "test-service"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    contrast_agent_version = "1.0.0" # Basic semantic version
  }

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:1.0.0"
    error_message = "Should handle basic semantic version 1.0.0"
  }
}

run "agent_version_multi_digit_semantic_version" {
  command = plan

  variables {
    enabled                = true
    application_name       = "agent-version-multi-digit-test"
    contrast_api_key       = "test-key"
    contrast_service_key   = "test-service"
    contrast_user_name     = "test-user"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
    contrast_agent_version = "12.34.567" # Multi-digit semantic version
  }

  assert {
    condition     = local.init_container[0].image == "contrast/agent-java:12.34.567"
    error_message = "Should handle multi-digit semantic version"
  }
}

run "proxy_port_boundary_values" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-port-boundary-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host   = "proxy.example.com"
      port   = 65535 # Maximum valid port
      scheme = "http"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT" && env.value == "65535"
    ]) == 1
    error_message = "Should handle maximum port value 65535"
  }
}

run "proxy_port_minimum_boundary" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-port-min-boundary-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host   = "proxy.example.com"
      port   = 1 # Minimum valid port
      scheme = "http"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT" && env.value == "1"
    ]) == 1
    error_message = "Should handle minimum port value 1"
  }
}

run "proxy_https_scheme_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-https-scheme-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host   = "proxy.example.com"
      port   = 8080
      scheme = "https"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__SCHEME" && env.value == "https"
    ]) == 1
    error_message = "Should handle https scheme"
  }
}

run "proxy_url_with_https_scheme" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-url-https-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      url = "https://proxy.example.com:8080"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__URL" && env.value == "https://proxy.example.com:8080"
    ]) == 1
    error_message = "Should handle HTTPS proxy URL"
  }
}

run "all_proxy_auth_types_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-auth-types-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host      = "proxy.example.com"
      port      = 8080
      auth_type = "NTLM" # Test NTLM auth type
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__AUTH_TYPE" && env.value == "NTLM"
    ]) == 1
    error_message = "Should handle NTLM auth type"
  }
}

run "digest_auth_type_validation" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-digest-auth-test"
    contrast_api_key     = "test-key"
    contrast_service_key = "test-service"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host      = "proxy.example.com"
      port      = 8080
      auth_type = "Digest" # Test Digest auth type
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__AUTH_TYPE" && env.value == "Digest"
    ]) == 1
    error_message = "Should handle Digest auth type"
  }
}
