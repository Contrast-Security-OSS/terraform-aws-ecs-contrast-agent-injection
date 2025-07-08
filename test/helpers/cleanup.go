package helpers

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_helper "github.com/gruntwork-io/terratest/modules/testing"
)

// TestCleanupManager handles cleanup of test resources
type TestCleanupManager struct {
	t                test_helper.TestingT
	awsHelper        *AWSHelper
	terraformOpts    *terraform.Options
	resourcePrefix   string
	createdResources []string
	cleanupFuncs     []func()
}

// NewTestCleanupManager creates a new test cleanup manager
func NewTestCleanupManager(t test_helper.TestingT, region string, resourcePrefix string) *TestCleanupManager {
	return &TestCleanupManager{
		t:                t,
		awsHelper:        NewAWSHelper(t, region),
		resourcePrefix:   resourcePrefix,
		createdResources: []string{},
		cleanupFuncs:     []func(){},
	}
}

// RegisterTerraformOptions registers Terraform options for cleanup
func (tcm *TestCleanupManager) RegisterTerraformOptions(opts *terraform.Options) {
	tcm.terraformOpts = opts
	tcm.AddCleanupFunc(func() {
		// Don't fail the test if destroy fails - log it and continue
		if _, err := terraform.DestroyE(tcm.t, opts); err != nil {
			fmt.Printf("Warning: Failed to destroy Terraform resources: %v\n", err)
		}
	})
}

// AddCleanupFunc adds a cleanup function to be called during cleanup
func (tcm *TestCleanupManager) AddCleanupFunc(fn func()) {
	tcm.cleanupFuncs = append(tcm.cleanupFuncs, fn)
}

// RegisterResource registers a resource for cleanup
func (tcm *TestCleanupManager) RegisterResource(resourceIdentifier string) {
	tcm.createdResources = append(tcm.createdResources, resourceIdentifier)
}

// Cleanup performs cleanup of all registered resources
func (tcm *TestCleanupManager) Cleanup() {
	// Check if we should keep resources
	if shouldKeepResources() {
		fmt.Printf("Keeping resources as requested (KEEP_RESOURCES=true)\n")
		return
	}

	fmt.Printf("Starting cleanup for test resources with prefix: %s\n", tcm.resourcePrefix)

	// Execute custom cleanup functions first
	for i := len(tcm.cleanupFuncs) - 1; i >= 0; i-- {
		func() {
			defer func() {
				if r := recover(); r != nil {
					fmt.Printf("Warning: Cleanup function panicked: %v\n", r)
				}
			}()
			tcm.cleanupFuncs[i]()
		}()
	}

	// Cleanup AWS resources by prefix
	func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("Warning: AWS cleanup panicked: %v\n", r)
			}
		}()
		tcm.awsHelper.CleanupResourcesByPrefix(tcm.t, tcm.resourcePrefix)
	}()

	// Cleanup AWS resources by tags
	func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Printf("Warning: AWS cleanup by tags panicked: %v\n", r)
			}
		}()
		tcm.awsHelper.CleanupResourcesByTags(tcm.t, map[string]string{
			"Test":   "true",
			"TestId": tcm.resourcePrefix,
		})
	}()

	fmt.Printf("Cleanup completed for test resources with prefix: %s\n", tcm.resourcePrefix)
}

// CleanupOnExit registers a cleanup function to be called when the test exits
// Note: This is a simplified version - in real tests, you would use defer in the test function
func (tcm *TestCleanupManager) CleanupOnExit() {
	// In actual usage, you would call this in the test function with defer:
	// defer tcm.Cleanup()
	// This method serves as a reminder and can be used for documentation
}

// CreateResourceName creates a resource name with the test prefix
func (tcm *TestCleanupManager) CreateResourceName(resourceType string) string {
	return fmt.Sprintf("%s-%s", tcm.resourcePrefix, resourceType)
}

// shouldKeepResources checks if resources should be kept after test completion
func shouldKeepResources() bool {
	keepResources := os.Getenv("KEEP_RESOURCES")
	return strings.ToLower(keepResources) == "true" || keepResources == "1"
}

// CleanupAllTestResources is a utility function to clean up all test resources
// This can be called directly from tests or from cleanup scripts
func CleanupAllTestResources(t test_helper.TestingT, region string) {
	awsHelper := NewAWSHelper(t, region)

	// Cleanup resources with different prefixes
	testPrefixes := []string{
		"test-",
		"unit-",
		"integration-",
		"e2e-",
	}

	for _, prefix := range testPrefixes {
		fmt.Printf("Cleaning up resources with prefix: %s\n", prefix)
		awsHelper.CleanupResourcesByPrefix(t, prefix)
	}

	// Cleanup resources by tags
	fmt.Printf("Cleaning up resources by tags\n")
	awsHelper.CleanupResourcesByTags(t, map[string]string{
		"Test": "true",
	})

	// Cleanup old resources (older than 24 hours)
	fmt.Printf("Cleaning up old resources\n")
	awsHelper.CleanupResourcesByAge(t, 24*time.Hour)
}

// ForceCleanupAllTestResources forcefully cleans up all test resources
// This is more aggressive and should be used with caution
func ForceCleanupAllTestResources(t test_helper.TestingT, region string) {
	awsHelper := NewAWSHelper(t, region)

	// Cleanup resources with different prefixes
	testPrefixes := []string{
		"test-",
		"unit-",
		"integration-",
		"e2e-",
		"performance-",
		"chaos-",
	}

	for _, prefix := range testPrefixes {
		fmt.Printf("Force cleaning up resources with prefix: %s\n", prefix)
		awsHelper.CleanupResourcesByPrefix(t, prefix)
	}

	// Cleanup resources by tags
	fmt.Printf("Force cleaning up resources by tags\n")
	awsHelper.CleanupResourcesByTags(t, map[string]string{
		"Test": "true",
	})

	// Cleanup all test resources regardless of age
	fmt.Printf("Force cleaning up all test resources\n")
	awsHelper.CleanupResourcesByAge(t, 0)
}

// ValidateCleanupComplete validates that all test resources have been cleaned up
func ValidateCleanupComplete(t test_helper.TestingT, region string, prefix string) bool {
	awsHelper := NewAWSHelper(t, region)

	// Check for remaining ECS clusters
	clustersResp, err := awsHelper.ecsClient.ListClusters(&ecs.ListClustersInput{})
	if err == nil {
		for _, clusterArn := range clustersResp.ClusterArns {
			clusterName := awsHelper.extractResourceName(aws.StringValue(clusterArn))
			if strings.HasPrefix(clusterName, prefix) {
				fmt.Printf("Warning: Found remaining ECS cluster: %s\n", clusterName)
				return false
			}
		}
	}

	// Check for remaining VPCs with Test tag
	vpcsResp, err := awsHelper.ec2Client.DescribeVpcs(&ec2.DescribeVpcsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("tag:Test"),
				Values: []*string{aws.String("true")},
			},
		},
	})
	if err == nil {
		for _, vpc := range vpcsResp.Vpcs {
			vpcId := aws.StringValue(vpc.VpcId)
			fmt.Printf("Warning: Found remaining VPC: %s\n", vpcId)
			return false
		}
	}

	// Check for remaining CloudWatch log groups
	logGroupsResp, err := awsHelper.cwlClient.DescribeLogGroups(&cloudwatchlogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String(fmt.Sprintf("/ecs/%s", prefix)),
	})
	if err == nil && len(logGroupsResp.LogGroups) > 0 {
		for _, logGroup := range logGroupsResp.LogGroups {
			fmt.Printf("Warning: Found remaining log group: %s\n", aws.StringValue(logGroup.LogGroupName))
			return false
		}
	}

	return true
}

// GetResourceInventory returns an inventory of test resources
func GetResourceInventory(t test_helper.TestingT, region string, prefix string) map[string]int {
	awsHelper := NewAWSHelper(t, region)
	inventory := make(map[string]int)

	// Count ECS clusters
	clustersResp, err := awsHelper.ecsClient.ListClusters(&ecs.ListClustersInput{})
	if err == nil {
		clusterCount := 0
		for _, clusterArn := range clustersResp.ClusterArns {
			clusterName := awsHelper.extractResourceName(aws.StringValue(clusterArn))
			if strings.HasPrefix(clusterName, prefix) {
				clusterCount++
			}
		}
		inventory["ECS Clusters"] = clusterCount
	}

	// Count VPCs with Test tag
	vpcsResp, err := awsHelper.ec2Client.DescribeVpcs(&ec2.DescribeVpcsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("tag:Test"),
				Values: []*string{aws.String("true")},
			},
		},
	})
	if err == nil {
		inventory["VPCs"] = len(vpcsResp.Vpcs)
	}

	// Count CloudWatch log groups
	logGroupsResp, err := awsHelper.cwlClient.DescribeLogGroups(&cloudwatchlogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String(fmt.Sprintf("/ecs/%s", prefix)),
	})
	if err == nil {
		inventory["CloudWatch Log Groups"] = len(logGroupsResp.LogGroups)
	}

	return inventory
}
