#!/bin/bash

set -e

NODE_EXPORTER_VERSION="1.6.1"  # Change to desired version

ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

echo "Installing Node Exporter version $NODE_EXPORTER_VERSION for architecture $ARCH"

# Create node_exporter user if not exists
if ! id node_exporter >/dev/null 2>&1; then
  sudo useradd --no-create-home --shell /bin/false node_exporter
fi

cd /tmp

# Download Node Exporter
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
wget $NODE_EXPORTER_URL -O node_exporter.tar.gz

# Extract
tar xzf node_exporter.tar.gz
cd node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}

# Move binary
sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Start and enable service
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "Node Exporter installation complete."
echo "Running on port 9100"
echo "Check status with: sudo systemctl status node_exporter"
