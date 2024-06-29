FROM ghcr.io/actions/actions-runner:2.317.0

# Switch to root user to install packages
USER root

# Install unzip and any other necessary packages
RUN apt-get update && \
    apt-get install -y unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the default user
USER runner
