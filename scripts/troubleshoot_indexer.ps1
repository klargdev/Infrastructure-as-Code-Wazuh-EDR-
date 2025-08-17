# Wazuh Indexer Troubleshooting Script for Windows
# This script helps diagnose and fix common Wazuh Indexer issues

param(
    [switch]$Fix,
    [switch]$Verbose
)

Write-Host "=== Wazuh Indexer Troubleshooting Script for Windows ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Function to print colored output
function Write-Status {
    param(
        [string]$Status,
        [string]$Message
    )
    
    switch ($Status) {
        "INFO" { Write-Host "[INFO] $Message" -ForegroundColor Green }
        "WARNING" { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[ERROR] $Message" -ForegroundColor Red }
    }
}

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Status "ERROR" "This script must be run as Administrator"
    exit 1
}

Write-Status "INFO" "Starting Wazuh Indexer troubleshooting..."

# 1. Check system resources
Write-Host ""
Write-Status "INFO" "=== System Resource Check ==="
Write-Host "Memory:" -ForegroundColor White
Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | Format-Table -AutoSize

Write-Host "Disk space:" -ForegroundColor White
Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | Select-Object DeviceID, Size, FreeSpace | Format-Table -AutoSize

Write-Host "CPU info:" -ForegroundColor White
Get-WmiObject -Class Win32_Processor | Select-Object Name, NumberOfCores | Format-Table -AutoSize

# 2. Check if Wazuh Indexer service exists
Write-Host ""
Write-Status "INFO" "=== Wazuh Indexer Service Check ==="
$service = Get-Service -Name "wazuh-indexer" -ErrorAction SilentlyContinue

if ($service) {
    Write-Status "INFO" "Wazuh Indexer service found"
    Write-Host "Service Status: $($service.Status)" -ForegroundColor White
    Write-Host "Service Name: $($service.Name)" -ForegroundColor White
    Write-Host "Display Name: $($service.DisplayName)" -ForegroundColor White
    
    if ($service.Status -eq "Running") {
        Write-Status "INFO" "Service is currently running"
    } else {
        Write-Status "WARNING" "Service is not running (Status: $($service.Status))"
    }
} else {
    Write-Status "ERROR" "Wazuh Indexer service not found"
    Write-Host "Available services containing 'wazuh':" -ForegroundColor White
    Get-Service | Where-Object {$_.Name -like "*wazuh*"} | Select-Object Name, Status, DisplayName | Format-Table -AutoSize
}

# 3. Check if ports are in use
Write-Host ""
Write-Status "INFO" "=== Port Availability Check ==="
$ports = @(9200, 9300)

foreach ($port in $ports) {
    $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    
    if ($connection) {
        Write-Status "WARNING" "Port $port is already in use"
        $connection | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess | Format-Table -AutoSize
        
        # Get process information
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "Process using port $port:" -ForegroundColor White
            $process | Select-Object Id, ProcessName, Path | Format-Table -AutoSize
        }
    } else {
        Write-Status "INFO" "Port $port is available"
    }
}

# 4. Check for common configuration files
Write-Host ""
Write-Status "INFO" "=== Configuration File Check ==="
$configPaths = @(
    "C:\Program Files\Wazuh\Wazuh Indexer\config\opensearch.yml",
    "C:\Program Files\Wazuh\Wazuh Indexer\config\jvm.options",
    "C:\Program Files\Wazuh\Wazuh Indexer\config\log4j2.properties"
)

foreach ($configPath in $configPaths) {
    if (Test-Path $configPath) {
        Write-Status "INFO" "Found: $configPath"
        $fileInfo = Get-Item $configPath
        Write-Host "Size: $($fileInfo.Length) bytes" -ForegroundColor White
        Write-Host "Last Modified: $($fileInfo.LastWriteTime)" -ForegroundColor White
    } else {
        Write-Status "ERROR" "Missing: $configPath"
    }
}

# 5. Check for Java installation
Write-Host ""
Write-Status "INFO" "=== Java Installation Check ==="
$javaPath = Get-Command java -ErrorAction SilentlyContinue

if ($javaPath) {
    Write-Status "INFO" "Java found at: $($javaPath.Source)"
    
    try {
        $javaVersion = & java -version 2>&1 | Select-String "version"
        Write-Host "Java Version: $javaVersion" -ForegroundColor White
    } catch {
        Write-Status "WARNING" "Could not determine Java version"
    }
    
    # Check JAVA_HOME environment variable
    $javaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    if ($javaHome) {
        Write-Status "INFO" "JAVA_HOME: $javaHome"
    } else {
        Write-Status "WARNING" "JAVA_HOME not set"
    }
} else {
    Write-Status "ERROR" "Java is not installed or not in PATH"
}

# 6. Check for common issues and provide fixes
Write-Host ""
Write-Status "INFO" "=== Common Issues and Fixes ==="

# Check if service exists but won't start
if ($service -and $service.Status -ne "Running") {
    Write-Status "WARNING" "Service exists but is not running"
    
    # Try to start the service
    if ($Fix) {
        Write-Status "INFO" "Attempting to start the service..."
        try {
            Start-Service -Name "wazuh-indexer" -ErrorAction Stop
            Write-Status "INFO" "Service started successfully"
        } catch {
            Write-Status "ERROR" "Failed to start service: $($_.Exception.Message)"
        }
    } else {
        Write-Status "INFO" "Use -Fix parameter to attempt automatic service start"
    }
}

# Check if ports are blocked by firewall
Write-Host ""
Write-Status "INFO" "=== Firewall Check ==="
$firewallRules = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*wazuh*" -or $_.DisplayName -like "*opensearch*"}

if ($firewallRules) {
    Write-Status "INFO" "Found firewall rules for Wazuh:"
    $firewallRules | Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize
} else {
    Write-Status "WARNING" "No specific firewall rules found for Wazuh"
    Write-Status "INFO" "Consider adding firewall rules for ports 9200 and 9300"
}

# 7. Provide recommendations
Write-Host ""
Write-Status "INFO" "=== Recommendations ==="

if (-not $service) {
    Write-Status "INFO" "1. Install Wazuh Indexer if not already installed"
    Write-Status "INFO" "2. Ensure the service is properly configured"
}

if (-not $javaPath) {
    Write-Status "INFO" "1. Install Java (OpenJDK 17 recommended)"
    Write-Status "INFO" "2. Set JAVA_HOME environment variable"
}

if ($service -and $service.Status -ne "Running") {
    Write-Status "INFO" "1. Check Windows Event Viewer for service errors"
    Write-Status "INFO" "2. Verify configuration files are correct"
    Write-Status "INFO" "3. Check if required ports are available"
}

# 8. Show Windows Event Log entries
Write-Host ""
Write-Status "INFO" "=== Windows Event Log Check ==="
try {
    $events = Get-WinEvent -LogName "Application" -MaxEvents 10 | Where-Object {$_.Message -like "*wazuh*" -or $_.Message -like "*opensearch*"}
    
    if ($events) {
        Write-Status "INFO" "Found recent Wazuh-related events:"
        $events | Select-Object TimeCreated, LevelDisplayName, Message | Format-Table -AutoSize
    } else {
        Write-Status "INFO" "No recent Wazuh-related events found in Application log"
    }
} catch {
    Write-Status "WARNING" "Could not access Windows Event Log: $($_.Exception.Message)"
}

Write-Host ""
Write-Status "INFO" "Troubleshooting complete!"
Write-Host "For more detailed information, check:" -ForegroundColor White
Write-Host "  - Windows Event Viewer > Application" -ForegroundColor White
Write-Host "  - Wazuh Indexer logs (if service is running)" -ForegroundColor White
Write-Host "  - System logs for any related errors" -ForegroundColor White

if ($Fix) {
    Write-Host ""
    Write-Status "INFO" "Fix mode completed. Check service status:"
    Get-Service -Name "wazuh-indexer" -ErrorAction SilentlyContinue | Select-Object Name, Status, DisplayName | Format-Table -AutoSize
}
