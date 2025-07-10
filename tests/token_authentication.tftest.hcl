# Test token authentication functionality

run "token_authentication_basic" {
  command = plan

  variables {
    enabled                = true
    application_name       = "token-auth-test-app"
    contrast_api_token     = "test-token-123"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__TOKEN" && env.value == "test-token-123"
    ]) == 1
    error_message = "Should set CONTRAST__API__TOKEN when using token authentication"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__API_KEY"
    ]) == 0
    error_message = "Should not set CONTRAST__API__API_KEY when using token authentication"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__SERVICE_KEY"
    ]) == 0
    error_message = "Should not set CONTRAST__API__SERVICE_KEY when using token authentication"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__USER_NAME"
    ]) == 0
    error_message = "Should not set CONTRAST__API__USER_NAME when using token authentication"
  }

  assert {
    condition     = local.using_token_auth == true
    error_message = "Should detect token authentication method"
  }

  assert {
    condition     = output.authentication_method == "token"
    error_message = "Should output 'token' as authentication method"
  }
}

run "three_key_authentication_basic" {
  command = plan

  variables {
    enabled              = true
    application_name     = "three-key-auth-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__API_KEY" && env.value == "test-api-key"
    ]) == 1
    error_message = "Should set CONTRAST__API__API_KEY when using three-key authentication"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__SERVICE_KEY" && env.value == "test-service-key"
    ]) == 1
    error_message = "Should set CONTRAST__API__SERVICE_KEY when using three-key authentication"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__USER_NAME" && env.value == "test-user"
    ]) == 1
    error_message = "Should set CONTRAST__API__USER_NAME when using three-key authentication"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__TOKEN"
    ]) == 0
    error_message = "Should not set CONTRAST__API__TOKEN when using three-key authentication"
  }

  assert {
    condition     = local.using_token_auth == false
    error_message = "Should detect three-key authentication method"
  }

  assert {
    condition     = output.authentication_method == "three-key"
    error_message = "Should output 'three-key' as authentication method"
  }
}

run "token_authentication_with_proxy" {
  command = plan

  variables {
    enabled                = true
    application_name       = "token-proxy-test-app"
    contrast_api_token     = "test-token-with-proxy"
    environment            = "PRODUCTION"
    log_group_name         = "test-log-group"
    proxy_settings = {
      host      = "proxy.example.com"
      port      = 8080
      scheme    = "http"
      username  = "proxy-user"
      password  = "proxy-pass"
      auth_type = "Basic"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__TOKEN" && env.value == "test-token-with-proxy"
    ]) == 1
    error_message = "Should set CONTRAST__API__TOKEN when using token authentication with proxy"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__ENABLE" && env.value == "true"
    ]) == 1
    error_message = "Should enable proxy when configured with token authentication"
  }

  assert {
    condition     = output.authentication_method == "token"
    error_message = "Should output 'token' as authentication method when using proxy"
  }
}

run "token_authentication_disabled" {
  command = plan

  variables {
    enabled                = false
    application_name       = "disabled-token-test-app"
    contrast_api_token     = "test-token-disabled"
    environment            = "DEVELOPMENT"
    log_group_name         = "test-log-group"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__TOKEN"
    ]) == 0
    error_message = "Should not set CONTRAST__API__TOKEN when agent is disabled"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST_ENABLED" && env.value == "false"
    ]) == 1
    error_message = "Should set CONTRAST_ENABLED=false when agent is disabled"
  }

  assert {
    condition     = output.authentication_method == null
    error_message = "Should output null as authentication method when disabled"
  }
}
