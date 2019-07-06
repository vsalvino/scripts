<#
.SYNOPSIS
Sets up PowerShell remoting on a Windows server using encrypted HTTP or HTTPS/SSL.
Requires Windows PowerShell on Windows 10 or Windows Server 2016 and higher.

.PARAMETER UseHttp
Enables remoting over HTTP. Note that this is still encrypted and secure.

.PARAMETER UseHttps
Enables remoting over HTTPS. Generates a self-signed certificate to verify identify
of the remote machine. Use this when the remote machine is not connected to
ActiveDirectory.

.PARAMETER TrustedHosts
Hostnames or IP addresses allowed to connect to this system. Specify multiple
with commas, and use * for wildcard. Default is "*" which is all. To only allow
hosts on a local network use: "192.168.0.*" for example.
#>

# Parse options
param(
    [switch] $UseHttp = $false,
    [switch] $UseHttps = $false,
    [string] $TrustedHosts = "*"
)

if(-not ($UseHttp -or $UseHttps)) {
    Write-Error "Specify at least one of: -UseHttp or -UseHttps"
    exit 1
}

$Hostname = (Get-ComputerInfo).CsName

# Enable remoting
Enable-PSRemoting -SkipNetworkProfileCheck -Force

# Delete any remoting listeners currently in place
Remove-Item -Recurse WSMan:\localhost\Listener\*

# Set trusted hosts
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value $TrustedHosts -Force

if ($UseHttp) {
    # Create HTTP listener
    New-Item -Path WSMan:\localhost\Listener\ -Transport HTTP -Address * -Force
    # Enable the built-in firewall rules
    Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP*"
    # Output
    Write-Output "
PowerShell Remoting is now enabled via HTTP! To log in from your local machine run:
Enter-PSSession -ComputerName <IP/DNS/Hostname> -Credential (Get-Credential)

NOTE: If you are running behind a cloud or hardware firewall, open port 5985"
}

if ($UseHttps) {
    # Generate a self-signed certificate
    $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "$Hostname"
    # Create HTTPS Listener
    New-Item -Path WSMan:\localhost\Listener\ -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force
    # Create a new firewall rule
    New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Name "WINRM-HTTPS-In-TCP" -Profile Any -LocalPort 5986 -Protocol TCP
    # Write out the public key of the certificate
    $scriptDir = Split-Path $PSCommandPath -Parent
    Export-Certificate -Cert $Cert -FilePath "$scriptDir/${Hostname}.cer"
    # Output
    Write-Output "
PowerShell Remoting is now enabled via HTTPS! To log in from your local machine run:
  > Enter-PSSession -ComputerName <IP/DNS/Hostname> -Credential (Get-Credential) -UseSSL
You may want to disable certificate and/or common name validation by adding SessionOptions:
  > Enter-PSSession -ComputerName <IP/DNS/Hostname> -Credential (Get-Credential) -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
Top copy and install the self-signed certificate to your local machine:
  > `$Session = New-PSSession -ComputerName <IP/DNS/Hostname> -Credential (Get-Credential) -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
  > Copy-Item -FromSession `$Session -Path $(Join-Path $scriptDir ${Hostname}.cer) -Destination .\
  > Import-Certificate -FilePath ${Hostname}.cer -CertStoreLocation Cert:\LocalMachine\Root\

NOTE: If you are running behind a cloud or hardware firewall, open port 5986"
}
