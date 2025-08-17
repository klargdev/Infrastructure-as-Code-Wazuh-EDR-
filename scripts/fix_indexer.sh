#!/bin/bash

# Wazuh Indexer Quick Fix Script
# This script automatically fixes common Wazuh Indexer issues

set -e

echo "=== Wazuh Indexer Quick Fix Script ==="
echo "Timestamp: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_status "ERROR" "This script must be run as root (use sudo)"
   exit 1
fi

print_status "INFO" "Starting Wazuh Indexer quick fix..."

# 1. Stop the service first
print_status "INFO" "Stopping Wazuh Indexer service..."
systemctl stop wazuh-indexer || true

# 2. Fix configuration files
print_status "INFO" "Fixing configuration files..."

# Create backup of current config
if [[ -f "/etc/wazuh-indexer/opensearch.yml" ]]; then
    cp /etc/wazuh-indexer/opensearch.yml /etc/wazuh-indexer/opensearch.yml.backup.$(date +%Y%m%d_%H%M%S)
    print_status "INFO" "Backup created: opensearch.yml.backup"
fi

# Create a minimal working configuration
cat > /etc/wazuh-indexer/opensearch.yml << 'EOF'
# OpenSearch configuration for Wazuh Indexer
cluster.name: wazuh-cluster
node.name: wazuh-indexer-1

# Network settings
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300

# Security settings - Disabled for initial deployment
plugins.security.ssl.http.enabled: false
plugins.security.ssl.transport.enabled: false
plugins.security.allow_unsafe_democertificates: true
plugins.security.allow_default_init_securityindex: true

# Performance settings
bootstrap.memory_lock: false
path.data: /var/lib/wazuh-indexer
path.logs: /var/log/wazuh-indexer
path.config: /etc/wazuh-indexer

# Discovery settings
discovery.type: single-node

# Performance tuning
indices.memory.index_buffer_size: 30%
indices.queries.cache.size: 10%
indices.fielddata.cache.size: 10%
EOF

# Fix JVM options with conservative settings
cat > /etc/wazuh-indexer/jvm.options << 'EOF'
# JVM options for Wazuh Indexer
-Xms512m
-Xmx512m

# Garbage collection
-XX:+UseG1GC
-XX:G1ReservePercent=25
-XX:InitiatingHeapOccupancyPercent=75
-XX:MaxGCPauseMillis=200

# Performance tuning
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-server
-Djava.awt.headless=true
-Dfile.encoding=UTF-8
-Djna.nosys=true

# Security
-Dlog4j2.formatMsgNoLookups=true
-Dlog4j2.disable.jmx=true

# Network settings
-Dio.netty.allocator.type=pooled
-Dio.netty.allocator.numDirectArenas=0
EOF

# 3. Fix permissions
print_status "INFO" "Fixing file permissions..."
chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/
chmod -R 640 /etc/wazuh-indexer/
chmod 755 /etc/wazuh-indexer/

# 4. Create necessary directories with proper permissions
print_status "INFO" "Creating necessary directories..."
mkdir -p /var/lib/wazuh-indexer
mkdir -p /var/log/wazuh-indexer
mkdir -p /etc/wazuh-indexer/certs

chown -R wazuh-indexer:wazuh-indexer /var/lib/wazuh-indexer/
chown -R wazuh-indexer:wazuh-indexer /var/log/wazuh-indexer/
chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs/

chmod 755 /var/lib/wazuh-indexer/
chmod 755 /var/log/wazuh-indexer/
chmod 755 /etc/wazuh-indexer/certs/

# 5. Fix system limits
print_status "INFO" "Setting system limits..."
cat >> /etc/security/limits.conf << 'EOF'

# Wazuh Indexer limits
wazuh-indexer soft nofile 65535
wazuh-indexer hard nofile 65535
wazuh-indexer soft nproc 4096
wazuh-indexer hard nproc 4096
EOF

# 6. Check Java installation
print_status "INFO" "Checking Java installation..."
if ! command -v java &> /dev/null; then
    print_status "ERROR" "Java is not installed. Installing OpenJDK 17..."
    apt update
    apt install -y openjdk-17-jdk
fi

# Set JAVA_HOME if not set
if [[ -z "$JAVA_HOME" ]]; then
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
    print_status "INFO" "JAVA_HOME set to: $JAVA_HOME"
fi

# 7. Reload systemd and restart service
print_status "INFO" "Reloading systemd and starting service..."
systemctl daemon-reload

# 8. Start the service
print_status "INFO" "Starting Wazuh Indexer service..."
if systemctl start wazuh-indexer; then
    print_status "INFO" "Wazuh Indexer service started successfully!"
    
    # Wait a moment and check status
    sleep 5
    if systemctl is-active --quiet wazuh-indexer; then
        print_status "INFO" "Service is running and healthy!"
        
        # Check if port is listening
        if netstat -tuln | grep -q ":9200 "; then
            print_status "INFO" "Port 9200 is listening - service is accessible!"
        else
            print_status "WARNING" "Port 9200 is not listening yet - service may still be starting"
        fi
    else
        print_status "ERROR" "Service failed to start properly"
        systemctl status wazuh-indexer --no-pager -l
    fi
else
    print_status "ERROR" "Failed to start Wazuh Indexer service"
    systemctl status wazuh-indexer --no-pager -l
fi

# 9. Show final status
echo ""
print_status "INFO" "=== Final Status ==="
systemctl status wazuh-indexer --no-pager -l

echo ""
print_status "INFO" "Quick fix completed!"
echo "If the service is still not working, run the troubleshooting script:"
echo "  sudo ./scripts/troubleshoot_indexer.sh"
echo ""
echo "To view real-time logs:"
echo "  sudo journalctl -u wazuh-indexer -f"
