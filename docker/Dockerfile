# Custom Contrast Init Container
# This Dockerfile creates a custom init container for the Contrast agent

# Use the official Contrast agent image as base
FROM contrast/agent-java:latest AS contrast

# Start with a minimal base image
FROM alpine:3.18

# Install required utilities
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates

# Copy the Contrast agent from the official image
COPY --from=contrast /contrast/contrast-agent.jar /contrast/contrast-agent.jar

# Add any custom initialization scripts
COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

# Create a non-root user
RUN addgroup -g 1000 contrast && \
    adduser -D -u 1000 -G contrast contrast

# Switch to non-root user
USER contrast

# Set the working directory
WORKDIR /contrast

# Default command (can be overridden in task definition)
CMD ["/usr/local/bin/init.sh"]
