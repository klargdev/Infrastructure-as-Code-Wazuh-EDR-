#!/bin/bash

# Deep Troubleshooting Script for Wazuh Indexer Java Startup Issues
# This script addresses the specific Java fatal exception errors

set -e

echo "=== Deep Troubleshooting Script for Wazuh Indexer ==="
echo "Timestamp: $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        "DEBUG")
            echo -e "${BLUE}[DEBUG]${NC} $message"
            ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_status "ERROR" "This script must be run as root (use sudo)"
   exit 1
fi

print_status "INFO" "Starting deep troubleshooting for Wazuh Indexer Java issues..."

# 1. Comprehensive Java Analysis
echo ""
print_status "INFO" "=== Java Installation Deep Analysis ==="

# Check Java installation
if command -v java &> /dev/null; then
    java_version=$(java -version 2>&1 | head -n 1)
    print_status "INFO" "Java found: $java_version"
    
    # Check Java version number
    java_version_number=$(java -version 2>&1 | grep -i version | sed 's/.*version "\([^"]*\)".*/\1/')
    print_status "INFO" "Java version number: $java_version_number"
    
    # Check if it's OpenJDK 17
    if echo "$java_version" | grep -q "openjdk.*17"; then
        print_status "INFO" "✓ OpenJDK 17 detected - compatible with Wazuh Indexer"
    elif echo "$java_version" | grep -q "openjdk.*11"; then
        print_status "WARNING" "OpenJDK 11 detected - may work but 17 is recommended"
    else
        print_status "ERROR" "Unsupported Java version - Wazuh Indexer requires OpenJDK 11 or 17"
    fi
    
    # Check JAVA_HOME
    if [[ -n "$JAVA_HOME" ]]; then
        print_status "INFO" "JAVA_HOME: $JAVA_HOME"
        if [[ -d "$JAVA_HOME" ]]; then
            print_status "INFO" "✓ JAVA_HOME directory exists"
        else
            print_status "ERROR" "✗ JAVA_HOME directory does not exist"
        fi
    else
        print_status "WARNING" "JAVA_HOME not set"
    fi
    
    # Check Java binary location
    java_bin=$(which java)
    print_status "INFO" "Java binary location: $java_bin"
    
    # Check Java binary permissions
    if [[ -x "$java_bin" ]]; then
        print_status "INFO" "✓ Java binary is executable"
    else
        print_status "ERROR" "✗ Java binary is not executable"
    fi
    
    # Check Java binary owner
    java_owner=$(stat -c '%U:%G' "$java_bin")
    print_status "INFO" "Java binary owner: $java_owner"
    
else
    print_status "ERROR" "Java is not installed"
    print_status "INFO" "Installing OpenJDK 17..."
    apt update
    apt install -y openjdk-17-jdk
fi

# 2. System Resource Analysis
echo ""
print_status "INFO" "=== System Resource Deep Analysis ==="

# Memory analysis
echo "Memory Information:"
free -h
echo ""

total_mem=$(free -m | awk 'NR==2{print $2}')
available_mem=$(free -m | awk 'NR==2{print $7}')
print_status "INFO" "Total Memory: ${total_mem}MB"
print_status "INFO" "Available Memory: ${available_mem}MB"

if [[ $total_mem -lt 2048 ]]; then
    print_status "ERROR" "✗ Insufficient memory: ${total_mem}MB (minimum 2GB required)"
elif [[ $available_mem -lt 1024 ]]; then
    print_status "WARNING" "⚠ Low available memory: ${available_mem}MB (recommend at least 1GB free)"
else
    print_status "INFO" "✓ Sufficient memory available"
fi

# Disk space analysis
echo ""
echo "Disk Space Information:"
df -h /
echo ""

disk_free=$(df -m / | awk 'NR==2{print $4}')
if [[ $disk_free -lt 5120 ]]; then
    print_status "WARNING" "⚠ Low disk space: ${disk_free}MB free (recommend at least 5GB)"
else
    print_status "INFO" "✓ Sufficient disk space available"
fi

# 3. Kernel Parameter Analysis
echo ""
print_status "INFO" "=== Kernel Parameter Analysis ==="

# Check vm.max_map_count
current_max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo "UNKNOWN")
print_status "INFO" "Current vm.max_map_count: $current_max_map_count"

if [[ "$current_max_map_count" == "UNKNOWN" ]]; then
    print_status "ERROR" "✗ Cannot read vm.max_map_count"
elif [[ $current_max_map_count -lt 262144 ]]; then
    print_status "ERROR" "✗ vm.max_map_count too low: $current_max_map_count (minimum 262144 required)"
    print_status "INFO" "Fixing vm.max_map_count..."
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    print_status "INFO" "✓ vm.max_map_count updated to 262144"
else
    print_status "INFO" "✓ vm.max_map_count is sufficient: $current_max_map_count"
fi

# Check other important kernel parameters
echo ""
print_status "INFO" "Other important kernel parameters:"
sysctl vm.swappiness vm.dirty_ratio vm.dirty_background_ratio 2>/dev/null || print_status "WARNING" "Cannot read some kernel parameters"

# 4. Wazuh Indexer Configuration Analysis
echo ""
print_status "INFO" "=== Wazuh Indexer Configuration Analysis ==="

# Check if service exists
if systemctl list-unit-files | grep -q "wazuh-indexer"; then
    print_status "INFO" "✓ Wazuh Indexer service exists"
    
    # Check service status
    service_status=$(systemctl is-active wazuh-indexer 2>/dev/null || echo "inactive")
    print_status "INFO" "Service status: $service_status"
    
    if [[ "$service_status" == "active" ]]; then
        print_status "INFO" "✓ Service is running"
    else
        print_status "WARNING" "⚠ Service is not running: $service_status"
    fi
else
    print_status "ERROR" "✗ Wazuh Indexer service not found"
fi

# Check configuration files
config_files=(
    "/etc/wazuh-indexer/opensearch.yml"
    "/etc/wazuh-indexer/jvm.options"
)

for config_file in "${config_files[@]}"; do
    if [[ -f "$config_file" ]]; then
        print_status "INFO" "✓ Found: $config_file"
        
        # Check file permissions
        file_perms=$(ls -la "$config_file" | awk '{print $1, $3, $4}')
        print_status "DEBUG" "File permissions: $file_perms"
        
        # Check if readable by wazuh-indexer user
        if sudo -u wazuh-indexer test -r "$config_file"; then
            print_status "INFO" "✓ File is readable by wazuh-indexer user"
        else
            print_status "ERROR" "✗ File is NOT readable by wazuh-indexer user"
        fi
        
        # Show file size
        file_size=$(stat -c '%s' "$config_file")
        print_status "DEBUG" "File size: ${file_size} bytes"
        
    else
        print_status "ERROR" "✗ Missing: $config_file"
    fi
done

# 5. Manual Configuration Test
echo ""
print_status "INFO" "=== Manual Configuration Test ==="

# Test configuration syntax
print_status "INFO" "Testing OpenSearch configuration syntax..."
if [[ -f "/usr/share/wazuh-indexer/bin/opensearch" ]]; then
    config_test=$(sudo -u wazuh-indexer /usr/share/wazuh-indexer/bin/opensearch --config-test-mode 2>&1)
    if [[ $? -eq 0 ]]; then
        print_status "INFO" "✓ Configuration syntax is valid"
    else
        print_status "ERROR" "✗ Configuration syntax error:"
        echo "$config_test"
    fi
else
    print_status "WARNING" "OpenSearch binary not found, skipping config test"
fi

# 6. Manual Startup Test
echo ""
print_status "INFO" "=== Manual Startup Test ==="

# Stop service if running
if systemctl is-active --quiet wazuh-indexer; then
    print_status "INFO" "Stopping Wazuh Indexer service for testing..."
    systemctl stop wazuh-indexer
    sleep 2
fi

# Test manual startup
print_status "INFO" "Testing manual startup (will timeout after 15 seconds)..."
timeout 15s sudo -u wazuh-indexer /usr/share/wazuh-indexer/bin/opensearch -d -p /tmp/opensearch-test.pid 2>&1 &
startup_pid=$!

# Wait a moment and check if process started
sleep 5
if ps -p $startup_pid > /dev/null; then
    print_status "INFO" "✓ Manual startup successful (PID: $startup_pid)"
    
    # Check if port is listening
    if netstat -tuln | grep -q ":9200 "; then
        print_status "INFO" "✓ Port 9200 is listening"
    else
        print_status "WARNING" "⚠ Port 9200 is not listening yet"
    fi
    
    # Kill test process
    kill $startup_pid 2>/dev/null || true
    rm -f /tmp/opensearch-test.pid
    
else
    print_status "ERROR" "✗ Manual startup failed"
fi

# 7. Log Analysis
echo ""
print_status "INFO" "=== Log Analysis ==="

# Check systemd logs
print_status "INFO" "Recent systemd logs for wazuh-indexer:"
journalctl -u wazuh-indexer --no-pager -l -n 20 2>/dev/null || print_status "WARNING" "No systemd logs found"

# Check application logs
log_files=(
    "/var/log/wazuh-indexer/wazuh-cluster.log"
    "/var/log/wazuh-indexer/wazuh-indexer.log"
    "/var/log/wazuh-indexer/gc.log"
)

for log_file in "${log_files[@]}"; do
    if [[ -f "$log_file" ]]; then
        print_status "INFO" "Found log file: $log_file"
        print_status "DEBUG" "Last 10 lines:"
        tail -n 10 "$log_file" 2>/dev/null || print_status "WARNING" "Cannot read log file"
        echo ""
    fi
done

# 8. Port Analysis
echo ""
print_status "INFO" "=== Port Analysis ==="

ports=(9200 9300)
for port in "${ports[@]}"; do
    if netstat -tuln | grep -q ":$port "; then
        print_status "WARNING" "⚠ Port $port is already in use:"
        netstat -tuln | grep ":$port "
        
        # Get process information
        process_info=$(lsof -i :$port 2>/dev/null || echo "Cannot get process info")
        print_status "DEBUG" "Process using port $port:"
        echo "$process_info"
    else
        print_status "INFO" "✓ Port $port is available"
    fi
    echo ""
done

# 9. Recommendations
echo ""
print_status "INFO" "=== Recommendations ==="

# Java recommendations
if ! command -v java &> /dev/null; then
    print_status "INFO" "1. Install OpenJDK 17: sudo apt install openjdk-17-jdk"
elif ! java -version 2>&1 | grep -q "openjdk.*1[17]"; then
    print_status "INFO" "1. Upgrade to OpenJDK 17: sudo apt install openjdk-17-jdk"
fi

# Memory recommendations
if [[ $total_mem -lt 2048 ]]; then
    print_status "INFO" "2. Increase system memory to at least 2GB"
fi

# Kernel parameter recommendations
if [[ $current_max_map_count -lt 262144 ]]; then
    print_status "INFO" "3. Set vm.max_map_count: echo 'vm.max_map_count=262144' >> /etc/sysctl.conf"
fi

# Service recommendations
if ! systemctl is-active --quiet wazuh-indexer; then
    print_status "INFO" "4. Try starting service: sudo systemctl start wazuh-indexer"
    print_status "INFO" "5. Check detailed logs: sudo journalctl -u wazuh-indexer -f"
fi

echo ""
print_status "INFO" "Deep troubleshooting complete!"
print_status "INFO" "Next steps:"
print_status "INFO" "1. Address any ERROR items above"
print_status "INFO" "2. Run: sudo systemctl start wazuh-indexer"
print_status "INFO" "3. Monitor logs: sudo journalctl -u wazuh-indexer -f"
print_status "INFO" "4. Test connectivity: curl -X GET 'http://localhost:9200/_cluster/health?pretty'"
