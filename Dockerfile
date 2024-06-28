# Use an alternative base image that supports multiple architectures
FROM ubuntu:24.04

# Install necessary packages and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    jq && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub Actions runner
RUN mkdir -p /runner
WORKDIR /runner

# Download and install the latest GitHub Actions runner
RUN curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.294.0/actions-runner-linux-x64-2.294.0.tar.gz && \
    tar xzf ./actions-runner-linux-x64.tar.gz && \
    rm -f ./actions-runner-linux-x64.tar.gz

# Install GitHub Actions runner dependencies
RUN ./bin/installdependencies.sh

# Set the entrypoint
ENTRYPOINT ["/runner/entrypoint.sh"]
