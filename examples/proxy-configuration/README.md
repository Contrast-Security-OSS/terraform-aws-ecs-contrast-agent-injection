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
