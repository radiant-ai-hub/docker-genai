FROM ubuntu:24.04
# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
# Work around GPG signature issues by allowing unauthenticated packages temporarily
RUN echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/99allow-unauthenticated
# Verify AMD64 architecture
RUN dpkg --print-architecture | grep -q "amd64" || (echo "This Dockerfile must be built on AMD64" && exit 1)
# Install basic dependencies
RUN apt-get update -o Acquire::AllowInsecureRepositories=true && apt-get install --allow-unauthenticated -y \
curl \
wget \
gnupg \
software-properties-common \
build-essential \
graphicsmagick \
gosu \
git \
ca-certificates \
&& rm -rf /var/lib/apt/lists/*
# Add deadsnakes PPA for Python 3.11
RUN add-apt-repository ppa:deadsnakes/ppa
# Install Python 3.11 and required packages
RUN apt-get update -o Acquire::AllowInsecureRepositories=true && apt-get install --allow-unauthenticated -y \
python3.11 \
python3.11-dev \
python3.11-venv \
python3-pip \
python3-requests \
&& rm -rf /var/lib/apt/lists/*
# Set Python 3.11 as default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
&& update-alternatives --set python3 /usr/bin/python3.11 \
&& ln -s /usr/bin/python3 /usr/bin/python
# Install Node.js 22 for AMD64
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
&& apt-get update -o Acquire::AllowInsecureRepositories=true \
&& apt-get install --allow-unauthenticated -y nodejs \
&& rm -rf /var/lib/apt/lists/*
# Verify Node.js architecture
RUN node -e 'if (process.arch !== "x64") { console.error("Node.js must be AMD64 version"); process.exit(1); }'
# Install pyrsm with pip
RUN pip install pyrsm
# Create a node user and group
RUN groupadd -r node && useradd -r -g node -m node
# Set up directories with proper permissions
RUN mkdir -p /home/node/.n8n && chown -R node:node /home/node/.n8n
# Install n8n and any ICU support if needed
ENV N8N_VERSION=latest
# Split installation to avoid disk space issues during build
RUN npm_config_user=root npm install -g full-icu
RUN npm_config_user=root npm install -g n8n@${N8N_VERSION}
# Install the n8n-nodes-python module
RUN cd $(npm root -g)/n8n && npm install n8n-nodes-python
# Set ICU environment variable
ENV NODE_ICU_DATA=/usr/lib/node_modules/full-icu
# Simple verification of installed versions
RUN echo "Architecture:" && dpkg --print-architecture && \
echo "Python version:" && python3 --version && \
echo "Node version:" && node --version
# Create entrypoint script
RUN echo '#!/bin/bash\n\
if [ "$USER" = "node" ]; then\n\
echo "Running as node user"\n\
exec gosu node "$@"\n\
else\n\
echo "Running as root user"\n\
exec "$@"\n\
fi' > /docker-entrypoint.sh && \
chmod +x /docker-entrypoint.sh
EXPOSE 5678/tcp
WORKDIR /home/node
VOLUME /home/node/.n8n
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["n8n", "start"]