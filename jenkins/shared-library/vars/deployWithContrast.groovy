// deployWithContrast.groovy
// Shared library function for deploying applications with Contrast agent

def call(Map config = [:]) {
    // Default values
    def defaults = [
        environment: 'development',
        appName: env.APP_NAME ?: '',
        imageTag: 'latest',
        enableContrast: params.ENABLE_CONTRAST_IN_TARGET_ENV ?: false,
        terraformDir: 'terraform/environments',
        awsRegion: 'us-east-1'
    ]
    
    // Merge defaults with provided config
    def settings = defaults + config
    
    // Validate required parameters
    if (!settings.appName) {
        error("Application name is required")
    }
    
    echo "Deploying ${settings.appName} to ${settings.environment}"
    echo "Contrast agent enabled: ${settings.enableContrast}"
    
    // Detect if this is a Java application
    def isJavaApp = detectJavaApplication(settings.appName)
    
    // Configure Contrast based on app type and settings
    def contrastEnabled = isJavaApp && settings.enableContrast
    
    // Set environment variables for Terraform
    env.TF_VAR_app_name = settings.appName
    env.TF_VAR_environment = settings.environment
    env.TF_VAR_app_image = settings.imageTag
    env.TF_VAR_contrast_enabled = contrastEnabled.toString()
    
    // Fetch Contrast credentials if enabled
    if (contrastEnabled) {
        withCredentials([
            string(credentialsId: 'contrast-api-key', variable: 'CONTRAST_API_KEY'),
            string(credentialsId: 'contrast-service-key', variable: 'CONTRAST_SERVICE_KEY'),
            string(credentialsId: 'contrast-user-name', variable: 'CONTRAST_USER_NAME')
        ]) {
            env.TF_VAR_contrast_api_key = CONTRAST_API_KEY
            env.TF_VAR_contrast_service_key = CONTRAST_SERVICE_KEY
            env.TF_VAR_contrast_user_name = CONTRAST_USER_NAME
            
            // Run Terraform deployment
            runTerraformDeployment(settings)
        }
    } else {
        // Run Terraform deployment without Contrast credentials
        runTerraformDeployment(settings)
    }
    
    // Validate deployment if Contrast was enabled
    if (contrastEnabled) {
        validateContrastDeployment(settings.appName)
    }
}

def detectJavaApplication(appName) {
    // Check for Java build files
    if (fileExists('pom.xml') || fileExists('build.gradle') || fileExists('build.gradle.kts')) {
        echo "Detected Java application based on build files"
        return true
    }
    
    // Check Docker image labels
    try {
        def imageLang = sh(
            script: """
                docker inspect --format '{{index .Config.Labels "com.liberty.app.language"}}' \${ECR_REGISTRY}/\${appName}:latest
            """,
            returnStdout: true
        ).trim()
        
        if (imageLang == 'java') {
            echo "Detected Java application based on Docker image label"
            return true
        }
    } catch (Exception e) {
        echo "Could not inspect Docker image: ${e.message}"
    }
    
    echo "Not detected as a Java application"
    return false
}

def runTerraformDeployment(settings) {
    dir("${settings.terraformDir}/${settings.environment}") {
        // Initialize Terraform
        sh """
            terraform init \
                -backend-config="key=${settings.appName}/${settings.environment}/terraform.tfstate"
        """
        
        // Plan deployment
        sh """
            terraform plan \
                -out=tfplan
        """
        
        // Apply deployment
        sh "terraform apply -auto-approve tfplan"
    }
}

def validateContrastDeployment(appName) {
    echo "Validating Contrast agent deployment..."
    
    // Wait for service to stabilize
    sleep(time: 30, unit: 'SECONDS')
    
    // Check CloudWatch logs
    def logGroupName = "/ecs/${appName}/contrast-init"
    def validation = sh(
        script: """
            aws logs filter-log-events \
                --log-group-name ${logGroupName} \
                --filter-pattern '"Contrast agent copied successfully"' \
                --max-items 1 \
                --query 'events[0].message' \
                --output text
        """,
        returnStatus: true
    )
    
    if (validation == 0) {
        echo "✓ Contrast agent deployment validated successfully"
    } else {
        echo "⚠ Could not validate Contrast agent deployment"
    }
}
