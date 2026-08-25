param (
    [Parameter(Mandatory=$true)][string]$SecretName,
    [Parameter(Mandatory=$true)][string]$SecretValue
)
Write-Host "Verschlüssele Secret '$SecretName' für mediNix (systemd-creds)..."
$utf8 = [System.Text.Encoding]::UTF8.GetBytes($SecretValue)
# Note: systemd-creds is a Linux tool, so we show the user how to do it on the target host.
Write-Host "HINWEIS: Führen Sie diesen Befehl auf dem NixOS-Zielsystem aus:" -ForegroundColor Yellow
Write-Host "echo -n '$SecretValue' | sudo systemd-creds encrypt --name=$SecretName - /var/lib/medinix/secrets/$SecretName.encrypted" -ForegroundColor Cyan
