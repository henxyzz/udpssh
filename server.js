// server.js
const express = require('express');
const { exec } = require('child_process');
const os = require('os');
const app = express();
const port = 8080;

app.set('view engine', 'ejs');

app.get('/api/status', async (req, res) => {
  try {
    const tcp = await runCmd('ss -tln');     // TCP listening
    const udp = await runCmd('ss -uln');     // UDP listening
    const ipPub = await getPublicIP();
    const ipLocal = getLocalIPs();
    const parsed = { tcp: parseSs(tcp), udp: parseSs(udp), ipPub, ipLocal };
    res.json(parsed);
  } catch (err) {
    res.status(500).json({ error: String(err) });
  }
});

app.get('/', async (req, res) => {
  const tcp = await runCmd('ss -tln');
  const udp = await runCmd('ss -uln');
  const ipPub = await getPublicIP();
  const ipLocal = getLocalIPs();
  res.render('index', { tcpRaw: tcp, udpRaw: udp, tcpList: parseSs(tcp), udpList: parseSs(udp), ipPub, ipLocal });
});

// Helpers
function runCmd(cmd) {
  return new Promise((resolve, reject) => {
    exec(cmd, { maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) return reject(stderr || err);
      resolve(stdout.toString());
    });
  });
}

function parseSs(output) {
  // simple parse of ss output lines (skip header)
  const lines = output.split('\n').map(l => l.trim()).filter(l => l);
  // find header index (usually first line contains "State")
  let start = 0;
  if (lines[0] && lines[0].toLowerCase().includes('state')) start = 1;
  const rows = lines.slice(start).map(line => {
    // collapse multiple spaces, split
    const parts = line.replace(/\s+/g, ' ').split(' ');
    // typical last column is "local:port"
    const local = parts[4] || parts[3] || '';
    return { raw: line, local };
  });
  return rows;
}

async function getPublicIP() {
  // try couple services; if offline, fallback to hostname IPs
  const services = ['https://ifconfig.co/ip', 'https://icanhazip.com', 'https://ifconfig.me/ip'];
  for (const s of services) {
    try {
      const out = await runCmd(`curl -s --max-time 5 ${s}`);
      if (out && out.trim()) return out.trim();
    } catch (e) {
      // ignore and try next
    }
  }
  return null;
}

function getLocalIPs() {
  const nets = os.networkInterfaces();
  const ips = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (!net.internal) ips.push({ iface: name, address: net.address, family: net.family });
    }
  }
  return ips;
}

// Minimal EJS template embedded (no separate files) - fallback if views folder not present
const ejs = require('ejs');
const fs = require('fs');
const viewDir = __dirname + '/views';
if (!fs.existsSync(viewDir)) {
  fs.mkdirSync(viewDir);
  fs.writeFileSync(viewDir + '/index.ejs', `
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Server Status</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  :root{--bg:#0b0f14;--card:#0f1720;--muted:#9aa4b2;--accent:#7c3aed}
  body{margin:0;font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto,'Helvetica Neue',Arial;background:var(--bg);color:#e6eef6}
  .wrap{max-width:1000px;margin:28px auto;padding:20px}
  header{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px}
  .brand{font-weight:700;font-size:20px;color:var(--accent)}
  .card{background:var(--card);padding:16px;border-radius:12px;box-shadow:0 6px 18px rgba(2,6,23,0.6);margin-bottom:12px}
  table{width:100%;border-collapse:collapse}
  th,td{padding:8px;text-align:left;border-bottom:1px solid rgba(255,255,255,0.03);font-family:monospace}
  .muted{color:var(--muted);font-size:13px}
  .tag{background:rgba(255,255,255,0.03);padding:6px 8px;border-radius:999px;font-size:13px}
  .row{display:flex;gap:12px;flex-wrap:wrap}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div><div class="brand">🔧 Node Status Panel</div><div class="muted">SSH + BadVPN + Status</div></div>
    <div class="tag">Port 8080</div>
  </header>

  <div class="card">
    <h3>IP Info</h3>
    <div class="muted">Public IP:</div>
    <div><strong><%= ipPub || 'Unknown' %></strong></div>
    <div class="muted" style="margin-top:8px">Local Interfaces:</div>
    <ul>
      <% ipLocal.forEach(i => { %>
        <li><%= i.iface %> — <%= i.address %> (<%= i.family %>)</li>
      <% }) %>
    </ul>
  </div>

  <div class="card">
    <h3>Listening TCP Ports</h3>
    <table>
      <thead><tr><th>Local</th><th>Raw</th></tr></thead>
      <tbody>
        <% tcpList.forEach(r => { %>
          <tr><td><%= r.local %></td><td><%= r.raw %></td></tr>
        <% }) %>
      </tbody>
    </table>
  </div>

  <div class="card">
    <h3>Listening UDP Ports</h3>
    <table>
      <thead><tr><th>Local</th><th>Raw</th></tr></thead>
      <tbody>
        <% udpList.forEach(r => { %>
          <tr><td><%= r.local %></td><td><%= r.raw %></td></tr>
        <% }) %>
      </tbody>
    </table>
  </div>

  <div class="card muted">
    Tip: jika port UDP (7300) tidak terlihat di sini, kemungkinan container tidak binding UDP atau PaaS memblok UDP.
  </div>
</div>
</body>
</html>
  `);
}

app.listen(port, () => {
  console.log(`Status web ready — http://0.0.0.0:${port}`);
});
