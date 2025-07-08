package helpers

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"
	"time"

	"github.com/gruntwork-io/terratest/modules/testing"
	"github.com/stretchr/testify/require"
)

// ContrastHelper provides utilities for Contrast Security API operations
type ContrastHelper struct {
	apiURL     string
	apiKey     string
	serviceKey string
	userName   string
	httpClient *http.Client
}

// NewContrastHelper creates a new Contrast helper instance
func NewContrastHelper(apiURL, apiKey, serviceKey, userName string) *ContrastHelper {
	return &ContrastHelper{
		apiURL:     apiURL,
		apiKey:     apiKey,
		serviceKey: serviceKey,
		userName:   userName,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// Application represents a Contrast application
type Application struct {
	AppID   string `json:"app_id"`
	Name    string `json:"name"`
	Status  string `json:"status"`
	Created int64  `json:"created"`
}

// Server represents a Contrast server
type Server struct {
	ServerID    string `json:"server_id"`
	Name        string `json:"name"`
	Environment string `json:"environment"`
	Status      string `json:"status"`
	LastSeen    int64  `json:"last_seen"`
}

// Agent represents a Contrast agent
type Agent struct {
	AgentID  string `json:"agent_id"`
	Version  string `json:"version"`
	Language string `json:"language"`
	Status   string `json:"status"`
	LastSeen int64  `json:"last_seen"`
}

// ValidateConnectivity tests connectivity to Contrast API
func (h *ContrastHelper) ValidateConnectivity(t testing.TestingT) {
	req, err := http.NewRequest("GET", h.apiURL+"/api/ng/profile", nil)
	require.NoError(t, err)

	h.setAuthHeaders(req)

	resp, err := h.httpClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode, "Failed to connect to Contrast API")
}

// WaitForApplication waits for an application to appear in Contrast
func (h *ContrastHelper) WaitForApplication(t testing.TestingT, appName string, timeout time.Duration) *Application {
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		app, err := h.GetApplication(appName)
		if err == nil && app != nil {
			return app
		}

		time.Sleep(10 * time.Second)
	}

	require.Fail(t, fmt.Sprintf("Application %s did not appear in Contrast within %v", appName, timeout))
	return nil
}

// WaitForServer waits for a server to appear in Contrast
func (h *ContrastHelper) WaitForServer(t testing.TestingT, serverName string, timeout time.Duration) *Server {
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		server, err := h.GetServer(serverName)
		if err == nil && server != nil {
			return server
		}

		time.Sleep(10 * time.Second)
	}

	require.Fail(t, fmt.Sprintf("Server %s did not appear in Contrast within %v", serverName, timeout))
	return nil
}

// WaitForAgent waits for an agent to appear and be active
func (h *ContrastHelper) WaitForAgent(t testing.TestingT, appName string, timeout time.Duration) *Agent {
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		agent, err := h.GetAgent(appName)
		if err == nil && agent != nil && agent.Status == "active" {
			return agent
		}

		time.Sleep(15 * time.Second)
	}

	require.Fail(t, fmt.Sprintf("Agent for app %s did not become active within %v", appName, timeout))
	return nil
}

// GetApplication retrieves an application by name
func (h *ContrastHelper) GetApplication(appName string) (*Application, error) {
	req, err := http.NewRequest("GET", h.apiURL+"/api/ng/applications", nil)
	if err != nil {
		return nil, err
	}

	h.setAuthHeaders(req)

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status %d", resp.StatusCode)
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var response struct {
		Applications []Application `json:"applications"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, err
	}

	for _, app := range response.Applications {
		if app.Name == appName {
			return &app, nil
		}
	}

	return nil, fmt.Errorf("application %s not found", appName)
}

// GetServer retrieves a server by name
func (h *ContrastHelper) GetServer(serverName string) (*Server, error) {
	req, err := http.NewRequest("GET", h.apiURL+"/api/ng/servers", nil)
	if err != nil {
		return nil, err
	}

	h.setAuthHeaders(req)

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status %d", resp.StatusCode)
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var response struct {
		Servers []Server `json:"servers"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, err
	}

	for _, server := range response.Servers {
		if server.Name == serverName {
			return &server, nil
		}
	}

	return nil, fmt.Errorf("server %s not found", serverName)
}

// GetAgent retrieves agent information for an application
func (h *ContrastHelper) GetAgent(appName string) (*Agent, error) {
	app, err := h.GetApplication(appName)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequest("GET", fmt.Sprintf("%s/api/ng/applications/%s/agents", h.apiURL, app.AppID), nil)
	if err != nil {
		return nil, err
	}

	h.setAuthHeaders(req)

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status %d", resp.StatusCode)
	}

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var response struct {
		Agents []Agent `json:"agents"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, err
	}

	if len(response.Agents) > 0 {
		return &response.Agents[0], nil
	}

	return nil, fmt.Errorf("no agents found for application %s", appName)
}

// ValidateAgentConfiguration validates that the agent is configured correctly
func (h *ContrastHelper) ValidateAgentConfiguration(t testing.TestingT, appName, expectedEnvironment string) {
	server, err := h.GetServer(fmt.Sprintf("%s-us-east-1", appName))
	require.NoError(t, err, "Failed to get server from Contrast")
	require.NotNil(t, server, "Server not found in Contrast")

	require.Equal(t, expectedEnvironment, strings.ToUpper(server.Environment), "Environment mismatch")
	require.Equal(t, "online", server.Status, "Server is not online")

	agent, err := h.GetAgent(appName)
	require.NoError(t, err, "Failed to get agent from Contrast")
	require.NotNil(t, agent, "Agent not found in Contrast")

	require.Equal(t, "active", agent.Status, "Agent is not active")
	require.Equal(t, "java", agent.Language, "Agent language is not Java")
}

// CleanupApplication removes an application from Contrast
func (h *ContrastHelper) CleanupApplication(appName string) error {
	app, err := h.GetApplication(appName)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("DELETE", fmt.Sprintf("%s/api/ng/applications/%s", h.apiURL, app.AppID), nil)
	if err != nil {
		return err
	}

	h.setAuthHeaders(req)

	resp, err := h.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("failed to delete application, status: %d", resp.StatusCode)
	}

	return nil
}

// setAuthHeaders sets the required authentication headers
func (h *ContrastHelper) setAuthHeaders(req *http.Request) {
	req.Header.Set("API-Key", h.apiKey)
	req.Header.Set("Authorization", h.serviceKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
}
