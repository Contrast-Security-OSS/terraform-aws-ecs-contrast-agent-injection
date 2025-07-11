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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_contrast_agent_injection"></a> [contrast\_agent\_injection](#module\_contrast\_agent\_injection) | Contrast-Security-OSS/ecs-contrast-agent-injection/aws | ~> 1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.contrast](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_cluster.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_iam_role.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_cpu"></a> [app\_cpu](#input\_app\_cpu) | CPU units for the application container | `number` | `510` | no |
| <a name="input_app_image"></a> [app\_image](#input\_app\_image) | Docker image for the application | `string` | n/a | yes |
| <a name="input_app_memory"></a> [app\_memory](#input\_app\_memory) | Memory for the application container in MB | `number` | `1018` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Name of the application | `string` | `"java-example-app"` | no |
| <a name="input_app_port"></a> [app\_port](#input\_app\_port) | Port the application listens on | `number` | `8080` | no |
| <a name="input_application_code"></a> [application\_code](#input\_application\_code) | Application code this application should use in Contrast | `string` | `""` | no |
| <a name="input_application_group"></a> [application\_group](#input\_application\_group) | Name of the application group with which this application should be associated in Contrast | `string` | `""` | no |
| <a name="input_application_metadata"></a> [application\_metadata](#input\_application\_metadata) | Define a set of key=value pairs for specifying user-defined metadata associated with the application. Example: business-unit=accounting, office=Baltimore | `string` | `""` | no |
| <a name="input_application_session_metadata"></a> [application\_session\_metadata](#input\_application\_session\_metadata) | Provide metadata that is used to create a new session ID in Contrast. This value should be formatted as key=value pairs (conforming to RFC 2253). Mutually exclusive with application\_session\_id | `string` | `""` | no |
| <a name="input_application_tags"></a> [application\_tags](#input\_application\_tags) | Apply labels to an application. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3 | `string` | `""` | no |
| <a name="input_application_version"></a> [application\_version](#input\_application\_version) | Override the reported application version | `string` | `""` | no |
| <a name="input_assess_tags"></a> [assess\_tags](#input\_assess\_tags) | Apply a list of labels to vulnerabilities and preflight messages. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3 | `string` | `""` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones. If not specified, will use first 2 AZs in the region. | `list(string)` | `[]` | no |
| <a name="input_aws_profile"></a> [aws\_profile](#input\_aws\_profile) | AWS CLI profile to use | `string` | `"default"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_contrast_agent_version"></a> [contrast\_agent\_version](#input\_contrast\_agent\_version) | Specific version of the Contrast agent to use | `string` | `"latest"` | no |
| <a name="input_contrast_api_key"></a> [contrast\_api\_key](#input\_contrast\_api\_key) | Contrast API key | `string` | n/a | yes |
| <a name="input_contrast_api_url"></a> [contrast\_api\_url](#input\_contrast\_api\_url) | Contrast API URL | `string` | `"https://app.contrastsecurity.com/Contrast"` | no |
| <a name="input_contrast_enabled"></a> [contrast\_enabled](#input\_contrast\_enabled) | Enable Contrast agent | `bool` | `false` | no |
| <a name="input_contrast_log_level"></a> [contrast\_log\_level](#input\_contrast\_log\_level) | Log level for the Contrast agent | `string` | `"INFO"` | no |
| <a name="input_contrast_service_key"></a> [contrast\_service\_key](#input\_contrast\_service\_key) | Contrast service key | `string` | n/a | yes |
| <a name="input_contrast_user_name"></a> [contrast\_user\_name](#input\_contrast\_user\_name) | Contrast user name | `string` | n/a | yes |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired number of tasks | `number` | `1` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name | `string` | `"DEVELOPMENT"` | no |
| <a name="input_inventory_tags"></a> [inventory\_tags](#input\_inventory\_tags) | Apply a list of labels to libraries. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3 | `string` | `""` | no |
| <a name="input_server_tags"></a> [server\_tags](#input\_server\_tags) | Apply a list of labels to the server. Labels must be formatted as a comma-delimited list. Example: label1, label2, label3 | `string` | `""` | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | CPU units for the task (256, 512, 1024, 2048, 4096) | `string` | `"512"` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | Memory for the task in MB | `string` | `"1024"` | no |
| <a name="input_team"></a> [team](#input\_team) | Team name for tagging | `string` | `"platform"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones_used"></a> [availability\_zones\_used](#output\_availability\_zones\_used) | The availability zones used for the deployment |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Outputs |
| <a name="output_contrast_enabled"></a> [contrast\_enabled](#output\_contrast\_enabled) | n/a |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | The private subnet IDs created |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | The public subnet IDs created |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | n/a |
| <a name="output_subnet_ids_used"></a> [subnet\_ids\_used](#output\_subnet\_ids\_used) | The subnet IDs that are being used for the ECS service |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | n/a |
| <a name="output_vpc_cidr"></a> [vpc\_cidr](#output\_vpc\_cidr) | The CIDR block of the created VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The VPC ID being used |
<!-- END_TF_DOCS -->