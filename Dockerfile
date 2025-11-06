# ==========================================
# 🐧 Debian + OpenSSH + Node.js + badvpn + Web Status
# ==========================================
FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------
# Install dependencies
# ------------------------------------------
RUN apt-get update && apt-get install -y \
    wget curl ca-certificates gnupg2 apt-transport-https \
    openssh-server iproute2 iputils-ping net-tools procps \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------
# Install Node.js 18 LTS
# ------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm --version && node --version

# ------------------------------------------
# Setup SSH
# ------------------------------------------
RUN mkdir -p /var/run/sshd
RUN useradd -m vpnuser && echo 'vpnuser:ChangeMe123!' | chpasswd
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
RUN echo "PermitTunnel yes" >> /etc/ssh/sshd_config || true
RUN echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
RUN echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# ------------------------------------------
# Install badvpn
# ------------------------------------------
RUN wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/tgkxdwb03r7w59r/badvpn-udpgw?dl=1" \
    && chmod +x /usr/bin/badvpn-udpgw || true

# ------------------------------------------
# App section (langsung di root, bukan subfolder)
# ------------------------------------------
WORKDIR /opt/statusapp

# Copy all files langsung (biar gak error COPY)
COPY . .

# Install node dependencies
RUN npm install --production || true

# ------------------------------------------
# Permission
# ------------------------------------------
RUN chmod +x /opt/statusapp/start.sh || true

# ------------------------------------------
# Expose ports
# ------------------------------------------
EXPOSE 22/tcp
EXPOSE 8080/tcp
EXPOSE 7300/udp

# ------------------------------------------
# Start all services (SSH, badvpn, Node.js)
# ------------------------------------------
CMD ["/opt/statusapp/start.sh"]
