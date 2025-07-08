package helpers

import (
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/testing"
	"github.com/stretchr/testify/require"
)

// AWSHelper provides utilities for AWS operations in tests
type AWSHelper struct {
	sess      *session.Session
	ec2Client *ec2.EC2
	ecsClient *ecs.ECS
	cwlClient *cloudwatchlogs.CloudWatchLogs
	region    string
}

// NewAWSHelper creates a new AWS helper instance
func NewAWSHelper(t testing.TestingT, region string) *AWSHelper {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err)

	return &AWSHelper{
		sess:      sess,
		ec2Client: ec2.New(sess),
		ecsClient: ecs.New(sess),
		cwlClient: cloudwatchlogs.New(sess),
		region:    region,
	}
}

// GetRandomResourceName generates a random resource name with test prefix
func (h *AWSHelper) GetRandomResourceName(prefix string) string {
	return fmt.Sprintf("test-%s-%s", prefix, strings.ToLower(random.UniqueId()))
}

// WaitForECSServiceStable waits for an ECS service to reach a stable state
func (h *AWSHelper) WaitForECSServiceStable(t testing.TestingT, clusterName, serviceName string, timeout time.Duration) {
	// Simple polling approach for AWS SDK v1
	start := time.Now()
	for time.Since(start) < timeout {
		resp, err := h.ecsClient.DescribeServices(&ecs.DescribeServicesInput{
			Cluster:  aws.String(clusterName),
			Services: []*string{aws.String(serviceName)},
		})
		require.NoError(t, err)

		if len(resp.Services) > 0 {
			service := resp.Services[0]
			if *service.DesiredCount == *service.RunningCount {
				return // Service is stable
			}
		}
		time.Sleep(10 * time.Second)
	}
	require.Fail(t, "ECS service did not reach stable state within timeout")
}

// GetECSTaskDefinition retrieves an ECS task definition
func (h *AWSHelper) GetECSTaskDefinition(t testing.TestingT, taskDefArn string) *ecs.TaskDefinition {
	resp, err := h.ecsClient.DescribeTaskDefinition(&ecs.DescribeTaskDefinitionInput{
		TaskDefinition: aws.String(taskDefArn),
	})
	require.NoError(t, err)

	return resp.TaskDefinition
}

// GetECSServiceTasks retrieves all tasks for an ECS service
func (h *AWSHelper) GetECSServiceTasks(t testing.TestingT, clusterName, serviceName string) []*ecs.Task {
	// First get the service
	svcResp, err := h.ecsClient.DescribeServices(&ecs.DescribeServicesInput{
		Cluster:  aws.String(clusterName),
		Services: []*string{aws.String(serviceName)},
	})
	require.NoError(t, err)
	require.Len(t, svcResp.Services, 1)

	// Then list tasks
	listResp, err := h.ecsClient.ListTasks(&ecs.ListTasksInput{
		Cluster:     aws.String(clusterName),
		ServiceName: aws.String(serviceName),
	})
	require.NoError(t, err)

	if len(listResp.TaskArns) == 0 {
		return []*ecs.Task{}
	}

	// Describe tasks
	taskResp, err := h.ecsClient.DescribeTasks(&ecs.DescribeTasksInput{
		Cluster: aws.String(clusterName),
		Tasks:   listResp.TaskArns,
	})
	require.NoError(t, err)

	return taskResp.Tasks
}

// GetCloudWatchLogs retrieves logs from a CloudWatch log group
func (h *AWSHelper) GetCloudWatchLogs(t testing.TestingT, logGroupName string, since time.Time) []*cloudwatchlogs.OutputLogEvent {
	// Get log streams
	streamsResp, err := h.cwlClient.DescribeLogStreams(&cloudwatchlogs.DescribeLogStreamsInput{
		LogGroupName: aws.String(logGroupName),
		OrderBy:      aws.String("LastEventTime"),
		Descending:   aws.Bool(true),
		Limit:        aws.Int64(10),
	})
	require.NoError(t, err)

	var allEvents []*cloudwatchlogs.OutputLogEvent

	for _, stream := range streamsResp.LogStreams {
		eventsResp, err := h.cwlClient.GetLogEvents(&cloudwatchlogs.GetLogEventsInput{
			LogGroupName:  aws.String(logGroupName),
			LogStreamName: stream.LogStreamName,
			StartTime:     aws.Int64(since.UnixMilli()),
		})
		require.NoError(t, err)

		allEvents = append(allEvents, eventsResp.Events...)
	}

	return allEvents
}

// CheckContrastAgentInLogs checks if Contrast agent initialization messages appear in logs
func (h *AWSHelper) CheckContrastAgentInLogs(t testing.TestingT, logGroupName string, since time.Time) bool {
	events := h.GetCloudWatchLogs(t, logGroupName, since)

	contrastKeywords := []string{
		"Contrast agent copied successfully",
		"Contrast Security Agent",
		"contrast-agent.jar",
		"CONTRAST_ENABLED=true",
	}

	for _, event := range events {
		message := aws.StringValue(event.Message)
		for _, keyword := range contrastKeywords {
			if strings.Contains(message, keyword) {
				return true
			}
		}
	}

	return false
}

// GetVPCDefaultSecurityGroup retrieves the default security group for a VPC
func (h *AWSHelper) GetVPCDefaultSecurityGroup(t testing.TestingT, vpcId string) string {
	resp, err := h.ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []*string{aws.String(vpcId)},
			},
			{
				Name:   aws.String("group-name"),
				Values: []*string{aws.String("default")},
			},
		},
	})
	require.NoError(t, err)
	require.Len(t, resp.SecurityGroups, 1)

	return aws.StringValue(resp.SecurityGroups[0].GroupId)
}

// CleanupResourcesByPrefix removes all resources with a specific prefix
func (h *AWSHelper) CleanupResourcesByPrefix(t testing.TestingT, prefix string) {
	// Cleanup ECS services
	h.cleanupECSServices(t, prefix)

	// Cleanup ECS clusters
	h.cleanupECSClusters(t, prefix)

	// Cleanup CloudWatch log groups
	h.cleanupCloudWatchLogs(t, prefix)
}

// CleanupResourcesByTags removes all resources with specific tags
func (h *AWSHelper) CleanupResourcesByTags(t testing.TestingT, tags map[string]string) {
	// Cleanup VPCs and related resources
	h.cleanupVPCsByTags(t, tags)

	// Cleanup ECS resources
	h.cleanupECSResourcesByTags(t, tags)

	// Cleanup CloudWatch log groups
	h.cleanupCloudWatchLogsByTags(t, tags)
}

// CleanupResourcesByAge removes resources older than the specified duration
func (h *AWSHelper) CleanupResourcesByAge(t testing.TestingT, maxAge time.Duration) {
	cutoffTime := time.Now().Add(-maxAge)

	// Cleanup old ECS resources
	h.cleanupOldECSResources(t, cutoffTime)

	// Cleanup old VPCs
	h.cleanupOldVPCs(t, cutoffTime)

	// Cleanup old CloudWatch logs
	h.cleanupOldCloudWatchLogs(t, cutoffTime)
}

// cleanupVPCsByTags removes VPCs and related resources with specific tags
func (h *AWSHelper) cleanupVPCsByTags(t testing.TestingT, tags map[string]string) {
	// Build filters for VPC search
	var filters []*ec2.Filter
	for key, value := range tags {
		filters = append(filters, &ec2.Filter{
			Name:   aws.String(fmt.Sprintf("tag:%s", key)),
			Values: []*string{aws.String(value)},
		})
	}

	// Find VPCs with matching tags
	resp, err := h.ec2Client.DescribeVpcs(&ec2.DescribeVpcsInput{
		Filters: filters,
	})
	require.NoError(t, err)

	for _, vpc := range resp.Vpcs {
		vpcId := aws.StringValue(vpc.VpcId)
		h.cleanupVPCResources(t, vpcId)

		// Delete VPC
		_, err := h.ec2Client.DeleteVpc(&ec2.DeleteVpcInput{
			VpcId: aws.String(vpcId),
		})
		if err != nil {
			// Log error but don't fail the test
			fmt.Printf("Warning: Failed to delete VPC %s: %v\n", vpcId, err)
		}
	}
}

// cleanupVPCResources removes all resources within a VPC
func (h *AWSHelper) cleanupVPCResources(t testing.TestingT, vpcId string) {
	// Delete NAT Gateways
	natResp, err := h.ec2Client.DescribeNatGateways(&ec2.DescribeNatGatewaysInput{
		Filter: []*ec2.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []*string{aws.String(vpcId)},
			},
			{
				Name:   aws.String("state"),
				Values: []*string{aws.String("available")},
			},
		},
	})
	if err == nil {
		for _, natGw := range natResp.NatGateways {
			h.ec2Client.DeleteNatGateway(&ec2.DeleteNatGatewayInput{
				NatGatewayId: natGw.NatGatewayId,
			})
		}
	}

	// Delete Internet Gateways
	igwResp, err := h.ec2Client.DescribeInternetGateways(&ec2.DescribeInternetGatewaysInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("attachment.vpc-id"),
				Values: []*string{aws.String(vpcId)},
			},
		},
	})
	if err == nil {
		for _, igw := range igwResp.InternetGateways {
			// Detach first
			h.ec2Client.DetachInternetGateway(&ec2.DetachInternetGatewayInput{
				InternetGatewayId: igw.InternetGatewayId,
				VpcId:             aws.String(vpcId),
			})
			// Then delete
			h.ec2Client.DeleteInternetGateway(&ec2.DeleteInternetGatewayInput{
				InternetGatewayId: igw.InternetGatewayId,
			})
		}
	}

	// Delete Route Tables (except main)
	rtResp, err := h.ec2Client.DescribeRouteTables(&ec2.DescribeRouteTablesInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []*string{aws.String(vpcId)},
			},
		},
	})
	if err == nil {
		for _, rt := range rtResp.RouteTables {
			// Skip main route table
			isMain := false
			for _, assoc := range rt.Associations {
				if aws.BoolValue(assoc.Main) {
					isMain = true
					break
				}
			}
			if !isMain {
				h.ec2Client.DeleteRouteTable(&ec2.DeleteRouteTableInput{
					RouteTableId: rt.RouteTableId,
				})
			}
		}
	}

	// Delete Security Groups (except default)
	sgResp, err := h.ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []*string{aws.String(vpcId)},
			},
		},
	})
	if err == nil {
		for _, sg := range sgResp.SecurityGroups {
			if aws.StringValue(sg.GroupName) != "default" {
				h.ec2Client.DeleteSecurityGroup(&ec2.DeleteSecurityGroupInput{
					GroupId: sg.GroupId,
				})
			}
		}
	}

	// Delete Subnets
	subnetResp, err := h.ec2Client.DescribeSubnets(&ec2.DescribeSubnetsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []*string{aws.String(vpcId)},
			},
		},
	})
	if err == nil {
		for _, subnet := range subnetResp.Subnets {
			h.ec2Client.DeleteSubnet(&ec2.DeleteSubnetInput{
				SubnetId: subnet.SubnetId,
			})
		}
	}
}

// cleanupECSResourcesByTags removes ECS resources with specific tags
func (h *AWSHelper) cleanupECSResourcesByTags(t testing.TestingT, tags map[string]string) {
	// List all clusters
	clustersResp, err := h.ecsClient.ListClusters(&ecs.ListClustersInput{})
	if err != nil {
		return
	}

	for _, clusterArn := range clustersResp.ClusterArns {
		clusterName := h.extractResourceName(aws.StringValue(clusterArn))

		// Check if cluster has matching tags
		tagsResp, err := h.ecsClient.ListTagsForResource(&ecs.ListTagsForResourceInput{
			ResourceArn: clusterArn,
		})
		if err != nil {
			continue
		}

		hasMatchingTags := true
		for key, value := range tags {
			found := false
			for _, tag := range tagsResp.Tags {
				if aws.StringValue(tag.Key) == key && aws.StringValue(tag.Value) == value {
					found = true
					break
				}
			}
			if !found {
				hasMatchingTags = false
				break
			}
		}

		if hasMatchingTags {
			h.cleanupECSClusterResources(t, clusterName)
		}
	}
}

// cleanupECSClusterResources removes all resources within an ECS cluster
func (h *AWSHelper) cleanupECSClusterResources(t testing.TestingT, clusterName string) {
	// Scale down and delete services
	servicesResp, err := h.ecsClient.ListServices(&ecs.ListServicesInput{
		Cluster: aws.String(clusterName),
	})
	if err == nil {
		for _, serviceArn := range servicesResp.ServiceArns {
			serviceName := h.extractResourceName(aws.StringValue(serviceArn))

			// Scale down to 0
			h.ecsClient.UpdateService(&ecs.UpdateServiceInput{
				Cluster:      aws.String(clusterName),
				Service:      aws.String(serviceName),
				DesiredCount: aws.Int64(0),
			})

			// Wait for service to be stable (with timeout)
			h.waitForECSServiceStableWithTimeout(t, clusterName, serviceName, 5*time.Minute)

			// Delete service
			h.ecsClient.DeleteService(&ecs.DeleteServiceInput{
				Cluster: aws.String(clusterName),
				Service: aws.String(serviceName),
			})
		}
	}

	// Delete cluster
	h.ecsClient.DeleteCluster(&ecs.DeleteClusterInput{
		Cluster: aws.String(clusterName),
	})
}

// cleanupOldECSResources removes ECS resources older than the specified time
func (h *AWSHelper) cleanupOldECSResources(t testing.TestingT, cutoffTime time.Time) {
	// This would need to be implemented based on resource creation times
	// For now, we'll use the existing prefix-based cleanup
	h.cleanupECSServices(t, "test-")
	h.cleanupECSClusters(t, "test-")
}

// cleanupOldVPCs removes VPCs older than the specified time
func (h *AWSHelper) cleanupOldVPCs(t testing.TestingT, cutoffTime time.Time) {
	// This would need to be implemented based on VPC creation times
	// For now, we'll use tag-based cleanup
	h.cleanupVPCsByTags(t, map[string]string{"Test": "true"})
}

// cleanupOldCloudWatchLogs removes CloudWatch log groups older than the specified time
func (h *AWSHelper) cleanupOldCloudWatchLogs(t testing.TestingT, cutoffTime time.Time) {
	resp, err := h.cwlClient.DescribeLogGroups(&cloudwatchlogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String("/ecs/test-"),
	})
	if err != nil {
		return
	}

	for _, logGroup := range resp.LogGroups {
		creationTime := time.Unix(aws.Int64Value(logGroup.CreationTime)/1000, 0)
		if creationTime.Before(cutoffTime) {
			h.cwlClient.DeleteLogGroup(&cloudwatchlogs.DeleteLogGroupInput{
				LogGroupName: logGroup.LogGroupName,
			})
		}
	}
}

// cleanupCloudWatchLogsByTags removes CloudWatch log groups with specific tags
func (h *AWSHelper) cleanupCloudWatchLogsByTags(t testing.TestingT, tags map[string]string) {
	// CloudWatch Logs doesn't support tag-based filtering in the same way
	// We'll use prefix-based cleanup for now
	h.cleanupCloudWatchLogs(t, "test-")
}

// waitForECSServiceStableWithTimeout waits for an ECS service to reach a stable state with timeout
func (h *AWSHelper) waitForECSServiceStableWithTimeout(t testing.TestingT, clusterName, serviceName string, timeout time.Duration) {
	start := time.Now()
	for time.Since(start) < timeout {
		resp, err := h.ecsClient.DescribeServices(&ecs.DescribeServicesInput{
			Cluster:  aws.String(clusterName),
			Services: []*string{aws.String(serviceName)},
		})
		if err != nil {
			return // Service might be deleted
		}

		if len(resp.Services) > 0 {
			service := resp.Services[0]
			if aws.Int64Value(service.DesiredCount) == aws.Int64Value(service.RunningCount) {
				return // Service is stable
			}
		}
		time.Sleep(10 * time.Second)
	}
	// Don't fail the test if service doesn't become stable - it might be getting deleted
}

// cleanupECSServices removes ECS services with a specific prefix
func (h *AWSHelper) cleanupECSServices(t testing.TestingT, prefix string) {
	clustersResp, err := h.ecsClient.ListClusters(&ecs.ListClustersInput{})
	require.NoError(t, err)

	for _, clusterArn := range clustersResp.ClusterArns {
		clusterName := h.extractResourceName(aws.StringValue(clusterArn))

		if strings.HasPrefix(clusterName, prefix) {
			servicesResp, err := h.ecsClient.ListServices(&ecs.ListServicesInput{
				Cluster: aws.String(clusterName),
			})
			require.NoError(t, err)

			for _, serviceArn := range servicesResp.ServiceArns {
				serviceName := h.extractResourceName(aws.StringValue(serviceArn))

				// Scale down to 0
				_, err = h.ecsClient.UpdateService(&ecs.UpdateServiceInput{
					Cluster:      aws.String(clusterName),
					Service:      aws.String(serviceName),
					DesiredCount: aws.Int64(0),
				})
				require.NoError(t, err)

				// Wait for service to be stable
				h.WaitForECSServiceStable(t, clusterName, serviceName, 5*time.Minute)

				// Delete service
				h.ecsClient.DeleteService(&ecs.DeleteServiceInput{
					Cluster: aws.String(clusterName),
					Service: aws.String(serviceName),
				})
			}
		}
	}
}

// cleanupECSClusters removes ECS clusters with a specific prefix
func (h *AWSHelper) cleanupECSClusters(t testing.TestingT, prefix string) {
	clustersResp, err := h.ecsClient.ListClusters(&ecs.ListClustersInput{})
	require.NoError(t, err)

	for _, clusterArn := range clustersResp.ClusterArns {
		clusterName := h.extractResourceName(aws.StringValue(clusterArn))

		if strings.HasPrefix(clusterName, prefix) {
			// Delete cluster
			h.ecsClient.DeleteCluster(&ecs.DeleteClusterInput{
				Cluster: aws.String(clusterName),
			})
		}
	}
}

// cleanupCloudWatchLogs removes CloudWatch log groups with a specific prefix
func (h *AWSHelper) cleanupCloudWatchLogs(t testing.TestingT, prefix string) {
	resp, err := h.cwlClient.DescribeLogGroups(&cloudwatchlogs.DescribeLogGroupsInput{
		LogGroupNamePrefix: aws.String(fmt.Sprintf("/ecs/%s", prefix)),
	})
	require.NoError(t, err)

	for _, logGroup := range resp.LogGroups {
		// Delete log group
		h.cwlClient.DeleteLogGroup(&cloudwatchlogs.DeleteLogGroupInput{
			LogGroupName: logGroup.LogGroupName,
		})
	}
}

// extractResourceName extracts the resource name from an ARN
func (h *AWSHelper) extractResourceName(arn string) string {
	parts := strings.Split(arn, "/")
	if len(parts) > 1 {
		return parts[len(parts)-1]
	}
	return arn
}

// ValidateContrastSidecarConfiguration validates the contrast sidecar configuration
func (h *AWSHelper) ValidateContrastSidecarConfiguration(t testing.TestingT, taskDefArn string, expectedConfig map[string]string) {
	taskDef := h.GetECSTaskDefinition(t, taskDefArn)

	// Find the contrast sidecar container
	var contrastContainer *ecs.ContainerDefinition
	for _, container := range taskDef.ContainerDefinitions {
		if strings.Contains(aws.StringValue(container.Name), "contrast") {
			contrastContainer = container
			break
		}
	}

	require.NotNil(t, contrastContainer, "Contrast sidecar container not found")

	// Validate environment variables
	envVars := make(map[string]string)
	for _, env := range contrastContainer.Environment {
		envVars[aws.StringValue(env.Name)] = aws.StringValue(env.Value)
	}

	for key, expectedValue := range expectedConfig {
		actualValue, exists := envVars[key]
		require.True(t, exists, "Environment variable %s not found", key)
		require.Equal(t, expectedValue, actualValue, "Environment variable %s has wrong value", key)
	}
}

// ValidateContrastAgentSidecarPresence validates that the contrast agent sidecar is present
func (h *AWSHelper) ValidateContrastAgentSidecarPresence(t testing.TestingT, taskDefArn string, shouldBePresent bool) {
	taskDef := h.GetECSTaskDefinition(t, taskDefArn)

	contrastSidecarFound := false
	for _, container := range taskDef.ContainerDefinitions {
		if strings.Contains(aws.StringValue(container.Name), "contrast") {
			contrastSidecarFound = true
			break
		}
	}

	if shouldBePresent {
		require.True(t, contrastSidecarFound, "Contrast sidecar container should be present but was not found")
	} else {
		require.False(t, contrastSidecarFound, "Contrast sidecar container should not be present but was found")
	}
}

// CheckServiceHealth checks if an ECS service is healthy
func (h *AWSHelper) CheckServiceHealth(t testing.TestingT, clusterName, serviceName string) bool {
	resp, err := h.ecsClient.DescribeServices(&ecs.DescribeServicesInput{
		Cluster:  aws.String(clusterName),
		Services: []*string{aws.String(serviceName)},
	})
	require.NoError(t, err)

	if len(resp.Services) == 0 {
		return false
	}

	service := resp.Services[0]
	return *service.RunningCount == *service.DesiredCount &&
		*service.DesiredCount > 0
}
