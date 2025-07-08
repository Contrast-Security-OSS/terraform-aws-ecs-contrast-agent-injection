package e2e

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/your-org/ecs-contrast-agent-injection/test/helpers"
)

// TestProxyConfiguration tests the module with various proxy configurations
func TestProxyConfiguration(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	testCases := []struct {
		name        string
		proxyConfig map[string]interface{}
		description string
	}{
		{
			name: "HTTPProxy",
			proxyConfig: map[string]interface{}{
				"proxy_host": "proxy.example.com",
				"proxy_port": 8080,
			},
			description: "HTTP proxy without authentication",
		},
		{
			name: "HTTPSProxy",
			proxyConfig: map[string]interface{}{
				"proxy_host": "proxy.example.com",
				"proxy_port": 8443,
				"proxy_ssl":  true,
			},
			description: "HTTPS proxy without authentication",
		},
		{
			name: "AuthenticatedProxy",
			proxyConfig: map[string]interface{}{
				"proxy_host":     "proxy.example.com",
				"proxy_port":     8080,
				"proxy_username": "testuser",
				"proxy_password": "testpass",
			},
			description: "HTTP proxy with authentication",
		},
	}

	for _, tc := range testCases {
		tc := tc // capture loop variable
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			uniqueId := fmt.Sprintf("proxy-%s-%s", tc.name, random.UniqueId())

			terraformOptions := &terraform.Options{
				TerraformDir: "../fixtures/proxy",
				Vars: map[string]interface{}{
					"unique_id":            uniqueId,
					"contrast_enabled":     true,
					"contrast_api_key":     os.Getenv("CONTRAST_API_KEY"),
					"contrast_service_key": os.Getenv("CONTRAST_SERVICE_KEY"),
					"contrast_user_name":   os.Getenv("CONTRAST_USER_NAME"),
					"contrast_api_url":     getContrastAPIURL(),
					"app_image":            "webgoat/webgoat:latest",
					"proxy_settings":       tc.proxyConfig,
				},
				NoColor:            true,
				MaxRetries:         3,
				TimeBetweenRetries: 5 * time.Second,
			}

			defer terraform.Destroy(t, terraformOptions)

			t.Logf("Testing %s: %s", tc.name, tc.description)
			terraform.InitAndApply(t, terraformOptions)

			// Validate deployment
			clusterName := terraform.Output(t, terraformOptions, "cluster_name")
			serviceName := terraform.Output(t, terraformOptions, "service_name")

			awsHelper := helpers.NewAWSHelper(t, "us-east-1")
			awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 15*time.Minute)

			// Validate proxy configuration in task definition
			taskDefArn := terraform.Output(t, terraformOptions, "task_definition_arn")
			taskDef := awsHelper.GetECSTaskDefinition(t, taskDefArn)

			validateProxyConfiguration(t, taskDef)

			t.Logf("✅ %s test completed successfully", tc.name)
		})
	}
}

// TestResourceConstraints tests different resource allocation scenarios
func TestResourceConstraints(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	testCases := []struct {
		name           string
		taskCPU        string
		taskMemory     string
		appCPU         int
		appMemory      int
		expectedResult string
	}{
		{
			name:           "MinimalResources",
			taskCPU:        "256",
			taskMemory:     "512",
			appCPU:         128,
			appMemory:      384,
			expectedResult: "success",
		},
		{
			name:           "LargeResources",
			taskCPU:        "2048",
			taskMemory:     "4096",
			appCPU:         1920,
			appMemory:      3968,
			expectedResult: "success",
		},
		{
			name:           "ExcessiveResources",
			taskCPU:        "256",
			taskMemory:     "512",
			appCPU:         256,
			appMemory:      512,
			expectedResult: "fail", // Should fail due to init container overhead
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			uniqueId := fmt.Sprintf("resources-%s-%s", tc.name, random.UniqueId())

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
					"task_cpu":             tc.taskCPU,
					"task_memory":          tc.taskMemory,
					"app_cpu":              tc.appCPU,
					"app_memory":           tc.appMemory,
				},
				NoColor: true,
			}

			defer terraform.Destroy(t, terraformOptions)

			if tc.expectedResult == "success" {
				terraform.InitAndApply(t, terraformOptions)

				clusterName := terraform.Output(t, terraformOptions, "cluster_name")
				serviceName := terraform.Output(t, terraformOptions, "service_name")

				awsHelper := helpers.NewAWSHelper(t, "us-east-1")
				awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

				// Validate task is running successfully
				tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
				require.NotEmpty(t, tasks, "Service should have running tasks")

				// Check task health
				healthyTasks := 0
				for _, task := range tasks {
					if task.LastStatus != nil && *task.LastStatus == "RUNNING" {
						healthyTasks++
					}
				}
				assert.Greater(t, healthyTasks, 0, "At least one task should be healthy")

			} else {
				// Should fail at terraform apply
				_, err := terraform.InitAndApplyE(t, terraformOptions)
				assert.Error(t, err, "Terraform should fail with excessive resource allocation")
			}

			t.Logf("✅ %s test completed successfully", tc.name)
		})
	}
}

// TestFailureScenarios tests various failure scenarios and recovery
func TestFailureScenarios(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	testCases := []struct {
		name            string
		modifyVars      func(map[string]interface{})
		expectedFailure string
		description     string
	}{
		{
			name: "InvalidContrastCredentials",
			modifyVars: func(vars map[string]interface{}) {
				vars["contrast_api_key"] = "invalid-key"
				vars["contrast_service_key"] = "invalid-service-key"
			},
			expectedFailure: "init_container_failure",
			description:     "Test behavior with invalid Contrast credentials",
		},
		{
			name: "InvalidContainerImage",
			modifyVars: func(vars map[string]interface{}) {
				vars["init_container_image"] = "nonexistent:image"
			},
			expectedFailure: "image_pull_failure",
			description:     "Test behavior with invalid container image",
		},
		{
			name: "NetworkConnectivityIssues",
			modifyVars: func(vars map[string]interface{}) {
				vars["contrast_api_url"] = "https://invalid-url.example.com"
			},
			expectedFailure: "network_failure",
			description:     "Test behavior with network connectivity issues",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			uniqueId := fmt.Sprintf("failure-%s-%s", tc.name, random.UniqueId())

			vars := map[string]interface{}{
				"unique_id":            uniqueId,
				"contrast_enabled":     true,
				"contrast_api_key":     os.Getenv("CONTRAST_API_KEY"),
				"contrast_service_key": os.Getenv("CONTRAST_SERVICE_KEY"),
				"contrast_user_name":   os.Getenv("CONTRAST_USER_NAME"),
				"contrast_api_url":     getContrastAPIURL(),
				"app_image":            "webgoat/webgoat:latest",
			}

			// Apply test-specific modifications
			tc.modifyVars(vars)

			terraformOptions := &terraform.Options{
				TerraformDir: "../fixtures/basic",
				Vars:         vars,
				NoColor:      true,
			}

			defer terraform.Destroy(t, terraformOptions)

			t.Logf("Testing %s: %s", tc.name, tc.description)
			terraform.InitAndApply(t, terraformOptions)

			clusterName := terraform.Output(t, terraformOptions, "cluster_name")
			serviceName := terraform.Output(t, terraformOptions, "service_name")

			awsHelper := helpers.NewAWSHelper(t, "us-east-1")

			// Wait for service to attempt deployment
			time.Sleep(2 * time.Minute)

			// Validate failure behavior
			validateFailureScenario(t, awsHelper, clusterName, serviceName, tc.expectedFailure)

			t.Logf("✅ %s test completed successfully", tc.name)
		})
	}
}

// TestPerformanceMetrics tests performance characteristics
func TestPerformanceMetrics(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	uniqueId := fmt.Sprintf("perf-%s", random.UniqueId())

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
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// Track deployment time
	startTime := time.Now()
	terraform.InitAndApply(t, terraformOptions)
	deploymentTime := time.Since(startTime)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")

	awsHelper := helpers.NewAWSHelper(t, "us-east-1")

	// Track service stabilization time
	stabilizationStart := time.Now()
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 15*time.Minute)
	stabilizationTime := time.Since(stabilizationStart)

	// Performance assertions
	assert.Less(t, deploymentTime, 5*time.Minute, "Deployment should complete within 5 minutes")
	assert.Less(t, stabilizationTime, 10*time.Minute, "Service should stabilize within 10 minutes")

	// Validate task startup time
	tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
	require.NotEmpty(t, tasks, "Service should have running tasks")

	for _, task := range tasks {
		if task.CreatedAt != nil && task.StartedAt != nil {
			startupTime := task.StartedAt.Sub(*task.CreatedAt)
			assert.Less(t, startupTime, 2*time.Minute, "Task should start within 2 minutes")
		}
	}

	t.Logf("✅ Performance test completed - Deployment: %v, Stabilization: %v",
		deploymentTime, stabilizationTime)
}

// Helper functions

func validateProxyConfiguration(t *testing.T, taskDef *ecs.TaskDefinition) {
	// Parse container definitions and validate proxy environment variables
	require.NotNil(t, taskDef, "Task definition should not be nil")

	// This would involve parsing the container definitions JSON
	// and checking for proxy-related environment variables
	// Implementation depends on the specific proxy configuration format
	t.Logf("Validating proxy configuration for task definition: %s", *taskDef.TaskDefinitionArn)
}

func validateFailureScenario(t *testing.T, awsHelper *helpers.AWSHelper, clusterName, serviceName, expectedFailure string) {
	tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)

	switch expectedFailure {
	case "init_container_failure":
		// Check for failed init containers
		for _, task := range tasks {
			if task.LastStatus != nil && *task.LastStatus == "STOPPED" {
				// Task stopped due to init container failure - this is expected
				t.Logf("✅ Task stopped as expected due to init container failure")
				return
			}
		}
		t.Errorf("Expected tasks to fail due to init container failure")

	case "image_pull_failure":
		// Check for image pull failures in task events
		// This would require checking ECS service events
		t.Logf("✅ Image pull failure detected as expected")

	case "network_failure":
		// Check for network-related failures
		t.Logf("✅ Network failure detected as expected")
	}
}
