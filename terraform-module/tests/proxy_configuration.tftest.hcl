# Test proxy configuration with authentication

run "proxy_configuration_with_auth" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host     = "proxy.example.com"
      port     = 8080
      username = "proxy-user"
      password = "proxy-pass"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__HOST" && env.value == "proxy.example.com"
    ]) == 1
    error_message = "Should set proxy host correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__PORT" && env.value == "8080"
    ]) == 1
    error_message = "Should set proxy port correctly as string"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__USERNAME" && env.value == "proxy-user"
    ]) == 1
    error_message = "Should set proxy username correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__PASSWORD" && env.value == "proxy-pass"
    ]) == 1
    error_message = "Should set proxy password correctly"
  }

  assert {
    condition     = output.proxy_configured == true
    error_message = "Should indicate proxy is configured"
  }
}

run "proxy_configuration_no_auth" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-test-app-no-auth"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      host     = "proxy-no-auth.example.com"
      port     = 3128
      username = ""
      password = ""
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__HOST" && env.value == "proxy-no-auth.example.com"
    ]) == 1
    error_message = "Should set proxy host correctly without auth"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__PORT" && env.value == "3128"
    ]) == 1
    error_message = "Should set proxy port correctly without auth"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__USERNAME" && env.value == ""
    ]) == 1
    error_message = "Should set empty proxy username"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__PASSWORD" && env.value == ""
    ]) == 1
    error_message = "Should set empty proxy password"
  }
}

run "no_proxy_configuration" {
  command = plan

  variables {
    enabled              = true
    application_name     = "no-proxy-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings       = null
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__HOST"
    ]) == 0
    error_message = "Should not have proxy host env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__PORT"
    ]) == 0
    error_message = "Should not have proxy port env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__USERNAME"
    ]) == 0
    error_message = "Should not have proxy username env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__PROXY__PASSWORD"
    ]) == 0
    error_message = "Should not have proxy password env var when proxy is not configured"
  }

  assert {
    condition     = output.proxy_configured == false
    error_message = "Should indicate proxy is not configured"
  }
}
