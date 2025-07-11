# Proxy Configuration Example

This example demonstrates how to configure the Contrast agent with proxy settings for corporate environments.

## Usage

```bash
# Copy the example values
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your actual values
vim terraform.tfvars

# Initialize and apply
terraform init
terraform apply
```

## Configuration

The proxy configuration allows the Contrast agent to communicate through corporate proxies. You can configure the proxy in two ways:

**Option 1: Individual Settings**
- **host**: Proxy hostname or IP address
- **port**: Proxy port number
- **scheme**: Proxy protocol (http or https)
- **username**: Proxy authentication username (optional)
- **password**: Proxy authentication password (optional)
- **auth_type**: Proxy authentication type - NTLM, Digest, or Basic (optional)

**Option 2: Proxy URL**
- **url**: Complete proxy URL in format `scheme://host:port` (e.g., `http://proxy.company.com:8080`)
- **username**: Proxy authentication username (optional)
- **password**: Proxy authentication password (optional)
- **auth_type**: Proxy authentication type - NTLM, Digest, or Basic (optional)

**Note:** You must use either the URL option OR the individual host/port/scheme options, but not both.

## Environment Variables

The proxy configuration sets these environment variables for the Contrast agent:

- `CONTRAST__API__PROXY__ENABLE`
- `CONTRAST__API__PROXY__URL` (when using URL configuration)
- `CONTRAST__API__PROXY__HOST` (when using individual settings)
- `CONTRAST__API__PROXY__PORT` (when using individual settings)
- `CONTRAST__API__PROXY__SCHEME` (when using individual settings)
- `CONTRAST__API__PROXY__USER` (when credentials are provided)
- `CONTRAST__API__PROXY__PASS` (when credentials are provided)
- `CONTRAST__API__PROXY__AUTH_TYPE` (when authentication type is specified)

## Security Note

Proxy credentials are marked as sensitive and should be managed securely, preferably through:
- AWS Secrets Manager
- Environment variables in CI/CD
- Encrypted terraform.tfvars files

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_contrast_agent_injection_with_proxy"></a> [contrast\_agent\_injection\_with\_proxy](#module\_contrast\_agent\_injection\_with\_proxy) | ../.. | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_contrast_api_key"></a> [contrast\_api\_key](#input\_contrast\_api\_key) | Contrast API key | `string` | n/a | yes |
| <a name="input_contrast_service_key"></a> [contrast\_service\_key](#input\_contrast\_service\_key) | Contrast service key | `string` | n/a | yes |
| <a name="input_contrast_user_name"></a> [contrast\_user\_name](#input\_contrast\_user\_name) | Contrast user name | `string` | n/a | yes |
| <a name="input_proxy_password"></a> [proxy\_password](#input\_proxy\_password) | Proxy password | `string` | `""` | no |
| <a name="input_proxy_username"></a> [proxy\_username](#input\_proxy\_username) | Proxy username | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_contrast_enabled"></a> [contrast\_enabled](#output\_contrast\_enabled) | Example outputs |
| <a name="output_proxy_configured"></a> [proxy\_configured](#output\_proxy\_configured) | n/a |
<!-- END_TF_DOCS -->