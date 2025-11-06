# Dockerfile - Debian + OpenSSH + Node + badvpn
FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive
# Install requirements: curl,wget,openssh,net-tools (ss), ca-certificates, nodejs
RUN apt-get update && apt-get install -y \
    wget curl ca-certificates gnupg2 apt-transport-https \
    openssh-server iproute2 iputils-ping net-tools procps \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18 (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm --version && node --version

# Create sshd runtime dir
RUN mkdir -p /var/run/sshd

# Create vpn user (change password after deploy!)
RUN useradd -m vpnuser && echo 'vpnuser:ChangeMe123!' | chpasswd

# Configure SSH (allow password auth so HTTP Custom can use it if needed)
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN echo "PermitTunnel yes" >> /etc/ssh/sshd_config || true
RUN echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
RUN echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# Install badvpn binary (replace with your trusted source if available)
# NOTE: Using remote binary - for production build your own binary or use package build.
RUN wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/tgkxdwb03r7w59r/badvpn-udpgw" || true
RUN chmod +x /usr/bin/badvpn-udpgw || true

# App directory
WORKDIR /opt/statusapp

# Copy node app files
COPY package.json package-lock.json* ./ || true
COPY server.js start.sh ./

RUN chmod +x /opt/statusapp/start.sh

# Expose ports
EXPOSE 22/tcp
EXPOSE 8080/tcp
EXPOSE 7300/udp

# Default command: start service script (sshd + badvpn + node)
CMD ["/opt/statusapp/start.sh"]
