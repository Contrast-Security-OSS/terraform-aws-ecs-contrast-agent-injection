# Jenkins Pipeline Integration

This directory contains resources for integrating the Contrast agent deployment with Jenkins CI/CD pipelines.

## Files

- `Jenkinsfile` - Example declarative pipeline
- `shared-library/` - Reusable Jenkins shared library functions
- `README.md` - This file

## Features

- Automated Java application detection
- Environment-based agent enablement
- Secure credential management
- Rollback capabilities

## Setup

1. **Configure Jenkins Credentials**
   - Add credentials for Contrast API keys
   - Add AWS credentials for deployment

2. **Install Required Plugins**
   - AWS Steps Plugin
   - Credentials Binding Plugin
   - Pipeline Plugin

3. **Configure Shared Library**
   - Add the shared library to Jenkins global configuration
   - Reference it in your Jenkinsfile

## Usage

### Basic Pipeline

```groovy
@Library('contrast-sidecar') _

pipeline {
    agent any
    
    parameters {
        booleanParam(
            name: 'ENABLE_CONTRAST_IN_TARGET_ENV',
            defaultValue: false,
            description: 'Enable Contrast agent for this deployment?'
        )
    }
    
    stages {
        stage('Deploy') {
            steps {
                deployWithContrast {
                    environment = 'staging'
                    appName = 'my-app'
                }
            }
        }
    }
}
```

### Advanced Pipeline with Auto-Detection

```groovy
pipeline {
    agent any
    
    stages {
        stage('Detect Application Type') {
            steps {
                script {
                    env.IS_JAVA_APP = sh(
                        script: '[ -f pom.xml ] || [ -f build.gradle ]',
                        returnStatus: true
                    ) == 0
                }
            }
        }
        
        stage('Deploy') {
            when {
                expression { env.IS_JAVA_APP == 'true' }
            }
            steps {
                deployECSWithContrast()
            }
        }
    }
}
```

## Environment Variables

The pipeline expects these environment variables:

- `TF_VAR_contrast_api_key` - From Jenkins credentials
- `TF_VAR_contrast_service_key` - From Jenkins credentials
- `TF_VAR_contrast_user_name` - From Jenkins credentials
- `ENABLE_CONTRAST_IN_TARGET_ENV` - Pipeline parameter

## Rollback

To rollback (disable Contrast):

1. Run the pipeline with `ENABLE_CONTRAST_IN_TARGET_ENV=false`
2. The deployment will create a new task definition without the agent
3. ECS will perform a rolling update

## Best Practices

1. **Start with Test Environments**: Enable Contrast in L17/test first
2. **Monitor Resources**: Check CloudWatch metrics after deployment
3. **Use Feature Flags**: Control rollout percentage through external flags
4. **Automate Testing**: Include Contrast validation in deployment tests
