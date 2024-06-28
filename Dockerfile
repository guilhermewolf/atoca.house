# Use the official GitHub Actions runner image as the base image
FROM ghcr.io/actions/actions-runner:latest

# Switch to root user to install packages
USER root

# Install unzip and any other necessary packages
RUN apt-get update && \
    apt-get install -y unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the default user
USER runner

# Set the entrypoint to the default entrypoint of the base image
ENTRYPOINT ["/runner/entrypoint.sh"]
