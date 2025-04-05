FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Verify ARM64 architecture
RUN dpkg --print-architecture | grep -q "arm64" || (echo "This Dockerfile must be built on ARM64" && exit 1)

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Add deadsnakes PPA for Python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa

# Install Python 3.12 and required packages
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python3-pip \
    python3-requests \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --set python3 /usr/bin/python3.12 \
    && ln -s /usr/bin/python3 /usr/bin/python

# Install Node.js 23 for ARM64
RUN curl -fsSL https://deb.nodesource.com/setup_23.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js architecture
RUN node -e 'if (process.arch !== "arm64") { console.error("Node.js must be ARM64 version"); process.exit(1); }'

# Verify versions and architectures
RUN echo "Architecture:" && dpkg --print-architecture && \
    echo "Python version:" && python3 --version && \
    echo "Node version:" && node --version && \
    echo "Testing Python packages:" && \
    python3 -c "import requests; import argparse; print('Packages successfully imported')" && \
    python3 -c 'import platform; assert "aarch64" in platform.machine(), "Python must be ARM64 version"'

CMD ["/bin/bash"]