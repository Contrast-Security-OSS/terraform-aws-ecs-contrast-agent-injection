# Basic Java Application Example

This example demonstrates how to integrate the Contrast agent sidecar with a basic Java application running on ECS.

## Prerequisites

- AWS Account with ECS/Fargate access
- Contrast Security account with API credentials
- Existing VPC and subnets
- Java application Docker image

## Files

- `main.tf` - Main Terraform configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars.example` - Example variable values
- `start.sh` - Example application startup script

## Setup

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Fill in your actual values
3. Run:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

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
