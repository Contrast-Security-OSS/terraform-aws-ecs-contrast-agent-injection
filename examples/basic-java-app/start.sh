#!/bin/sh
# Example application startup script with Contrast agent injection

echo "Starting application: ${APP_NAME}"
echo "Environment: ${APP_ENV}"

# =================================================================
# --- Begin Contrast Agent Dynamic Injection Block ---
# This block checks if the Contrast agent should be activated.
# If CONTRAST_ENABLED is set to "true", it prepends the
# -javaagent flag to the JAVA_TOOL_OPTIONS environment variable.
# This ensures the JVM loads the agent without altering the core
# application command. The path /opt/contrast/java/contrast-agent.jar
# corresponds to the shared volume mount point in the app container.
# =================================================================
if [ "$CONTRAST_ENABLED" = "true" ]; then
    echo "Contrast agent is enabled. Injecting agent into JAVA_TOOL_OPTIONS."
    
    # Define the path to the agent JAR
    CONTRAST_AGENT_PATH="/opt/contrast/java/contrast-agent.jar"
    
    # Check if the agent file exists
    if [ -f "$CONTRAST_AGENT_PATH" ]; then
        echo "Contrast agent found at: $CONTRAST_AGENT_PATH"
        
        # Prepend the Contrast javaagent to any existing JAVA_TOOL_OPTIONS
        # This allows multiple agents (e.g., DataDog, Contrast) to coexist.
        export JAVA_TOOL_OPTIONS="-javaagent:${CONTRAST_AGENT_PATH} ${JAVA_TOOL_OPTIONS}"
        
        echo "Updated JAVA_TOOL_OPTIONS: ${JAVA_TOOL_OPTIONS}"
    else
        echo "WARNING: Contrast agent file not found at $CONTRAST_AGENT_PATH"
        echo "Continuing without Contrast agent..."
    fi
else
    echo "Contrast agent is disabled (CONTRAST_ENABLED != 'true')"
fi
# --- End Contrast Agent Dynamic Injection Block ---

# Set JVM options for container environment
export JAVA_OPTS="${JAVA_OPTS} -XX:MaxRAMPercentage=75.0"
export JAVA_OPTS="${JAVA_OPTS} -XX:+UseG1GC"
export JAVA_OPTS="${JAVA_OPTS} -XX:+UseStringDeduplication"

# If you have DataDog APM, it would be configured here
if [ "$DD_AGENT_ENABLED" = "true" ]; then
    echo "DataDog APM is enabled"
    export DD_AGENT_HOST="localhost"
    export DD_TRACE_ENABLED="true"
fi

# Log startup information
echo "Starting Java application..."
echo "JAVA_OPTS: ${JAVA_OPTS}"
echo "JAVA_TOOL_OPTIONS: ${JAVA_TOOL_OPTIONS}"

# Execute the application
# Replace this with your actual application startup command
exec java ${JAVA_OPTS} -jar /app/application.jar "$@"
