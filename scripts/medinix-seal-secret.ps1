param (
    [Parameter(Mandatory=$true)][string]$SecretName,
    [Parameter(Mandatory=$true)][string]$SecretValue
)

# KONVENTION (gleich wie medinix-seal-secret.sh):
#   Datei       : /var/lib/medinix/secrets/<SecretName>.encrypted
#   Credential  : <SecretName>            fuer alle Namen
#                 <basis>-api-key         fuer Namen auf "-apikey"
# systemd bettet den Credential-Namen IN den Blob ein; die Units erwarten
# z.B. "sonarr-api-key". Andere Namen werden nicht umgeschrieben.
$CredentialName = if ($SecretName -match '-apikey$') {
    $SecretName -replace '-apikey$', '-api-key'
} else {
    $SecretName
}

Write-Host "Verschlüssele Secret '$SecretName' für mediNix (systemd-creds)..."
# Note: systemd-creds is a Linux tool, so we show the user how to do it on the target host.
Write-Host "HINWEIS: Führen Sie diesen Befehl auf dem NixOS-Zielsystem aus:" -ForegroundColor Yellow
Write-Host "echo -n '$SecretValue' | sudo systemd-creds encrypt --name=$CredentialName - /var/lib/medinix/secrets/$SecretName.encrypted" -ForegroundColor Cyan
