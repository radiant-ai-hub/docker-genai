#!/bin/bash
set -e

echo "Starting container initialization..."

# If NB_UID/NB_GID are set, modify user/group accordingly
if [ ! -z "$NB_UID" ] && [ ! -z "$NB_GID" ]; then
    # Create new group first if it doesn't exist
    echo "Creating group ${NB_GROUP:-${NB_USER}} with GID: $NB_GID"
    sudo groupadd -g $NB_GID -o ${NB_GROUP:-${NB_USER}} || true

    # Modify user's primary group and UID
    echo "Setting ${NB_USER} UID to: $NB_UID and GID to: $NB_GID"
    sudo usermod -u $NB_UID -g $NB_GID ${NB_USER}

    # Only set ownership of essential directories
    echo "Setting ownership of essential directories..."
    sudo chown $NB_UID:$NB_GID /home/${NB_USER}
fi

echo "Creating and setting permissions for RSMBASE directories..."

# Create RSMBASE directory
mkdir -p ${RSMBASE}
chmod -R 755 ${RSMBASE}
chmod g+s ${RSMBASE}    # set the setgid bit

# Create RSMBASE directory if they don't exist
mkdir -p ${RSMBASE}/zsh

# Set proper permissions for RSMBASE directory
sudo chown -R ${NB_USER}:${NB_GID:-users} ${RSMBASE}

# Create and set permissions for log files
echo "Creating and setting permissions for log files..."
sudo touch /var/log/sshd/sshd.log
sudo chown ${NB_USER}:${NB_GID:-users} /var/log/sshd/sshd.log
sudo chmod 640 /var/log/sshd/sshd.log

echo "Starting SSHD service..."
sudo /usr/sbin/sshd -E /var/log/sshd/sshd.log

echo "Starting PostgreSQL service..."
sudo -u postgres /usr/lib/postgresql/${POSTGRES_VERSION}/bin/postgres \
    -c config_file=/etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf &

echo "Starting n8n ..."
sudo /usr/local/bin/n8n start \

echo "All services started. Tailing logs..."
tail -f /var/log/sshd/sshd.log &
sleep 2
sudo -u postgres tail -f /var/log/postgresql/postgresql-*.log 2>/dev/null &

# making sure that /bin/zsh is the default
sudo usermod -s /bin/zsh jovyan || echo "Failed to change shell"

# Wait for all background processes
wait
