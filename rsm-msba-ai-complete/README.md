# RSM MSBA AI Complete Environment

This project integrates the RSM MSBA GenAI environment with n8n, Ollama, Qdrant, and other AI tools in a single Docker Compose setup.

## Components

- **RSM MSBA GenAI**: The main data science container for RSM MSBA students
- **n8n**: Workflow automation tool with Python support
- **Ollama**: Local LLM hosting
- **Qdrant**: Vector database for AI applications
- **PostgreSQL**: Database for n8n and other services
- **Traefik**: Reverse proxy for HTTPS and routing

## Prerequisites

- Docker and Docker Compose installed
- At least 8GB of RAM (16GB recommended)
- At least 20GB of free disk space

## Getting Started

1. Clone this repository or create a new directory for the project
2. Place the launch script and related files in this directory
3. Run the launch script:

```
./launch-rsm-msba-ai-complete.sh
```

4. Follow the on-screen menu options

## Accessing Services

- **RSM MSBA**: http://localhost:8765
- **n8n**: http://localhost:5678
- **Qdrant**: http://localhost:6333
- **Ollama**: http://localhost:11434 (API access)

## Customization

The `.env` file contains configuration options you can modify:

- Database credentials
- n8n encryption keys
- Domain settings for Traefik
- API keys for various services

## Using Ollama Models

You can pull and use different Ollama models:

1. From the menu, select option 6
2. Enter the model name (e.g., llama3, codellama, etc.)
3. The model will be pulled and available to use

## n8n Python Integration

n8n is configured with Python support. You can:

- Create Python nodes in n8n workflows
- Use the included Python libraries (pandas, numpy, etc.)
- Access the Ollama API via the OLLAMA_HOST environment variable

## Data Sharing

The following volumes are used to persist data:

- `pg_data`: PostgreSQL data for RSM MSBA
- `postgres_storage`: PostgreSQL data for n8n
- `n8n_storage`: n8n workflows and credentials
- `ollama_storage`: Ollama models
- `qdrant_storage`: Qdrant vector collections
- `traefik_data`: Traefik SSL certificates

The `shared` folder is mounted in both RSM MSBA and n8n containers for easy data exchange.

## Troubleshooting

If containers don't start properly:

1. Check logs: `docker-compose -f docker-compose-rsm-msba-ai-complete.yml logs`
2. Ensure ports aren't already in use
3. Try stopping and restarting: Select option 2, then option 1 from the menu