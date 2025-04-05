# from https://hub.docker.com/r/nikolaik/python-nodejs
FROM nikolaik/python-nodejs:python3.12-nodejs23

USER root

# Define build argument and set it as an environment variable in one step
ARG DOCKERHUB_VERSION
ENV DOCKERHUB_VERSION=${DOCKERHUB_VERSION}
ENV DOCKERHUB_NAME="rsm-msba-genai-intel"
ENV QUARTO_VERSION="1.7.5"
ENV TERM=xterm
ENV PATH="/usr/local/bin:$PATH"

# postgres env variables
ENV POSTGRES_VERSION=16
ENV PGPASSWORD=postgres

# Jupyter and shell environment setup
ARG RSMBASE=/home/${NB_USER}/.rsm-msba
ENV RSMBASE=${RSMBASE} \
    SHELL=/bin/zsh \
    ZDOTDIR=/home/${NB_USER}/.rsm-msba/zsh

# Add autojump to initial package installation
COPY files/init-apt.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

COPY files/postgres/postgresql.conf /etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf
COPY files/postgres/pg_hba.conf /etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf

COPY files/postgres/install-postgres.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

COPY files/install-sshd.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

COPY files/install-quarto.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

# Copy the launch script into the image
COPY launch-${DOCKERHUB_NAME}.sh /opt/launch.sh
COPY files/zsh/setup.sh /usr/local/bin/setup
RUN chmod 755 /usr/local/bin/*

# Create log directories with proper permissions
RUN mkdir -p /var/log/postgresql /var/log/sshd && \
    chown postgres:postgres /var/log/postgresql && \
    chmod 750 /var/log/postgresql

# Oh-my-zsh and other zsh setup
COPY files/install-ohmyzsh.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

COPY files/zsh/zshrc /etc/skel/.zshrc
COPY files/zsh/p10k.zsh /etc/skel/.p10k.zsh
COPY files/zsh/usethis /usr/local/bin/usethis
COPY files/zsh/github.sh /usr/local/bin/github

# startup script that starts sshd and postgres and manages permissions
COPY files/start-container.sh /usr/local/bin/
COPY files/sshd/sshd_config /etc/ssh/sshd_config
RUN chmod +x /usr/local/bin/start-container.sh

# setup the GitHub CLI
COPY files/install-gh.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

# setup UV
COPY files/install-uv.sh setup.sh
RUN chmod +x setup.sh && \
    ./setup.sh && \
    rm setup.sh

EXPOSE 22 8765

CMD ["/usr/local/bin/start-container.sh"]

# Switch back to jovyan to avoid accidental container runs as root
USER ${NB_UID}
ENV HOME /home/${NB_USER}
WORKDIR "${HOME}"