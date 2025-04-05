#!/bin/bash
set -e  # Exit on error

echo "Installing packages that are needed for all next steps"

# Update package list with reduced output
apt update -qq || { echo "Failed to update package list"; exit 1; }

# System utilities
echo "Installing system utilities..."
apt -y install \
  liblzma5 \
  liblzma-dev \
  sudo \
  curl \
  lsb-release \
  wget \
  ca-certificates \
  gdebi-core

# Shell and editors
echo "Installing shell and editors..."
apt -y install \
  zsh \
  autojump \
  vim \
  vifm

# Development tools
echo "Installing development tools..."
apt -y install \
  git \
  rsync \
  pipx

# System monitoring
echo "Installing monitoring tools..."
apt -y install \
  htop \
  lsof

# File management
echo "Installing file management tools..."
apt -y install \
  rename

echo "Cleaning up after installation..."
apt clean
apt autoremove -y
update-ca-certificates -f || { echo "Failed to update certificates"; exit 1; }
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
#     sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
#     sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
#     useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" --no-user-group "${NB_USER}" && \
#     chmod g+w /etc/passwd
userdel -f $(getent passwd 1000 | cut -d: -f1) || true
useradd --no-log-init --create-home --shell /bin/bash --uid "${NB_UID}" --no-user-group "${NB_USER}"

# Setup user permissions
echo "Configuring user permissions..."
echo "jovyan ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jovyan
chmod 0440 /etc/sudoers.d/jovyan
chmod g+w /etc/passwd

# Set shell for jovyan user
echo "Setting default shell to zsh..."
usermod -s /bin/zsh jovyan || { echo "Failed to change shell"; exit 1; }

echo "Installation completed successfully"


