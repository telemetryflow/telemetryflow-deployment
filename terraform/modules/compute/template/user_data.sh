#!/bin/bash

# Enable logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "[START] UserData Script - $(date)"

# Detect OS, set default user and specific package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$NAME" == "Ubuntu" ]]; then
        OS="Ubuntu"
        DEFAULT_USER="ubuntu"
        PKG_MANAGER="apt-get"
        PKG_UPDATE="$PKG_MANAGER update && $PKG_MANAGER upgrade -y"
        PKG_INSTALL="$PKG_MANAGER install -y"
    elif [[ "$NAME" == *"Amazon Linux"* ]]; then
        OS="Amazon Linux"
        DEFAULT_USER="ec2-user"
        if [[ "$VERSION" == *"2023"* ]]; then
            PKG_MANAGER="dnf"
        else
            PKG_MANAGER="yum"
        fi
        PKG_UPDATE="$PKG_MANAGER update -y && $PKG_MANAGER upgrade -y"
        PKG_INSTALL="$PKG_MANAGER install -y"
    fi
fi

# Environment Variables
echo "[INFO] Setting up environment variables..."
ENVIRONMENT=${environment}
HOSTNAME=${hostname}
REGION=${region}

# Set hostname
hostnamectl set-hostname $HOSTNAME

# Update system packages
echo "[INFO] Updating system packages..."
eval $PKG_UPDATE

# Install common packages
echo "[INFO] Installing common packages..."
eval $PKG_INSTALL \
    amazon-cloudwatch-agent \
    aws-cli \
    curl \
    htop \
    jq \
    nc \
    net-tools \
    wget

# Configure AWS CLI
echo "[INFO] Configuring AWS CLI..."
if [[ "$OS" == "Ubuntu" ]]; then
    # Ubuntu configuration
    mkdir -p /home/ubuntu/.aws
    cat > /home/ubuntu/.aws/config <<EOF
[default]
region = $REGION
output = json
EOF
    chown -R ubuntu:ubuntu /home/ubuntu/.aws
else
    # Amazon Linux configuration (both AL2 and AL2023)
    mkdir -p /home/ec2-user/.aws
    cat > /home/ec2-user/.aws/config <<EOF
[default]
region = $REGION
output = json
EOF
    chown -R ec2-user:ec2-user /home/ec2-user/.aws
fi

# Configure CloudWatch Agent
echo "[INFO] Configuring CloudWatch Agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "totalcpu": true
            },
            "disk": {
                "measurement": [
                    "used_percent",
                    "used",
                    "total"
                ],
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent",
                    "mem_total",
                    "mem_used"
                ]
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/$ENVIRONMENT/system",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/$ENVIRONMENT/security",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# System configurations
echo "[INFO] Setting up system configurations..."

# Set timezone
timedatectl set-timezone Asia/Jakarta

# Configure sysctl
cat > /etc/sysctl.d/99-custom.conf <<EOF
# Network performance
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF

sysctl -p /etc/sysctl.d/99-custom.conf

# Install Docker based on OS
echo "[INFO] Installing Docker..."
if [[ "$OS" == "Ubuntu" ]]; then
    $PKG_INSTALL ca-certificates gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    $PKG_MANAGER update
    $PKG_INSTALL docker-ce docker-ce-cli containerd.io
    usermod -aG docker ubuntu
else
    $PKG_INSTALL docker
    usermod -aG docker ec2-user
fi

# Install Docker Compose v2
echo "[INFO] Installing Docker Compose..."
mkdir -p /usr/local/lib/docker/cli-plugins/
curl -SL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create instance metadata file
echo "[INFO] Creating instance metadata file..."
cat > /etc/instance-tags <<EOF
ENVIRONMENT=$ENVIRONMENT
HOSTNAME=$HOSTNAME
REGION=$REGION
OS=$OS
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Verify installations
echo "[INFO] Verifying installations..."
aws --version
docker --version
docker compose version

echo "[END] UserData Script - $(date)"
