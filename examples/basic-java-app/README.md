# Basic Java Application Example

This example demonstrates how to integrate the Contrast agent injection with a basic Java application running on ECS.

## Prerequisites

- AWS Account with ECS/Fargate access
- Contrast Security account with API credentials
- Java application Docker image

The example will create its own VPC, subnets, NAT gateways, and all necessary networking infrastructure.

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars.example` - Example variable values
- `start.sh` - Example application startup script

## Setup

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Fill in your actual values (the only required values are `app_image` and Contrast credentials if `contrast_enabled=true`)
3. Run:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

The configuration will automatically create:
- VPC with public and private subnets across 2 availability zones
- Internet Gateway and NAT Gateways for network connectivity
- Route tables with proper routing configuration
- Security groups and necessary IAM roles

## Application Modifications

Your Java application needs a modified entrypoint script. See `start.sh` for an example.

## Testing

After deployment:

1. Check ECS console for running tasks
2. Verify both containers start successfully
3. Check CloudWatch logs for Contrast agent initialization
4. Verify application appears in Contrast dashboard

## Cleanup

```bash
terraform destroy
```
