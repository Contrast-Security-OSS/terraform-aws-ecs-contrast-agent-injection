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

The proxy configuration allows the Contrast agent to communicate through corporate proxies:

- **host**: Proxy hostname or IP address
- **port**: Proxy port number
- **username**: Proxy authentication username (optional)
- **password**: Proxy authentication password (optional)

## Environment Variables

The proxy configuration sets these environment variables for the Contrast agent:

- `CONTRAST__PROXY__HOST`
- `CONTRAST__PROXY__PORT`
- `CONTRAST__PROXY__USERNAME`
- `CONTRAST__PROXY__PASSWORD`

## Security Note

Proxy credentials are marked as sensitive and should be managed securely, preferably through:
- AWS Secrets Manager
- Environment variables in CI/CD
- Encrypted terraform.tfvars files
