$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path $env:temp\bootstrap-puppet-install.log -append
Write-Host "Downloading Puppet"
(New-Object System.Net.WebClient).DownloadFile("https://downloads.puppetlabs.com/windows/puppet-agent-x64-latest.msi", "$env:temp\puppet-agent-x64-latest.msi")
Write-Host "Installing Puppet"
Start-Process msiexec.exe -ArgumentList "/qn /norestart /i $env:temp\puppet-agent-x64-latest.msi" -Wait
Write-Host "Puppet Installed"
Stop-Transcript