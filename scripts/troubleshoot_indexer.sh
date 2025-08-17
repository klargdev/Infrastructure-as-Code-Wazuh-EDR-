#!/bin/bash

# Wazuh Indexer Troubleshooting Script
# This script helps diagnose and fix common Wazuh Indexer issues

set -e

echo "=== Wazuh Indexer Troubleshooting Script ==="
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

print_status "INFO" "Starting Wazuh Indexer troubleshooting..."

# 1. Check system resources
echo ""
print_status "INFO" "=== System Resource Check ==="
echo "Memory:"
free -h
echo ""
echo "Disk space:"
df -h /
echo ""
echo "CPU info:"
nproc
echo ""

# 2. Check Java installation
echo ""
print_status "INFO" "=== Java Installation Check ==="
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n 1)
    print_status "INFO" "Java found: $java_version"
    
    # Check JAVA_HOME
    if [[ -n "$JAVA_HOME" ]]; then
        print_status "INFO" "JAVA_HOME: $JAVA_HOME"
    else
        print_status "WARNING" "JAVA_HOME not set"
    fi
    
    # Check if OpenJDK 17 is installed
    if dpkg -l | grep -q "openjdk-17"; then
        print_status "INFO" "OpenJDK 17 is installed"
    else
        print_status "ERROR" "OpenJDK 17 is not installed"
    fi
else
    print_status "ERROR" "Java is not installed"
fi

# 3. Check Wazuh Indexer service status
echo ""
print_status "INFO" "=== Wazuh Indexer Service Status ==="
if systemctl is-active --quiet wazuh-indexer; then
    print_status "INFO" "Wazuh Indexer service is running"
else
    print_status "ERROR" "Wazuh Indexer service is not running"
    echo "Service status:"
    systemctl status wazuh-indexer --no-pager -l
fi

# 4. Check configuration files
echo ""
print_status "INFO" "=== Configuration File Check ==="
config_files=(
    "/etc/wazuh-indexer/opensearch.yml"
    "/etc/wazuh-indexer/jvm.options"
    "/etc/wazuh-indexer/log4j2.properties"
)

for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
        print_status "INFO" "Found: $config_file"
        echo "Permissions: $(ls -la "$config_file")"
        
        # Check if file is readable by wazuh-indexer user
        if sudo -u wazuh-indexer test -r "$config_file"; then
            print_status "INFO" "File is readable by wazuh-indexer user"
        else
            print_status "ERROR" "File is NOT readable by wazuh-indexer user"
        fi
    else
        print_status "ERROR" "Missing: $config_file"
    fi
    echo ""
done

# 5. Check directories and permissions
echo ""
print_status "INFO" "=== Directory and Permission Check ==="
directories=(
    "/var/lib/wazuh-indexer"
    "/var/log/wazuh-indexer"
    "/etc/wazuh-indexer"
    "/etc/wazuh-indexer/certs"
)

for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        print_status "INFO" "Found: $dir"
        echo "Permissions: $(ls -ld "$dir")"
        echo "Owner: $(stat -c '%U:%G' "$dir")"
    else
        print_status "ERROR" "Missing: $dir"
    fi
    echo ""
done

# 6. Check system limits
echo ""
print_status "INFO" "=== System Limits Check ==="
echo "Current limits for wazuh-indexer user:"
sudo -u wazuh-indexer ulimit -a
echo ""

# Check /etc/security/limits.conf
if grep -q "wazuh-indexer" /etc/security/limits.conf; then
    print_status "INFO" "Wazuh Indexer limits found in /etc/security/limits.conf"
    grep "wazuh-indexer" /etc/security/limits.conf
else
    print_status "WARNING" "No Wazuh Indexer limits found in /etc/security/limits.conf"
fi

# 7. Check recent logs
echo ""
print_status "INFO" "=== Recent Log Analysis ==="
if [[ -f "/var/log/wazuh-indexer/wazuh-cluster.log" ]]; then
    print_status "INFO" "Last 20 lines of wazuh-cluster.log:"
    tail -n 20 /var/log/wazuh-indexer/wazuh-cluster.log
else
    print_status "WARNING" "wazuh-cluster.log not found"
fi

echo ""
if [[ -f "/var/log/wazuh-indexer/wazuh-cluster.log" ]]; then
    print_status "INFO" "Last 20 lines of wazuh-cluster.log:"
    tail -n 20 /var/log/wazuh-indexer/wazuh-cluster.log
else
    print_status "WARNING" "wazuh-cluster.log not found"
fi

# 8. Check systemd logs
echo ""
print_status "INFO" "=== Systemd Log Analysis ==="
echo "Last 20 lines of wazuh-indexer service logs:"
journalctl -u wazuh-indexer --no-pager -l -n 20

# 9. Check for common issues and provide fixes
echo ""
print_status "INFO" "=== Common Issues and Fixes ==="

# Check if SSL is enabled but certificates are missing
if grep -q "plugins.security.ssl.http.enabled: true" /etc/wazuh-indexer/opensearch.yml 2>/dev/null; then
    if [[ ! -f "/etc/wazuh-indexer/certs/wazuh-1.pem" ]]; then
        print_status "ERROR" "SSL is enabled but certificates are missing"
        print_status "INFO" "Fix: Either disable SSL or provide proper certificates"
    fi
fi

# Check JVM heap size
if [[ -f "/etc/wazuh-indexer/jvm.options" ]]; then
    heap_size=$(grep "^[^-]*Xmx" /etc/wazuh-indexer/jvm.options | head -1 | sed 's/.*Xmx//')
    if [[ -n "$heap_size" ]]; then
        print_status "INFO" "Current JVM heap size: $heap_size"
        
        # Convert to MB for comparison
        heap_mb=$(echo "$heap_size" | sed 's/[^0-9]//g')
        if [[ "$heap_size" == *"g"* ]]; then
            heap_mb=$((heap_mb * 1024))
        fi
        
        total_mem=$(free -m | awk 'NR==2{print $2}')
        if [[ $heap_mb -gt $((total_mem / 2)) ]]; then
            print_status "WARNING" "Heap size ($heap_mb MB) is more than 50% of total memory ($total_mem MB)"
            print_status "INFO" "Consider reducing heap size to prevent OOM issues"
        fi
    fi
fi

# 10. Provide restart commands
echo ""
print_status "INFO" "=== Recommended Actions ==="
echo "If you want to restart the service, use:"
echo "  sudo systemctl restart wazuh-indexer"
echo ""
echo "To view real-time logs:"
echo "  sudo journalctl -u wazuh-indexer -f"
echo ""
echo "To check service status:"
echo "  sudo systemctl status wazuh-indexer"
echo ""

# 11. Check if port is in use
echo ""
print_status "INFO" "=== Port Availability Check ==="
if netstat -tuln | grep -q ":9200 "; then
    print_status "WARNING" "Port 9200 is already in use"
    netstat -tuln | grep ":9200 "
else
    print_status "INFO" "Port 9200 is available"
fi

if netstat -tuln | grep -q ":9300 "; then
    print_status "WARNING" "Port 9300 is already in use"
    netstat -tuln | grep ":9300 "
else
    print_status "INFO" "Port 9300 is available"
fi

echo ""
print_status "INFO" "Troubleshooting complete. Check the output above for issues."
echo "For more detailed logs, check:"
echo "  - /var/log/wazuh-indexer/"
echo "  - journalctl -u wazuh-indexer"
echo "  - systemctl status wazuh-indexer"
