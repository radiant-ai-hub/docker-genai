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
