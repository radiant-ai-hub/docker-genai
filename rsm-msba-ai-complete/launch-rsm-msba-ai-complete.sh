#!/bin/bash

# Create necessary directories
mkdir -p n8n/backup shared

# Display header
echo "---------------------------------------------------------------------------"
echo "RSM MSBA AI Environment Setup"
echo "---------------------------------------------------------------------------"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker before continuing."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose before continuing."
    exit 1
fi

# Set up environment variables
if [ ! -f ".env" ]; then
    echo "Creating default .env file..."
    cat > .env << 'EOF'
# PostgreSQL Settings
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8n
POSTGRES_DB=n8n

# n8n Settings
N8N_ENCRYPTION_KEY=YourEncryptionKey
N8N_USER_MANAGEMENT_JWT_SECRET=YourJWTSecret

# Domain Settings (for Traefik)
DOMAIN_NAME=localhost
SUBDOMAIN=n8n
SSL_EMAIL=example@example.com

# Optional API Keys
MCP_BRAVE_API_KEY=
MCP_OPENAI_API_KEY=
EOF
    echo "Created default .env file. You may want to edit it with your own values."
fi

# Create n8n Dockerfile if it doesn't exist
if [ ! -f "n8n/Dockerfile" ]; then
    echo "Creating n8n Dockerfile..."
    cat > n8n/Dockerfile << 'EOF'
# Use a base image that includes both Python and Node.js
FROM nikolaik/python-nodejs:python3.10-nodejs18

# Rename user 'pn' to 'node' so that n8n runs as node
RUN usermod --login node --move-home --home /home/node pn && \
    groupmod --new-name node pn

# Specify n8n version as an argument
ARG N8N_VERSION=1.84.1

# Install any system dependencies required by n8n or your additional packages
RUN apt-get update && \
    apt-get -y install graphicsmagick gosu git

# Create a directory for python requirements and copy your requirements file
RUN mkdir /requirements

# Create requirements.txt
RUN echo "requests\npandas\nnumpy\nscipy\nscikit-learn\ntransformers\ntorch\npillow\nmatplotlib\nseaborn" > /requirements/requirements.txt

# Upgrade pip and install python dependencies
RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install -r /requirements/requirements.txt

# Switch to root to install global npm packages
USER root

# Install n8n and ICU support
RUN npm_config_user=root npm install -g full-icu n8n@${N8N_VERSION}
RUN cd $(npm root -g)/n8n && npm install n8n-nodes-python

# Set ICU environment variable
ENV NODE_ICU_DATA /usr/lib/node_modules/full-icu

# Set working directory
WORKDIR /data

# Expose n8n port
EXPOSE 5678/tcp

CMD ["n8n"]
EOF
    echo "Created n8n Dockerfile."
fi

# Function to check if containers are running
check_containers() {
    echo "Checking container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E 'rsm-msba|n8n|ollama|qdrant|postgres|traefik'
}

# Function to stop all containers
stop_containers() {
    echo "Stopping containers..."
    docker-compose -f docker-compose-rsm-msba-ai-complete.yml down
    echo "Containers stopped."
}

# Create the docker-compose file
cat > docker-compose-rsm-msba-ai-complete.yml << 'EOF'
services:
  # RSM MSBA container
  rsm-msba:
    image: vnijs/rsm-msba-genai-intel:latest
    container_name: rsm-msba-genai-intel
    environment:
      TZ: America/Los_Angeles
      USER: jovyan
      HOME: /home/jovyan
      SHELL: /bin/zsh
      ZDOTDIR: /home/jovyan/.rsm-msba/zsh
      RSMBASE: /home/jovyan/.rsm-msba
      # Add Ollama environment variable for internal access
      OLLAMA_HOST: ollama:11434
    volumes:
      - ${HOME}:/home/jovyan
      - pg_data:/var/lib/postgresql/16/main
    networks:
      - rsm-genai
    ports:
      - 127.0.0.1:8765:8765

  # Traefik proxy
  traefik:
    image: "traefik"
    restart: always
    command:
      - "--api=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.mytlschallenge.acme.tlschallenge=true"
      - "--certificatesresolvers.mytlschallenge.acme.email=${SSL_EMAIL:-example@example.com}"
      - "--certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - traefik_data:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - rsm-genai

  # PostgreSQL database (shared between n8n and potentially other services)
  postgres:
    image: postgres:16-alpine
    hostname: postgres
    networks: ['rsm-genai']
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER:-n8n}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-n8n}
      - POSTGRES_DB=${POSTGRES_DB:-n8n}
    volumes:
      - postgres_storage:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER:-n8n} -d ${POSTGRES_DB:-n8n}']
      interval: 5s
      timeout: 5s
      retries: 10

  # n8n workflow automation
  n8n:
    build: ./n8n
    hostname: n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - 5678:5678
    volumes:
      - n8n_storage:/home/node/.n8n
      - ./n8n/backup:/backup
      - ./shared:/data/shared
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(`${SUBDOMAIN:-n8n}.${DOMAIN_NAME:-localhost}`)
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.entrypoints=web,websecure
      - traefik.http.routers.n8n.tls.certresolver=mytlschallenge
      - traefik.http.middlewares.n8n.headers.SSLRedirect=true
      - traefik.http.middlewares.n8n.headers.STSSeconds=315360000
      - traefik.http.middlewares.n8n.headers.browserXSSFilter=true
      - traefik.http.middlewares.n8n.headers.contentTypeNosniff=true
      - traefik.http.middlewares.n8n.headers.forceSTSHeader=true
      - traefik.http.middlewares.n8n.headers.SSLHost=${DOMAIN_NAME:-localhost}
      - traefik.http.middlewares.n8n.headers.STSIncludeSubdomains=true
      - traefik.http.middlewares.n8n.headers.STSPreload=true
      - traefik.http.routers.n8n.middlewares=n8n@docker
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_USER=${POSTGRES_USER:-n8n}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD:-n8n}
      - N8N_HOST=${SUBDOMAIN:-n8n}.${DOMAIN_NAME:-localhost}
      - N8N_PORT=5678
      - N8N_PROTOCOL=${N8N_PROTOCOL:-https}
      - NODE_ENV=production
      - WEBHOOK_URL=${WEBHOOK_URL:-https://n8n.localhost/}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-YourEncryptionKey}
      - N8N_USER_MANAGEMENT_JWT_SECRET=${N8N_USER_MANAGEMENT_JWT_SECRET:-YourJWTSecret}
      - GENERIC_TIMEZONE=America/Los_Angeles
      - TZ=America/Los_Angeles
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_PERSONALIZATION_ENABLED=false
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
      - OLLAMA_HOST=ollama:11434
      # Add your API keys here as needed
      - MCP_BRAVE_API_KEY=${MCP_BRAVE_API_KEY:-}
      - MCP_OPENAI_API_KEY=${MCP_OPENAI_API_KEY:-}
    networks:
      - rsm-genai
    depends_on:
      postgres:
        condition: service_healthy

  # Qdrant vector database
  qdrant:
    image: qdrant/qdrant
    hostname: qdrant
    container_name: qdrant
    networks: ['rsm-genai']
    restart: unless-stopped
    ports:
      - 6333:6333
    volumes:
      - qdrant_storage:/qdrant/storage

  # Ollama for local AI models - CPU version by default
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    networks: ['rsm-genai']
    restart: unless-stopped
    ports:
      - 11434:11434
    volumes:
      - ollama_storage:/root/.ollama

  # Initial model pull for Ollama
  ollama-init:
    image: ollama/ollama:latest
    container_name: ollama-init
    networks: ['rsm-genai']
    volumes:
      - ollama_storage:/root/.ollama
    entrypoint: /bin/sh
    environment:
      - OLLAMA_HOST=ollama:11434
    command:
      - "-c"
      - "sleep 10 && ollama pull llama3"
    depends_on:
      - ollama

networks:
  rsm-genai:
    name: rsm-genai

volumes:
  pg_data:
    name: pg_data
  postgres_storage:
    name: postgres_storage
  n8n_storage:
    name: n8n_storage
  ollama_storage:
    name: ollama_storage
  qdrant_storage:
    name: qdrant_storage
  traefik_data:
    name: traefik_data
EOF

# Display menu
show_menu() {
    echo "---------------------------------------------------------------------------"
    echo "RSM MSBA AI Environment Menu"
    echo "---------------------------------------------------------------------------"
    echo "1) Start all services"
    echo "2) Stop all services"
    echo "3) Show container status"
    echo "4) Open RSM MSBA shell"
    echo "5) Open n8n shell"
    echo "6) Pull Ollama model (specify model name)"
    echo "q) Quit"
    echo "---------------------------------------------------------------------------"
    read -p "Enter your choice: " choice

    case "$choice" in
        1)
            echo "Starting all services..."
            echo "Checking for and removing conflicting containers first..."
            
            # Check if container exists and remove it if it does
            for container in qdrant ollama ollama-init n8n postgres traefik rsm-msba-genai-intel; do
                if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                    echo "Removing existing container: $container"
                    docker rm -f $container
                fi
            done
            
            # Make volumes external since they might already exist
            sed -i 's/name: pg_data/name: pg_data\n    external: true/' docker-compose-rsm-msba-ai-complete.yml
            sed -i 's/name: postgres_storage/name: postgres_storage\n    external: true/' docker-compose-rsm-msba-ai-complete.yml
            sed -i 's/name: n8n_storage/name: n8n_storage\n    external: true/' docker-compose-rsm-msba-ai-complete.yml
            sed -i 's/name: ollama_storage/name: ollama_storage\n    external: true/' docker-compose-rsm-msba-ai-complete.yml
            sed -i 's/name: qdrant_storage/name: qdrant_storage\n    external: true/' docker-compose-rsm-msba-ai-complete.yml
            sed -i 's/name: traefik_data/name: traefik_data\n    external: true/' docker-compose-rsm-msba-ai-complete.yml
            
            # Start the services
            docker-compose -f docker-compose-rsm-msba-ai-complete.yml up -d
            echo "All services started."
            echo ""
            echo "Access points:"
            echo "- RSM MSBA: http://localhost:8765"
            echo "- n8n: http://localhost:5678"
            echo "- Qdrant: http://localhost:6333"
            echo "- Ollama: http://localhost:11434"
            ;;
        2)
            stop_containers
            ;;
        3)
            check_containers
            ;;
        4)
            echo "Opening RSM MSBA shell..."
            docker exec -it rsm-msba-genai-intel /bin/zsh
            ;;
        5)
            echo "Opening n8n shell..."
            docker exec -it n8n /bin/bash
            ;;
        6)
            read -p "Enter Ollama model name to pull (e.g., llama3): " model_name
            if [ -n "$model_name" ]; then
                echo "Pulling Ollama model: $model_name..."
                docker exec -it ollama ollama pull "$model_name"
            else
                echo "No model name provided."
            fi
            ;;
        q|Q)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
    clear
    show_menu
}

# Make the script executable
chmod +x launch-rsm-msba-ai-complete.sh

# Show the menu to start
clear
show_menu