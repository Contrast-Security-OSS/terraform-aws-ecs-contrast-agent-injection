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

// TestChaosEngineering tests system resilience under various failure conditions
func TestChaosEngineering(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	uniqueId := fmt.Sprintf("chaos-%s", random.UniqueId())

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
			"desired_count":        2, // Multiple tasks for chaos testing
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// Initial deployment
	terraform.InitAndApply(t, terraformOptions)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")

	awsHelper := helpers.NewAWSHelper(t, "us-east-1")
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	// Test 1: Task termination resilience
	t.Run("TaskTerminationResilience", func(t *testing.T) {
		t.Logf("Testing task termination resilience...")

		// Get initial tasks
		initialTasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
		require.NotEmpty(t, initialTasks, "Service should have running tasks")

		// In a real implementation, you would terminate a task here
		// For now, we'll simulate by updating the desired count to force a restart
		t.Logf("Simulating task termination by updating service...")

		// Scale down and then back up to force task replacement
		terraformOptions.Vars["desired_count"] = 1
		terraform.Apply(t, terraformOptions)

		time.Sleep(30 * time.Second)

		terraformOptions.Vars["desired_count"] = 2
		terraform.Apply(t, terraformOptions)

		// Wait for service to recover
		awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

		// Verify service recovered
		recoveredTasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
		assert.Len(t, recoveredTasks, 2, "Service should recover to desired count")

		healthyTasks := 0
		for _, task := range recoveredTasks {
			if task.LastStatus != nil && *task.LastStatus == "RUNNING" {
				healthyTasks++
			}
		}
		assert.Equal(t, 2, healthyTasks, "All tasks should be healthy after recovery")
	})

	// Test 2: Network partition simulation
	t.Run("NetworkPartitionSimulation", func(t *testing.T) {
		t.Logf("Testing network partition simulation...")

		// This would involve temporarily modifying security group rules
		// to simulate network partitions and test recovery

		// For now, we'll simulate by updating with invalid API URL
		originalAPIURL := os.Getenv("CONTRAST_API_URL")
		terraformOptions.Vars["contrast_api_url"] = "https://invalid-url.example.com"

		// Apply change
		terraform.Apply(t, terraformOptions)

		// Wait for deployment
		time.Sleep(2 * time.Minute)

		// Restore original configuration
		terraformOptions.Vars["contrast_api_url"] = originalAPIURL
		terraform.Apply(t, terraformOptions)

		// Verify service recovers
		awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 15*time.Minute)

		tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
		assert.NotEmpty(t, tasks, "Service should have recovered from network partition")
	})

	// Test 3: Resource exhaustion
	t.Run("ResourceExhaustion", func(t *testing.T) {
		t.Logf("Testing resource exhaustion handling...")

		// Scale up to test resource limits
		terraformOptions.Vars["desired_count"] = 5
		terraform.Apply(t, terraformOptions)

		// Wait and check if all tasks can be scheduled
		time.Sleep(5 * time.Minute)

		tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
		t.Logf("Tasks after scale-up: %d", len(tasks))

		// Scale back down
		terraformOptions.Vars["desired_count"] = 2
		terraform.Apply(t, terraformOptions)

		awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

		finalTasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
		assert.Len(t, finalTasks, 2, "Service should scale back down correctly")
	})

	t.Logf("✅ Chaos engineering tests completed successfully")
}

// TestLongRunningStability tests long-running stability and resource usage
func TestLongRunningStability(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping long-running stability test in short mode")
	}

	t.Parallel()

	skipIfMissingEnvVars(t)

	uniqueId := fmt.Sprintf("stability-%s", random.UniqueId())

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

	// Deploy infrastructure
	terraform.InitAndApply(t, terraformOptions)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")

	awsHelper := helpers.NewAWSHelper(t, "us-east-1")
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	// Monitor for 30 minutes
	monitoringDuration := 30 * time.Minute
	checkInterval := 2 * time.Minute

	t.Logf("Starting %v stability monitoring with %v intervals", monitoringDuration, checkInterval)

	startTime := time.Now()
	var measurements []StabilityMeasurement

	for time.Since(startTime) < monitoringDuration {
		measurement := collectStabilityMetrics(t, awsHelper, clusterName, serviceName)
		measurements = append(measurements, measurement)

		t.Logf("Stability check at %v: %d healthy tasks, %d total tasks",
			time.Since(startTime), measurement.HealthyTasks, measurement.TotalTasks)

		time.Sleep(checkInterval)
	}

	// Analyze results
	analyzeStabilityResults(t, measurements)

	t.Logf("✅ Long-running stability test completed successfully")
}

// TestMultiRegionDeployment tests deployment across multiple regions
func TestMultiRegionDeployment(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	regions := []string{"us-east-1", "us-west-2"}

	for _, region := range regions {
		region := region // capture loop variable
		t.Run(fmt.Sprintf("Region-%s", region), func(t *testing.T) {
			t.Parallel()

			uniqueId := fmt.Sprintf("multi-region-%s-%s", region, random.UniqueId())

			terraformOptions := &terraform.Options{
				TerraformDir: "../fixtures/basic",
				Vars: map[string]interface{}{
					"unique_id":            uniqueId,
					"aws_region":           region,
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

			terraform.InitAndApply(t, terraformOptions)

			clusterName := terraform.Output(t, terraformOptions, "cluster_name")
			serviceName := terraform.Output(t, terraformOptions, "service_name")

			awsHelper := helpers.NewAWSHelper(t, region)
			awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

			// Validate deployment in this region
			tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
			assert.NotEmpty(t, tasks, "Service should have tasks in region %s", region)

			t.Logf("✅ Multi-region deployment test completed for region %s", region)
		})
	}
}

// TestVersionUpgrade tests upgrading the Contrast agent version
func TestVersionUpgrade(t *testing.T) {
	t.Parallel()

	skipIfMissingEnvVars(t)

	uniqueId := fmt.Sprintf("upgrade-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../fixtures/basic",
		Vars: map[string]interface{}{
			"unique_id":              uniqueId,
			"contrast_enabled":       true,
			"contrast_api_key":       os.Getenv("CONTRAST_API_KEY"),
			"contrast_service_key":   os.Getenv("CONTRAST_SERVICE_KEY"),
			"contrast_user_name":     os.Getenv("CONTRAST_USER_NAME"),
			"contrast_api_url":       getContrastAPIURL(),
			"app_image":              "webgoat/webgoat:latest",
			"contrast_agent_version": "3.12.1", // Start with older version
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	// Initial deployment with older version
	t.Logf("Deploying with Contrast agent version 3.12.1...")
	terraform.InitAndApply(t, terraformOptions)

	clusterName := terraform.Output(t, terraformOptions, "cluster_name")
	serviceName := terraform.Output(t, terraformOptions, "service_name")

	awsHelper := helpers.NewAWSHelper(t, "us-east-1")
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 10*time.Minute)

	// Verify initial deployment
	initialTasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
	require.NotEmpty(t, initialTasks, "Service should have tasks with initial version")

	// Upgrade to newer version
	t.Logf("Upgrading to Contrast agent version 3.12.2...")
	terraformOptions.Vars["contrast_agent_version"] = "3.12.2"
	terraform.Apply(t, terraformOptions)

	// Wait for rolling update to complete
	awsHelper.WaitForECSServiceStable(t, clusterName, serviceName, 15*time.Minute)

	// Verify upgrade completed
	upgradedTasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)
	assert.NotEmpty(t, upgradedTasks, "Service should have tasks after upgrade")

	// Validate that tasks are running the new version
	// This would require checking the task definition for the new image version
	taskDefArn := terraform.Output(t, terraformOptions, "task_definition_arn")
	taskDef := awsHelper.GetECSTaskDefinition(t, taskDefArn)

	// Verify the task definition contains the new version
	assert.Contains(t, *taskDef.TaskDefinitionArn, "3.12.2", "Task definition should reference new version")

	t.Logf("✅ Version upgrade test completed successfully")
}

// Helper types and functions

type StabilityMeasurement struct {
	Timestamp    time.Time
	TotalTasks   int
	HealthyTasks int
	CPUUsage     float64
	MemoryUsage  float64
}

func collectStabilityMetrics(t *testing.T, awsHelper *helpers.AWSHelper, clusterName, serviceName string) StabilityMeasurement {
	tasks := awsHelper.GetECSServiceTasks(t, clusterName, serviceName)

	measurement := StabilityMeasurement{
		Timestamp:  time.Now(),
		TotalTasks: len(tasks),
	}

	for _, task := range tasks {
		if task.LastStatus != nil && *task.LastStatus == "RUNNING" {
			measurement.HealthyTasks++
		}
	}

	// In a real implementation, you would collect CPU and memory metrics
	// from CloudWatch or ECS task definitions
	measurement.CPUUsage = 0.0    // Placeholder
	measurement.MemoryUsage = 0.0 // Placeholder

	return measurement
}

func analyzeStabilityResults(t *testing.T, measurements []StabilityMeasurement) {
	if len(measurements) == 0 {
		t.Error("No stability measurements collected")
		return
	}

	// Calculate stability metrics
	totalChecks := len(measurements)
	stableChecks := 0

	for _, measurement := range measurements {
		if measurement.HealthyTasks > 0 && measurement.TotalTasks > 0 {
			stableChecks++
		}
	}

	stabilityPercentage := float64(stableChecks) / float64(totalChecks) * 100

	t.Logf("Stability analysis: %d/%d checks stable (%.1f%%)",
		stableChecks, totalChecks, stabilityPercentage)

	// Assert minimum stability threshold
	assert.GreaterOrEqual(t, stabilityPercentage, 95.0,
		"Service should maintain at least 95% stability")
}
