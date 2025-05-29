param (
    [string]$provider = "dhcp",  # Default is DHCP
    [string]$adapterName = "Ethernet"
)

# Define DNS provider IP addresses
$providers = @{
    "google"     = @("8.8.8.8", "8.8.4.4")
    "cloudflare" = @("1.1.1.1", "1.0.0.1")
    "opendns"    = @("208.67.222.222", "208.67.220.220")
    "quad9"      = @("9.9.9.9", "149.112.112.112")
    "begzar"     = @("185.55.226.26", "185.55.225.25")
    "dhcp"       = @()
}

# Check if adapter exists
$interface = Get-NetAdapter -Name $adapterName -ErrorAction SilentlyContinue
if (-not $interface) {
    Write-Error "Network adapter '$adapterName' not found."
    exit
}

$interfaceIndex = $interface.ifIndex

# Set DNS based on selected provider
if ($provider -eq "dhcp") {
    Write-Host "Setting DNS to automatic (DHCP)..."
    Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ResetServerAddresses
} elseif ($providers.ContainsKey($provider)) {
    $dnsServers = $providers[$provider]
    Write-Host "Setting DNS to $($provider.ToUpper())..."
    Set-DnsClientServerAddress -InterfaceIndex $interfaceIndex -ServerAddresses $dnsServers

    for ($i = 0; $i -lt $dnsServers.Count; $i++) {
        Write-Host "  DNS Server $i`: $($dnsServers[$i])"
    }
} else {
    Write-Error "Unknown DNS provider: '$provider'. Supported providers are: $($providers.Keys -join ', ')."
}