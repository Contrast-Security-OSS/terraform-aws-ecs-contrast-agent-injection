# Docker Images

This directory contains Docker images used in the Contrast agent injection deployment.

## Official Images

The recommended approach is to use the official Contrast images from Docker Hub:
- `contrast/agent-java:latest`
- `contrast/agent-java:3.12.2` (specific version)

## Custom Init Container

If you need to create a custom init container (e.g., for specific configurations or additional tools), use the provided Dockerfile.

### Building Custom Image

```bash
docker build -t my-org/contrast-init:latest .
docker push my-org/contrast-init:latest
```

### Using Custom Image

In your Terraform configuration:

```hcl
module "contrast_sidecar" {
  source = "./terraform-module"
  
  init_container_image = "my-org/contrast-init:latest"
  # ... other configuration
}
```

## Image Contents

The init container should include:
- The Contrast agent JAR file
- Any initialization scripts
- Minimal OS utilities (sh, cp)

## Security Considerations

- Keep images minimal to reduce attack surface
- Scan images for vulnerabilities
- Use specific version tags in production
- Store images in private registries
