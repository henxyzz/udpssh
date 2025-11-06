#!/bin/bash
set -e

# Start sshd in background
/usr/sbin/sshd
echo "[startup] sshd started"

# Start badvpn udpgw if binary exists
if [ -x /usr/bin/badvpn-udpgw ]; then
  # Listen on 0.0.0.0:7300 (UDP)
  /usr/bin/badvpn-udpgw --listen-addr 0.0.0.0:7300 --max-clients 1000 --max-connections-for-client 10 &
  echo "[startup] badvpn-udpgw started on 0.0.0.0:7300 (udp)"
else
  echo "[startup] badvpn-udpgw not found or not executable, skipping"
fi

# Give a tiny delay to let services bind
sleep 1

# Start the Node.js status server (will stay in foreground)
exec node /opt/statusapp/server.js
