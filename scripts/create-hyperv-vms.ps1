# Hyper-V K3S Worker Node Creation Script
# Run this script as Administrator!

# ============================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================

# Path to Ubuntu ISO (download from https://ubuntu.com/download/server)
$ISOPath = "C:\Users\harry\Downloads\ubuntu-24.04.3-live-server-amd64.iso"

# Where to store VM files
$VMPath = "C:\Hyper-V\VMs"

# Virtual Switch name (will be created if doesn't exist)
$SwitchName = "K3S-External"

# Your physical network adapter name (run: Get-NetAdapter to find it)
$PhysicalAdapter = "Wi-Fi"

# VM names to create
$VMNames = @("k3s-06", "k3s-07")

# VM Specs (matching your Proxmox VMs)
$VMMemoryStartup = 4GB
$VMMemoryMin = 2GB
$VMMemoryMax = 6GB
$VMCPUCount = 4
$VMDiskSize = 30GB

# ============================================
# DO NOT EDIT BELOW THIS LINE
# ============================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Hyper-V K3S Worker Node Creator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Check if ISO exists
if (-not (Test-Path $ISOPath)) {
    Write-Host "ERROR: Ubuntu ISO not found at: $ISOPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download Ubuntu 24.04 Server from:" -ForegroundColor Yellow
    Write-Host "https://ubuntu.com/download/server" -ForegroundColor White
    Write-Host ""
    Write-Host "Then update the ISOPath variable in this script." -ForegroundColor Yellow
    exit 1
}

# Create VM storage directory
if (-not (Test-Path $VMPath)) {
    Write-Host "Creating VM directory: $VMPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $VMPath -Force | Out-Null
}

# Check/Create Virtual Switch
$existingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $existingSwitch) {
    Write-Host "Creating External Virtual Switch: $SwitchName" -ForegroundColor Yellow
    Write-Host "  Using adapter: $PhysicalAdapter" -ForegroundColor Gray
    
    # Check if adapter exists
    $adapter = Get-NetAdapter -Name $PhysicalAdapter -ErrorAction SilentlyContinue
    if (-not $adapter) {
        Write-Host "ERROR: Network adapter '$PhysicalAdapter' not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Available adapters:" -ForegroundColor Yellow
        Get-NetAdapter | Where-Object Status -eq 'Up' | Format-Table Name, Status, MacAddress
        Write-Host ""
        Write-Host "Update the PhysicalAdapter variable with the correct name." -ForegroundColor Yellow
        exit 1
    }
    
    try {
        New-VMSwitch -Name $SwitchName -NetAdapterName $PhysicalAdapter -AllowManagementOS $true
        Write-Host "  Virtual Switch created successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to create virtual switch: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "Virtual Switch '$SwitchName' already exists." -ForegroundColor Green
}

Write-Host ""

# Create each VM
foreach ($VMName in $VMNames) {
    Write-Host "----------------------------------------" -ForegroundColor Gray
    Write-Host "Creating VM: $VMName" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    # Check if VM already exists
    $existingVM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Host "  VM '$VMName' already exists. Skipping." -ForegroundColor Yellow
        continue
    }
    
    # Create VM directory
    $VMDir = Join-Path $VMPath $VMName
    if (-not (Test-Path $VMDir)) {
        New-Item -ItemType Directory -Path $VMDir -Force | Out-Null
    }
    
    # VHD path
    $VHDPath = Join-Path $VMDir "$VMName.vhdx"
    
    try {
        # Create the VM
        Write-Host "  Creating virtual machine..." -ForegroundColor Gray
        New-VM -Name $VMName `
            -MemoryStartupBytes $VMMemoryStartup `
            -Generation 2 `
            -NewVHDPath $VHDPath `
            -NewVHDSizeBytes $VMDiskSize `
            -SwitchName $SwitchName `
            -Path $VMPath | Out-Null
        
        # Configure VM settings
        Write-Host "  Configuring VM settings..." -ForegroundColor Gray
        Set-VM -Name $VMName `
            -ProcessorCount $VMCPUCount `
            -DynamicMemory `
            -MemoryMinimumBytes $VMMemoryMin `
            -MemoryMaximumBytes $VMMemoryMax `
            -AutomaticStartAction Start `
            -AutomaticStopAction ShutDown
        
        # Add DVD drive with Ubuntu ISO
        Write-Host "  Attaching Ubuntu ISO..." -ForegroundColor Gray
        Add-VMDvdDrive -VMName $VMName -Path $ISOPath
        
        # Set boot order (DVD first)
        $DVDDrive = Get-VMDvdDrive -VMName $VMName
        Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive
        
        # Disable Secure Boot (required for Ubuntu)
        Write-Host "  Disabling Secure Boot for Ubuntu..." -ForegroundColor Gray
        Set-VMFirmware -VMName $VMName -EnableSecureBoot Off
        
        Write-Host "  VM '$VMName' created successfully!" -ForegroundColor Green
        
    }
    catch {
        Write-Host "  ERROR creating VM: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  VM Creation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Start the VMs:" -ForegroundColor White
foreach ($VMName in $VMNames) {
    Write-Host "   Start-VM -Name '$VMName'" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "2. Connect to each VM via Hyper-V Manager and install Ubuntu" -ForegroundColor White
Write-Host ""
Write-Host "3. During Ubuntu installation, configure:" -ForegroundColor White
Write-Host "   - Hostname: k3s-06 or k3s-07" -ForegroundColor Gray
Write-Host "   - Username: tech" -ForegroundColor Gray
Write-Host "   - Install OpenSSH Server: YES" -ForegroundColor Gray
Write-Host "   - Use static IP in 192.168.1.x range" -ForegroundColor Gray
Write-Host ""
Write-Host "4. After Ubuntu install, join to K3S cluster. See:" -ForegroundColor White
Write-Host "   k3s\docs\HYPERV_SETUP.md" -ForegroundColor Cyan
Write-Host ""
