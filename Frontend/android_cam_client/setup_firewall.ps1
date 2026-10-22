# Add inbound firewall rule for the ASP.NET Core API on port 5235
# Run from an elevated (Administrator) PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\setup_firewall.ps1

$ruleName = "SecurityCam API"
$port     = 5235

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Please run this script as Administrator."
    exit 1
}

if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
    Write-Host "Rule '$ruleName' already exists - skipping."
} else {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -Profile Any | Out-Null
    Write-Host "Inbound rule added for port $port"
}

Get-NetFirewallRule -DisplayName $ruleName | Select-Object DisplayName, Enabled, Direction, Action, Profile
