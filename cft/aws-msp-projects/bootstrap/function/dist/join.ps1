Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $dnsIps
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$securePassword
Add-Computer -NewName $computerName -DomainName $domainName -Credential $credentials -ErrorAction Stop
# Execute restart after script exit and allow time for external services
$shutdown = Start-Process -FilePath "shutdown.exe" -ArgumentList @("/r", "/t 10") -Wait -NoNewWindow -PassThru
if ($shutdown.ExitCode -ne 0) {
    throw "[ERROR] shutdown.exe exit code was not 0. It was actually $($shutdown.ExitCode)."
}