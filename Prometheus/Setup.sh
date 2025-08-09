 
#!/bin/bash

set -e

PROM_VERSION="2.45.0"  # Change to desired version or script could fetch latest dynamically
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "Installing Prometheus version $PROM_VERSION for architecture $ARCH"

# Download URL
PROM_URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz"

# Create prometheus user and group if not exists
if ! id prometheus >/dev/null 2>&1; then
  sudo useradd --no-create-home --shell /bin/false prometheus
fi

# Create directories
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Download Prometheus
cd /tmp
wget $PROM_URL -O prometheus.tar.gz

# Extract
tar xzf prometheus.tar.gz

cd prometheus-${PROM_VERSION}.linux-${ARCH}

# Copy binaries
sudo cp prometheus promtool /usr/local/bin/

# Copy consoles and console_libraries
sudo cp -r consoles /etc/prometheus
sudo cp -r console_libraries /etc/prometheus

# Copy default config
sudo cp prometheus.yml /etc/prometheus/prometheus.yml

# Change ownership
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Create systemd service
sudo tee /etc/systemd/system/prometheus.service > /dev/null << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file /etc/prometheus/prometheus.yml \\
  --storage.tsdb.path /var/lib/prometheus/ \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

echo "Prometheus installation and setup complete."
echo "Check status with: sudo systemctl status prometheus"
echo "Prometheus is running on default port 9090"
