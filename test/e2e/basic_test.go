package e2e

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/your-org/ecs-contrast-sidecar/test/helpers"
)

// TestBasicFunctionality tests the basic functionality of the Contrast sidecar
func TestBasicFunctionality(t *testing.T) {
	t.Parallel()

	// Skip test if required environment variables are not set
	skipIfMissingEnvVars(t)

	// Generate unique ID for test resources
	uniqueId := fmt.Sprintf("basic-%s", random.UniqueId())

	// Setup Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../fixtures/basic",
		Vars: map[string]interface{}{
			"unique_id":            uniqueId,
			"contrast_enabled":     true,
			"contrast_api_key":     os.Getenv("CONTRAST_API_KEY"),
			"contrast_service_key": os.Getenv("CONTRAST_SERVICE_KEY"),
			"contrast_user_name":   os.Getenv("CONTRAST_USER_NAME"),
			"contrast_api_url":     getContrastAPIURL(),
			"app_image":            "webgoat/webgoat:latest",
		},
		NoColor:            true,
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	// Clean up resources at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	appName := terraform.Output(t, terraformOptions, "app_name")
	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")
	taskDefArn := terraform.Output(t, terraformOptions, "task_definition_arn")
	contrastEnabled := terraform.Output(t, terraformOptions, "contrast_enabled")
	agentPath := terraform.Output(t, terraformOptions, "contrast_agent_path")
	logGroupApp := terraform.Output(t, terraformOptions, "log_group_app")
	logGroupContrast := terraform.Output(t, terraformOptions, "log_group_contrast")

	// Validate outputs
	assert.NotEmpty(t, appName, "App name should not be empty")
	assert.NotEmpty(t, clusterName, "Cluster name should not be empty")
	assert.NotEmpty(t, serviceName, "Service name should not be empty")
	assert.NotEmpty(t, taskDefArn, "Task definition ARN should not be empty")
	assert.Equal(t, "true", contrastEnabled, "Contrast should be enabled")
	assert.Contains(t, agentPath, "contrast-agent.jar", "Agent path should contain JAR file")
	assert.NotEmpty(t, logGroupApp, "App log group should not be empty")
	assert.NotEmpty(t, logGroupContrast, "Contrast log group should not be empty")

	// Setup AWS helper
	awsHelper := helpers.NewAWSHelper(t, "us-east-1")

	// Wait for ECS service to be stable
	t.Logf("Waiting for ECS service %s to be stable...", serviceName)
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	// Validate task definition structure
	t.Logf("Validating task definition structure...")
	taskDef := awsHelper.GetECSTaskDefinition(t, taskDefArn)
	validateTaskDefinitionStructure(t, taskDef)

	// Get running tasks
	t.Logf("Getting running tasks...")
	tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
	require.NotEmpty(t, tasks, "Service should have running tasks")

	// Wait for logs to appear and validate Contrast initialization
	t.Logf("Waiting for Contrast agent logs...")
	time.Sleep(2 * time.Minute) // Give time for containers to start and log

	testStart := time.Now().Add(-5 * time.Minute)
	contrastFound := awsHelper.CheckContrastAgentInLogs(t, logGroupContrast, testStart)
	assert.True(t, contrastFound, "Contrast agent initialization should be found in logs")

	// Setup Contrast helper and validate agent registration
	contrastHelper := helpers.NewContrastHelper(
		getContrastAPIURL(),
		os.Getenv("CONTRAST_API_KEY"),
		os.Getenv("CONTRAST_SERVICE_KEY"),
		os.Getenv("CONTRAST_USER_NAME"),
	)

	// Test Contrast connectivity
	t.Logf("Testing Contrast API connectivity...")
	contrastHelper.ValidateConnectivity(t)

	// Wait for application to appear in Contrast (this may take a while)
	t.Logf("Waiting for application to appear in Contrast...")
	app := contrastHelper.WaitForApplication(t, appName, 10*time.Minute)
	assert.NotNil(t, app, "Application should appear in Contrast")

	// Wait for server to appear in Contrast
	t.Logf("Waiting for server to appear in Contrast...")
	expectedServerName := fmt.Sprintf("%s-us-east-1", appName)
	server := contrastHelper.WaitForServer(t, expectedServerName, 5*time.Minute)
	assert.NotNil(t, server, "Server should appear in Contrast")

	// Wait for agent to be active
	t.Logf("Waiting for agent to be active...")
	agent := contrastHelper.WaitForAgent(t, appName, 5*time.Minute)
	assert.NotNil(t, agent, "Agent should be active in Contrast")

	// Validate agent configuration
	t.Logf("Validating agent configuration...")
	contrastHelper.ValidateAgentConfiguration(t, appName, "DEVELOPMENT")

	t.Logf("Basic functionality test completed successfully!")
}

// TestDisabledAgent tests that the module works correctly when the agent is disabled
func TestDisabledAgent(t *testing.T) {
	t.Parallel()

	uniqueId := fmt.Sprintf("disabled-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../fixtures/basic",
		Vars: map[string]interface{}{
			"unique_id":            uniqueId,
			"contrast_enabled":     false,
			"contrast_api_key":     "dummy-key", // Dummy values when disabled
			"contrast_service_key": "dummy-service-key",
			"contrast_user_name":   "dummy-user",
			"app_image":            "nginx:latest",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	contrastEnabled := terraform.Output(t, terraformOptions, "contrast_enabled")
	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")
	taskDefArn := terraform.Output(t, terraformOptions, "task_definition_arn")

	// Validate outputs
	assert.Equal(t, "false", contrastEnabled, "Contrast should be disabled")

	// When contrast is disabled, the agent_path output should not exist
	// We expect this to fail, so we'll check it doesn't exist in the state
	_, err := terraform.OutputE(t, terraformOptions, "contrast_agent_path")
	assert.Error(t, err, "Agent path output should not exist when contrast is disabled")
	assert.Contains(t, err.Error(), "Output \"contrast_agent_path\" not found", "Should get specific 'not found' error")

	// Setup AWS helper
	awsHelper := helpers.NewAWSHelper(t, "us-east-1")

	// Wait for service to be stable
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	// Validate task definition does not include Contrast components
	taskDef := awsHelper.GetECSTaskDefinition(t, taskDefArn)
	validateTaskDefinitionStructure(t, taskDef)

	t.Logf("Disabled agent test completed successfully!")
}

// TestAgentToggle tests enabling and then disabling the agent
func TestAgentToggle(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	uniqueId := fmt.Sprintf("toggle-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../fixtures/basic",
		Vars: map[string]interface{}{
			"unique_id":            uniqueId,
			"contrast_enabled":     true,
			"contrast_api_key":     os.Getenv("CONTRAST_API_KEY"),
			"contrast_service_key": os.Getenv("CONTRAST_SERVICE_KEY"),
			"contrast_user_name":   os.Getenv("CONTRAST_USER_NAME"),
			"contrast_api_url":     getContrastAPIURL(),
			"app_image":            "nginx:latest",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// First deployment with agent enabled
	t.Logf("Deploying with Contrast agent enabled...")
	terraform.InitAndApply(t, terraformOptions)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")
	contrastEnabled := terraform.Output(t, terraformOptions, "contrast_enabled")

	assert.Equal(t, "true", contrastEnabled, "Contrast should be enabled initially")

	awsHelper := helpers.NewAWSHelper(t, "us-east-1")
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	// Now disable the agent
	t.Logf("Disabling Contrast agent...")
	terraformOptions.Vars["contrast_enabled"] = false
	terraformOptions.Vars["contrast_api_key"] = "dummy-key"
	terraformOptions.Vars["contrast_service_key"] = "dummy-service-key"
	terraformOptions.Vars["contrast_user_name"] = "dummy-user"

	terraform.Apply(t, terraformOptions)

	// Validate agent is now disabled
	contrastEnabled = terraform.Output(t, terraformOptions, "contrast_enabled")
	agentPath := terraform.Output(t, terraformOptions, "contrast_agent_path")

	assert.Equal(t, "false", contrastEnabled, "Contrast should be disabled after toggle")
	assert.Empty(t, agentPath, "Agent path should be empty after disable")

	// Wait for service to stabilize after update
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	t.Logf("Agent toggle test completed successfully!")
}

// validateTaskDefinitionStructure validates the task definition structure
func validateTaskDefinitionStructure(t *testing.T, taskDef interface{}) {
	// This would require proper AWS SDK types and validation logic
	// For now, we'll keep it simple
	require.NotNil(t, taskDef, "Task definition should not be nil")

	// TODO: Add detailed validation of container definitions, volumes, etc.
	// This would involve parsing the JSON and checking for:
	// - Presence/absence of contrast-init container
	// - Presence/absence of contrast volume
	// - Correct environment variables
	// - Correct mount points and dependencies
}

// skipIfMissingEnvVars skips the test if required environment variables are missing
func skipIfMissingEnvVars(t *testing.T) {
	requiredVars := []string{
		"CONTRAST_API_KEY",
		"CONTRAST_SERVICE_KEY",
		"CONTRAST_USER_NAME",
	}

	for _, envVar := range requiredVars {
		if os.Getenv(envVar) == "" {
			t.Skipf("Skipping test: %s environment variable not set", envVar)
		}
	}
}

// getContrastAPIURL returns the Contrast API URL from environment or default
func getContrastAPIURL() string {
	apiURL := os.Getenv("CONTRAST_API_URL")
	if apiURL == "" {
		return "https://app.contrastsecurity.com/Contrast"
	}
	return apiURL
}
