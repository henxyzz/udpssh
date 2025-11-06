# Base Debian
FROM debian:bullseye

# Install paket
RUN apt update && apt install -y wget openssh-server screen && \
    mkdir /var/run/sshd

# Buat user SSH
RUN useradd -m vpnuser && echo 'vpnuser:vpnpassword' | chpasswd

# Izinkan login password + root SSH
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo "PermitTunnel yes" >> /etc/ssh/sshd_config

# Install badvpn
RUN wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/tgkxdwb03r7w59r/badvpn-udpgw" && \
    chmod +x /usr/bin/badvpn-udpgw

# Port
EXPOSE 22/tcp
EXPOSE 7300/udp

# Jalankan SSH & BadVPN bersamaan
CMD service ssh start && /usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 1000
