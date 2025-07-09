# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of the ECS Contrast Agent Injection Terraform module
- Agent injection pattern using init containers and shared volumes
- Support for conditional agent deployment via `enabled` variable
- Comprehensive proxy configuration support
- Environment-based configuration with validation
- Automatic server naming based on region
- Custom resource limits for init container
- Support for additional environment variables
- Comprehensive test suite with 30+ test cases
- Security scanning configuration with Checkov
- Complete working examples
- Terraform Registry ready structure

### Features
- Zero application image modifications required
- Dynamic enable/disable through Terraform variables
- Environment-based configuration (no config files needed)
- Support for proxy configurations (Basic, Digest, NTLM auth)
- Automatic server naming based on region
- Compatible with existing APM agents (DataDog, etc.)
- Production-ready security and resource configurations

### Documentation
- Comprehensive README with usage examples
- API documentation for all inputs and outputs
- Architecture diagrams and deployment patterns
- Security scanning guides
- Contributing guidelines

## [1.0.0] - TBD

### Added
- Initial stable release for Terraform Registry
