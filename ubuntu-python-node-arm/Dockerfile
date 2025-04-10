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
    graphicsmagick \
    gosu \
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

# Install Node.js 22 for ARM64
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
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

# Rename user 'pn' to 'node' so that n8n runs as node
# RUN usermod --login node --move-home --home /home/node pn && \
#     groupmod --new-name node pn

# specify n8n version to use
ENV N8N_VERSION=1.87.2

# Install n8n (using the specified version) and any ICU support if needed
# Install the n8n-nodes-python module and any additional node modules you require
# For example, if you have another node module to install, add it after n8n-nodes-python
RUN npm_config_user=root npm install -g full-icu n8n@${N8N_VERSION}
RUN cd $(npm root -g)/n8n && npm install n8n-nodes-python

# Set ICU environment variable if required
ENV NODE_ICU_DATA=/usr/lib/node_modules/full-icu

EXPOSE 5678/tcp

CMD ["n8n"]
# CMD ["/usr/local/bin/start-container.sh"]

# switch back to jovyan to avoid accidental container runs as root
# USER ${NB_UID}
# ENV HOME /home/${NB_USER}
# WORKDIR "${HOME}"
