# n8n with Python Support

This repository contains a Docker setup for running n8n workflow automation with Python support. The setup includes:

- Latest n8n version
- Python 3.11
- pyrsm package
- n8n-nodes-python module for Python integration

## 📋 Requirements

- Docker and Docker Compose installed on your system
- Docker with AMD64 support (Intel Mac or AMD64 Linux)
- Internet connection for building the image

## 🚀 Quick Start

1. Clone this repository or download the Dockerfile and docker-compose.yml
2. Run the following command to start n8n:

```bash
docker compose build --no-cache
docker compose up -d
```

3. Access the n8n web interface at http://localhost:5678

## 🛠️ Configuration

### Environment Variables

You can configure the setup using the following environment variables in the docker-compose.yml file:

- `USER`: Set to `node` for better security (recommended)
- `NODE_ENV`: Set to `production` for production use
- `N8N_ENCRYPTION_KEY`: Secret key for encrypting credentials (change this!)
- `GENERIC_TIMEZONE`: Set your preferred timezone (e.g., UTC, America/New_York)

### Volumes

The setup uses a Docker volume to persist your n8n data:

- `n8n_data`: Stores workflows, credentials, and other n8n data

## 🔧 Using Python in n8n

Once n8n is running, you can use Python in your workflows as follows:

1. Create a new workflow in the n8n web interface
2. Add a "Python" node (search for "Python" in the nodes panel)
3. Write your Python code in the script editor
4. Your Python environment has access to:
   - Python 3.11 standard libraries
   - UV package manager (installed system-wide)
   - pyrsm package
   - Other Python libraries installed via pip

Example Python script to test your environment:

```python
import sys
import platform

# Test if UV and pyrsm are available
try:
    import pyrsm
    pyrsm_available = True
except ImportError:
    pyrsm_available = False

# Return information about the Python environment
return {
    "python_version": sys.version,
    "platform": platform.platform(),
    "pyrsm_available": pyrsm_available
}
```

## 🔄 Updating

To update your n8n installation to the latest version:

1. Modify the `N8N_VERSION` in the Dockerfile (if you want a specific version) or keep it as `latest`
2. Rebuild the container:

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## 📦 Installing Additional Python Packages

There are two ways to install additional Python packages:

### Option 1: Modify the Dockerfile

Add the packages to the Dockerfile before the build:

```dockerfile
# Install pyrsm and your additional packages
RUN pip install pyrsm your-package1 your-package2
```

### Option 2: Install inside the running container

```bash
# Access the container
docker exec -it n8n-python bash

# Install packages using pip
pip install your-package-name

# Or if you prefer to use UV (if available)
uv pip install your-package-name
```

## 🔍 Troubleshooting

### Logs

To check the logs of your n8n container:

```bash
docker compose logs -f
```

### Container Access

To access the running container:

```bash
docker exec -it n8n-python bash
```

### Python Version Verification

Once inside the container, verify Python is working:

```bash
python --version
```

### n8n-nodes-python Check

Verify the Python module is correctly installed:

```bash
cd $(npm root -g)/n8n
npm list | grep n8n-nodes-python
```

## 🔒 Security Notes

- Change the `N8N_ENCRYPTION_KEY` to a secure value in production
- The container runs n8n as the `node` user for better security
- Consider setting up HTTPS if exposing n8n to the internet
- Regularly update the container to get security fixes

## 📌 Manual Docker Commands

If you prefer not to use Docker Compose, you can use these Docker commands:

```bash
# Build the image
docker build -t n8n-python:latest .

# Create a volume for persistent data
docker volume create n8n_data

# Run the container
docker run -d --name n8n-python \
  -p 5678:5678 \
  -e USER=node \
  -e NODE_ENV=production \
  -e N8N_ENCRYPTION_KEY=your-encryption-key-here \
  -v n8n_data:/home/node/.n8n \
  n8n-python:latest
```

## 📄 License

n8n is licensed under the [fair-code](https://faircode.io) [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/packages/cli/LICENSE.md).