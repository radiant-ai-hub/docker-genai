#!/bin/bash

set -e

# Update package lists
sudo apt update

# Install required dependencies
sudo apt install -y \
  gcc \
  pandoc \
  libsnappy-dev \
  cmake \
  wget \
  gdebi-core
 
##  mechanism to force source installs if we're using RSPM
UBUNTU_VERSION=${UBUNTU_VERSION:-`lsb_release -sc`}

if [ "$(uname -m)" != "aarch64" ]; then
    wget https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb -O quarto.deb
else
    wget https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-arm64.deb -O quarto.deb
fi

gdebi -n quarto.deb # adding -n to run non-interactively

# Clean up
rm -rf quarto.deb
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/downloaded_packages