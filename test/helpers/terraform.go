package helpers

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/testing"
)

// TerraformHelper provides utilities for Terraform operations in tests
type TerraformHelper struct {
	options *terraform.Options
	t       testing.TestingT
}

// NewTerraformHelper creates a new Terraform helper instance
func NewTerraformHelper(t testing.TestingT, terraformDir string, vars map[string]interface{}) *TerraformHelper {
	options := &terraform.Options{
		TerraformDir: terraformDir,
		Vars:         vars,
		NoColor:      true,
		Logger:       logger.Default,
		RetryableTerraformErrors: map[string]string{
			".*": "Retryable error",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	return &TerraformHelper{
		options: options,
		t:       t,
	}
}

// InitAndApply initializes and applies Terraform configuration
func (h *TerraformHelper) InitAndApply() {
	terraform.InitAndApply(h.t, h.options)
}

// Plan runs terraform plan
func (h *TerraformHelper) Plan() string {
	return terraform.Plan(h.t, h.options)
}

// Apply runs terraform apply
func (h *TerraformHelper) Apply() {
	terraform.Apply(h.t, h.options)
}

// Destroy runs terraform destroy
func (h *TerraformHelper) Destroy() {
	terraform.Destroy(h.t, h.options)
}

// GetOutput retrieves a Terraform output value
func (h *TerraformHelper) GetOutput(key string) string {
	return terraform.Output(h.t, h.options, key)
}

// GetAllOutputs retrieves all Terraform output values
func (h *TerraformHelper) GetAllOutputs() map[string]interface{} {
	return terraform.OutputAll(h.t, h.options)
}

// ValidateOutputs validates that expected outputs exist and have expected types
func (h *TerraformHelper) ValidateOutputs(expectedOutputs map[string]string) {
	outputs := h.GetAllOutputs()

	for key, expectedType := range expectedOutputs {
		value, exists := outputs[key]
		if !exists {
			h.t.Fatalf("Expected output %s not found", key)
		}

		actualType := fmt.Sprintf("%T", value)
		if !strings.Contains(actualType, expectedType) {
			h.t.Fatalf("Output %s has type %s, expected %s", key, actualType, expectedType)
		}
	}
}

// SetVariable sets a variable value
func (h *TerraformHelper) SetVariable(key string, value interface{}) {
	h.options.Vars[key] = value
}

// SetVariables sets multiple variable values
func (h *TerraformHelper) SetVariables(vars map[string]interface{}) {
	for key, value := range vars {
		h.options.Vars[key] = value
	}
}

// GetVariables returns all current variable values
func (h *TerraformHelper) GetVariables() map[string]interface{} {
	return h.options.Vars
}

// WithWorkspace sets the Terraform workspace
func (h *TerraformHelper) WithWorkspace(workspace string) *TerraformHelper {
	h.options.TerraformBinary = fmt.Sprintf("terraform workspace select %s && terraform", workspace)
	return h
}

// WithBackend configures Terraform backend
func (h *TerraformHelper) WithBackend(backendConfig map[string]interface{}) *TerraformHelper {
	h.options.BackendConfig = backendConfig
	return h
}

// WithEnvVars sets environment variables for Terraform execution
func (h *TerraformHelper) WithEnvVars(envVars map[string]string) *TerraformHelper {
	h.options.EnvVars = envVars
	return h
}

// ValidateNoChanges verifies that terraform plan shows no changes
func (h *TerraformHelper) ValidateNoChanges() {
	planOutput := h.Plan()
	if strings.Contains(planOutput, "Plan:") &&
		!strings.Contains(planOutput, "No changes") {
		h.t.Fatalf("Terraform plan shows changes when none were expected:\n%s", planOutput)
	}
}

// CreateFixtureOptions creates Terraform options for test fixtures
func CreateFixtureOptions(t testing.TestingT, fixtureName string, uniqueId string) *terraform.Options {
	fixtureDir := filepath.Join("fixtures", fixtureName)

	return &terraform.Options{
		TerraformDir: fixtureDir,
		Vars: map[string]interface{}{
			"unique_id": uniqueId,
		},
		NoColor: true,
		Logger:  logger.Default,
		RetryableTerraformErrors: map[string]string{
			"RequestError: send request failed": "Retryable AWS error",
			"Error creating.*":                  "Retryable creation error",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}
}

// DestroyWithRetry attempts to destroy resources with retry logic
func DestroyWithRetry(t testing.TestingT, options *terraform.Options, maxRetries int) {
	for i := 0; i < maxRetries; i++ {
		_, err := terraform.DestroyE(t, options)
		if err == nil {
			return
		}

		if i < maxRetries-1 {
			logger.Default.Logf(t, "Destroy attempt %d failed, retrying...", i+1)
			time.Sleep(time.Duration(i+1) * 30 * time.Second)
		} else {
			t.Fatalf("Failed to destroy after %d attempts: %v", maxRetries, err)
		}
	}
}
