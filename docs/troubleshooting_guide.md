# Wazuh Indexer Troubleshooting Guide

## Overview
This guide provides comprehensive troubleshooting steps for common Wazuh Indexer (OpenSearch) issues that may occur during deployment or operation.

## Common Issues and Solutions

### 1. Service Fails to Start (Exit Code 1)

**Symptoms:**
- `systemctl status wazuh-indexer` shows "failed (Result: exit-code)"
- Service exits with status code 1
- No detailed error information in systemd logs

**Causes:**
- Configuration file syntax errors
- Missing or incorrect file permissions
- Insufficient system resources (memory, disk space)
- SSL configuration issues
- JVM heap size too large
- Missing Java installation

**Solutions:**

#### Quick Fix (Recommended First Step)
```bash
# Run the automated fix script
sudo ./scripts/fix_indexer.sh
```

#### Manual Fix Steps
1. **Stop the service:**
   ```bash
   sudo systemctl stop wazuh-indexer
   ```

2. **Check configuration files:**
   ```bash
   sudo cat /etc/wazuh-indexer/opensearch.yml
   sudo cat /etc/wazuh-indexer/jvm.options
   ```

3. **Verify file permissions:**
   ```bash
   sudo ls -la /etc/wazuh-indexer/
   sudo ls -la /var/lib/wazuh-indexer/
   sudo ls -la /var/log/wazuh-indexer/
   ```

4. **Check Java installation:**
   ```bash
   java -version
   echo $JAVA_HOME
   ```

5. **Review detailed logs:**
   ```bash
   sudo journalctl -u wazuh-indexer -n 50 --no-pager
   sudo tail -f /var/log/wazuh-indexer/wazuh-cluster.log
   ```

### 2. SSL Configuration Issues

**Symptoms:**
- Service fails to start with SSL-related errors
- Certificate file not found errors
- SSL handshake failures

**Solutions:**

#### Option A: Disable SSL (Quick Fix)
```bash
# Edit the configuration file
sudo nano /etc/wazuh-indexer/opensearch.yml

# Comment out or set to false:
# plugins.security.ssl.http.enabled: false
# plugins.security.ssl.transport.enabled: false
```

#### Option B: Fix SSL Configuration
1. **Verify certificate files exist:**
   ```bash
   sudo ls -la /etc/wazuh-indexer/certs/
   ```

2. **Check certificate permissions:**
   ```bash
   sudo chown wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs/*
   sudo chmod 600 /etc/wazuh-indexer/certs/*
   ```

3. **Update configuration with correct paths:**
   ```yaml
   plugins.security.ssl.http.enabled: true
   plugins.security.ssl.transport.enabled: true
   plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/wazuh-1.pem
   plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/wazuh-1-key.pem
   plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/ca.crt
   ```

### 3. Memory and Resource Issues

**Symptoms:**
- Out of Memory (OOM) errors
- Service starts but crashes after a few minutes
- High memory usage warnings

**Solutions:**

1. **Reduce JVM heap size:**
   ```bash
   # Edit JVM options
   sudo nano /etc/wazuh-indexer/jvm.options
   
   # Change from:
   # -Xms1g
   # -Xmx1g
   # To:
   -Xms512m
   -Xmx512m
   ```

2. **Check system memory:**
   ```bash
   free -h
   ```

3. **Set appropriate limits:**
   ```bash
   # Edit limits.conf
   sudo nano /etc/security/limits.conf
   
   # Add:
   wazuh-indexer soft nofile 65535
   wazuh-indexer hard nofile 65535
   wazuh-indexer soft nproc 4096
   wazuh-indexer hard nproc 4096
   ```

### 4. Port Conflicts

**Symptoms:**
- Service fails to bind to ports 9200 or 9300
- "Address already in use" errors

**Solutions:**

1. **Check port usage:**
   ```bash
   sudo netstat -tuln | grep -E ":9200|:9300"
   sudo ss -tuln | grep -E ":9200|:9300"
   ```

2. **Kill conflicting processes:**
   ```bash
   # Find process using port 9200
   sudo lsof -i :9200
   
   # Kill the process (replace PID with actual process ID)
   sudo kill -9 <PID>
   ```

3. **Change ports if needed:**
   ```yaml
   # In opensearch.yml
   http.port: 9201
   transport.port: 9301
   ```

### 5. File Permission Issues

**Symptoms:**
- "Permission denied" errors
- Service cannot read configuration files
- Cannot write to data or log directories

**Solutions:**

1. **Fix ownership:**
   ```bash
   sudo chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/
   sudo chown -R wazuh-indexer:wazuh-indexer /var/lib/wazuh-indexer/
   sudo chown -R wazuh-indexer:wazuh-indexer /var/log/wazuh-indexer/
   ```

2. **Fix permissions:**
   ```bash
   sudo chmod -R 640 /etc/wazuh-indexer/
   sudo chmod 755 /etc/wazuh-indexer/
   sudo chmod 755 /var/lib/wazuh-indexer/
   sudo chmod 755 /var/log/wazuh-indexer/
   ```

### 6. Java Installation Issues

**Symptoms:**
- "Java not found" errors
- Wrong Java version
- JAVA_HOME not set

**Solutions:**

1. **Install OpenJDK 17:**
   ```bash
   sudo apt update
   sudo apt install -y openjdk-17-jdk
   ```

2. **Set JAVA_HOME:**
   ```bash
   echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
   export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
   ```

3. **Verify installation:**
   ```bash
   java -version
   echo $JAVA_HOME
   ```

## Diagnostic Commands

### System Information
```bash
# System resources
free -h
df -h
nproc

# Service status
sudo systemctl status wazuh-indexer
sudo journalctl -u wazuh-indexer --no-pager -l

# Process information
ps aux | grep wazuh-indexer
sudo lsof -i :9200
```

### Configuration Validation
```bash
# Check configuration syntax
sudo -u wazuh-indexer /usr/share/wazuh-indexer/bin/opensearch --help

# Validate configuration
sudo -u wazuh-indexer /usr/share/wazuh-indexer/bin/opensearch --config-test-mode

# Check file permissions
sudo ls -la /etc/wazuh-indexer/
sudo ls -la /var/lib/wazuh-indexer/
sudo ls -la /var/log/wazuh-indexer/
```

### Log Analysis
```bash
# Systemd logs
sudo journalctl -u wazuh-indexer -f

# Application logs
sudo tail -f /var/log/wazuh-indexer/wazuh-cluster.log
sudo tail -f /var/log/wazuh-indexer/wazuh-cluster.log

# System logs
sudo tail -f /var/log/syslog | grep wazuh-indexer
```

## Automated Troubleshooting

### Run the Troubleshooting Script
```bash
sudo ./scripts/troubleshoot_indexer.sh
```

This script will:
- Check system resources
- Verify Java installation
- Check service status
- Validate configuration files
- Check file permissions
- Analyze logs
- Provide specific recommendations

### Run the Quick Fix Script
```bash
sudo ./scripts/fix_indexer.sh
```

This script will:
- Stop the service
- Fix configuration files
- Set proper permissions
- Create necessary directories
- Set system limits
- Restart the service

## Prevention Tips

1. **Resource Planning:**
   - Ensure adequate memory (minimum 2GB RAM)
   - Allocate sufficient disk space
   - Use conservative JVM heap sizes

2. **Configuration Management:**
   - Test configurations before deployment
   - Use version control for configuration files
   - Implement configuration validation

3. **Monitoring:**
   - Set up log monitoring
   - Monitor system resources
   - Use health check endpoints

4. **Security:**
   - Start with SSL disabled for testing
   - Gradually enable security features
   - Use proper certificate management

## Getting Help

If the above solutions don't resolve your issue:

1. **Collect diagnostic information:**
   ```bash
   sudo ./scripts/troubleshoot_indexer.sh > troubleshooting_output.txt 2>&1
   ```

2. **Check official documentation:**
   - [Wazuh Documentation](https://documentation.wazuh.com/)
   - [OpenSearch Documentation](https://opensearch.org/docs/)

3. **Review logs thoroughly:**
   - Systemd logs
   - Application logs
   - System logs

4. **Verify system requirements:**
   - Operating system compatibility
   - Java version requirements
   - Hardware specifications

## Quick Reference

| Issue | Quick Fix | Detailed Fix |
|-------|-----------|--------------|
| Service won't start | `sudo ./scripts/fix_indexer.sh` | Check logs and configuration |
| SSL errors | Disable SSL in config | Fix certificate paths |
| Memory issues | Reduce heap size to 512m | Check system resources |
| Permission errors | Fix ownership and permissions | Verify file structure |
| Port conflicts | Check port usage | Kill conflicting processes |
| Java issues | Install OpenJDK 17 | Set JAVA_HOME |

Remember to always backup your configuration files before making changes!
