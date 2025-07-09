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
      if env.name == "CONTRAST__API__PROXY__ENABLE" && env.value == "true"
    ]) == 1
    error_message = "Should enable proxy when configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__HOST" && env.value == "proxy.example.com"
    ]) == 1
    error_message = "Should set proxy host correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT" && env.value == "8080"
    ]) == 1
    error_message = "Should set proxy port correctly as string"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__SCHEME" && env.value == "http"
    ]) == 1
    error_message = "Should set proxy scheme correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__USER" && env.value == "proxy-user"
    ]) == 1
    error_message = "Should set proxy username correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PASS" && env.value == "proxy-pass"
    ]) == 1
    error_message = "Should set proxy password correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__AUTH_TYPE" && env.value == "Basic"
    ]) == 1
    error_message = "Should set proxy auth type correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__URL"
    ]) == 0
    error_message = "Should not set proxy URL when using individual settings"
  }

  assert {
    condition     = output.proxy_configured == true
    error_message = "Should indicate proxy is configured"
  }
}

run "proxy_configuration_with_url" {
  command = plan

  variables {
    enabled              = true
    application_name     = "proxy-url-test-app"
    contrast_api_key     = "test-api-key"
    contrast_service_key = "test-service-key"
    contrast_user_name   = "test-user"
    environment          = "DEVELOPMENT"
    log_group_name       = "test-log-group"
    proxy_settings = {
      url       = "https://proxy-url.example.com:3128"
      username  = "url-proxy-user"
      password  = "url-proxy-pass"
      auth_type = "Digest"
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__ENABLE" && env.value == "true"
    ]) == 1
    error_message = "Should enable proxy when URL is configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__URL" && env.value == "https://proxy-url.example.com:3128"
    ]) == 1
    error_message = "Should set proxy URL correctly"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__USER" && env.value == "url-proxy-user"
    ]) == 1
    error_message = "Should set proxy username correctly for URL config"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PASS" && env.value == "url-proxy-pass"
    ]) == 1
    error_message = "Should set proxy password correctly for URL config"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__AUTH_TYPE" && env.value == "Digest"
    ]) == 1
    error_message = "Should set proxy auth type correctly for URL config"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__HOST"
    ]) == 0
    error_message = "Should not set proxy host when using URL configuration"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT"
    ]) == 0
    error_message = "Should not set proxy port when using URL configuration"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__SCHEME"
    ]) == 0
    error_message = "Should not set proxy scheme when using URL configuration"
  }

  assert {
    condition     = output.proxy_configured == true
    error_message = "Should indicate proxy is configured when using URL"
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
      host      = "proxy-no-auth.example.com"
      port      = 3128
      scheme    = "https"
      username  = ""
      password  = ""
      auth_type = ""
    }
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__ENABLE" && env.value == "true"
    ]) == 1
    error_message = "Should enable proxy even without auth"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__HOST" && env.value == "proxy-no-auth.example.com"
    ]) == 1
    error_message = "Should set proxy host correctly without auth"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT" && env.value == "3128"
    ]) == 1
    error_message = "Should set proxy port correctly without auth"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__SCHEME" && env.value == "https"
    ]) == 1
    error_message = "Should set proxy scheme correctly without auth"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__USER"
    ]) == 0
    error_message = "Should not set proxy username when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PASS"
    ]) == 0
    error_message = "Should not set proxy password when empty"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__AUTH_TYPE"
    ]) == 0
    error_message = "Should not set proxy auth type when empty"
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
      if env.name == "CONTRAST__API__PROXY__ENABLE"
    ]) == 0
    error_message = "Should not have proxy enable env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__HOST"
    ]) == 0
    error_message = "Should not have proxy host env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PORT"
    ]) == 0
    error_message = "Should not have proxy port env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__SCHEME"
    ]) == 0
    error_message = "Should not have proxy scheme env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__USER"
    ]) == 0
    error_message = "Should not have proxy username env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__PASS"
    ]) == 0
    error_message = "Should not have proxy password env var when proxy is not configured"
  }

  assert {
    condition = length([
      for env in local.contrast_env_vars : env
      if env.name == "CONTRAST__API__PROXY__AUTH_TYPE"
    ]) == 0
    error_message = "Should not have proxy auth type env var when proxy is not configured"
  }

  assert {
    condition     = output.proxy_configured == false
    error_message = "Should indicate proxy is not configured"
  }
}
