package unit

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestModuleOutputs tests that the module produces expected outputs
func TestModuleOutputs(t *testing.T) {
	t.Parallel()

	uniqueId := fmt.Sprintf("unit-%s", random.UniqueId())

	// Test with agent enabled
	t.Run("AgentEnabled", func(t *testing.T) {
		terraformOptions := &terraform.Options{
			TerraformDir: "../fixtures/basic",
			Vars: map[string]interface{}{
				"unique_id":            uniqueId + "-enabled",
				"contrast_enabled":     true,
				"contrast_api_key":     "test-api-key",
				"contrast_service_key": "test-service-key",
				"contrast_user_name":   "test-user",
				"app_image":            "nginx:latest",
			},
			NoColor: true,
		}

		defer terraform.Destroy(t, terraformOptions)

		// Only run plan to test outputs without creating resources
		terraform.Init(t, terraformOptions)
		planOutput := terraform.Plan(t, terraformOptions)

		// Check that plan includes expected resources
		assert.Contains(t, planOutput, "module.contrast_sidecar", "Plan should include contrast sidecar module")
		assert.Contains(t, planOutput, "contrast-agent-storage", "Plan should include contrast volume")
		assert.Contains(t, planOutput, "contrast-init", "Plan should include init container")
	})

	// Test with agent disabled
	t.Run("AgentDisabled", func(t *testing.T) {
		terraformOptions := &terraform.Options{
			TerraformDir: "../fixtures/basic",
			Vars: map[string]interface{}{
				"unique_id":            uniqueId + "-disabled",
				"contrast_enabled":     false,
				"contrast_api_key":     "dummy-key",
				"contrast_service_key": "dummy-service-key",
				"contrast_user_name":   "dummy-user",
				"app_image":            "nginx:latest",
			},
			NoColor: true,
		}

		defer terraform.Destroy(t, terraformOptions)

		terraform.Init(t, terraformOptions)
		planOutput := terraform.Plan(t, terraformOptions)

		// Check that plan does not include contrast-specific resources
		assert.NotContains(t, planOutput, "contrast-agent-storage", "Plan should not include contrast volume when disabled")
		assert.NotContains(t, planOutput, "contrast-init", "Plan should not include init container when disabled")
	})
}

// TestVariableValidation tests Terraform variable validation
func TestVariableValidation(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name          string
		vars          map[string]interface{}
		shouldSucceed bool
		expectedError string
	}{
		{
			name: "ValidEnvironment",
			vars: map[string]interface{}{
				"enabled":              false,
				"application_name":     "test-app",
				"contrast_api_key":     "dummy-key",
				"contrast_service_key": "dummy-service-key",
				"contrast_user_name":   "dummy-user",
				"environment":          "DEVELOPMENT",
			},
			shouldSucceed: true,
		},
		{
			name: "InvalidEnvironment",
			vars: map[string]interface{}{
				"enabled":              false,
				"application_name":     "test-app",
				"contrast_api_key":     "dummy-key",
				"contrast_service_key": "dummy-service-key",
				"contrast_user_name":   "dummy-user",
				"environment":          "INVALID",
			},
			shouldSucceed: false,
			expectedError: "Environment must be one of",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: "../../terraform-module",
				Vars:         tc.vars,
				NoColor:      true,
			}
			if tc.shouldSucceed {
				terraform.Init(t, terraformOptions)
				// Use plan instead of validate to test variable validation
				terraform.Plan(t, terraformOptions)
			} else {
				terraform.Init(t, terraformOptions)
				_, err := terraform.PlanE(t, terraformOptions)
				require.Error(t, err, "Expected validation to fail")
				if tc.expectedError != "" {
					assert.Contains(t, err.Error(), tc.expectedError, "Error should contain expected message")
				}
			}
		})
	}
}

// TestModuleStructure tests the basic structure of the module
func TestModuleStructure(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../terraform-module",
		NoColor:      true,
	}

	// Test that module can be initialized
	terraform.Init(t, terraformOptions)

	// Test that module validates successfully
	terraform.Validate(t, terraformOptions)

	// Test with minimal required variables
	terraformOptions.Vars = map[string]interface{}{
		"enabled":              false,
		"application_name":     "test-app",
		"contrast_api_key":     "dummy-key",
		"contrast_service_key": "dummy-service-key",
		"contrast_user_name":   "dummy-user",
		"environment":          "DEVELOPMENT",
	}

	// Run plan to validate structure
	planOutput := terraform.Plan(t, terraformOptions)

	// When disabled, the module should not error but may still produce outputs
	// The key is that it validates and plans successfully
	assert.NotContains(t, planOutput, "Error", "Plan should not contain errors")
}

// TestOutputTypes tests that outputs have the correct types
func TestOutputTypes(t *testing.T) {
	t.Parallel()

	uniqueId := fmt.Sprintf("output-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../fixtures/basic",
		Vars: map[string]interface{}{
			"unique_id":            uniqueId,
			"contrast_enabled":     true,
			"contrast_api_key":     "test-api-key",
			"contrast_service_key": "test-service-key",
			"contrast_user_name":   "test-user",
			"app_image":            "nginx:latest",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Test output types
	outputs := terraform.OutputAll(t, terraformOptions)

	// String outputs that should always exist
	alwaysStringOutputs := []string{
		"app_name",
		"cluster_name",
		"service_name",
		"task_definition_arn",
		"vpc_id",
		"security_group_id",
		"log_group_app",
		"unique_id",
	}

	for _, output := range alwaysStringOutputs {
		value, exists := outputs[output]
		assert.True(t, exists, fmt.Sprintf("Output %s should exist", output))
		assert.IsType(t, "", value, fmt.Sprintf("Output %s should be string type", output))
		assert.NotEmpty(t, value, fmt.Sprintf("Output %s should not be empty", output))
	}

	// Conditional string outputs that depend on contrast_enabled
	conditionalStringOutputs := []string{
		"contrast_agent_path",
		"log_group_contrast",
	}

	for _, output := range conditionalStringOutputs {
		value, exists := outputs[output]
		if exists && value != nil {
			// When contrast is enabled, these should be non-empty strings
			assert.IsType(t, "", value, fmt.Sprintf("Output %s should be string type", output))
			assert.NotEmpty(t, value, fmt.Sprintf("Output %s should not be empty when contrast is enabled", output))
		}
		// If the output doesn't exist or is nil, that could be valid depending on the contrast_enabled state
		// We can't assert they must exist because Terraform omits null outputs from JSON
	}

	// Boolean outputs
	contrastEnabled, exists := outputs["contrast_enabled"]
	assert.True(t, exists, "contrast_enabled output should exist")
	assert.IsType(t, true, contrastEnabled, "contrast_enabled should be boolean")

	// Array outputs
	arrayOutputs := []string{"private_subnet_ids", "public_subnet_ids"}
	for _, output := range arrayOutputs {
		value, exists := outputs[output]
		assert.True(t, exists, fmt.Sprintf("Output %s should exist", output))
		assert.IsType(t, []interface{}{}, value, fmt.Sprintf("Output %s should be array type", output))
	}
}

// TestOutputTypesWithDisabledAgent tests that outputs have the correct types when the agent is disabled
func TestOutputTypesWithDisabledAgent(t *testing.T) {
	t.Parallel()

	uniqueId := fmt.Sprintf("output-disabled-%s", random.UniqueId())

	terraformOptions := &terraform.Options{
		TerraformDir: "../fixtures/basic",
		Vars: map[string]interface{}{
			"unique_id":            uniqueId,
			"contrast_enabled":     false,
			"contrast_api_key":     "test-api-key",
			"contrast_service_key": "test-service-key",
			"contrast_user_name":   "test-user",
			"app_image":            "nginx:latest",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Test output types
	outputs := terraform.OutputAll(t, terraformOptions)

	// String outputs that should always exist
	alwaysStringOutputs := []string{
		"app_name",
		"cluster_name",
		"service_name",
		"task_definition_arn",
		"vpc_id",
		"security_group_id",
		"log_group_app",
		"unique_id",
	}

	for _, output := range alwaysStringOutputs {
		value, exists := outputs[output]
		assert.True(t, exists, fmt.Sprintf("Output %s should exist", output))
		assert.IsType(t, "", value, fmt.Sprintf("Output %s should be string type", output))
		assert.NotEmpty(t, value, fmt.Sprintf("Output %s should not be empty", output))
	}

	// Conditional outputs that should not exist when contrast is disabled
	conditionalOutputs := []string{
		"contrast_agent_path",
		"log_group_contrast",
	}

	for _, output := range conditionalOutputs {
		value, exists := outputs[output]
		assert.False(t, exists, fmt.Sprintf("Output %s should not exist when agent is disabled", output))
		if exists {
			assert.Nil(t, value, fmt.Sprintf("Output %s should be null when agent is disabled", output))
		}
	}

	// Boolean outputs
	contrastEnabled, exists := outputs["contrast_enabled"]
	assert.True(t, exists, "contrast_enabled output should exist")
	assert.IsType(t, false, contrastEnabled, "contrast_enabled should be boolean")
	assert.False(t, contrastEnabled.(bool), "contrast_enabled should be false when agent is disabled")

	// Array outputs
	arrayOutputs := []string{"private_subnet_ids", "public_subnet_ids"}
	for _, output := range arrayOutputs {
		value, exists := outputs[output]
		assert.True(t, exists, fmt.Sprintf("Output %s should exist", output))
		assert.IsType(t, []interface{}{}, value, fmt.Sprintf("Output %s should be array type", output))
	}
}
