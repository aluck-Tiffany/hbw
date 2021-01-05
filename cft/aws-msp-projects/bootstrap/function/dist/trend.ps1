# Change History: 
# August 29, 2018: remove PolicyID 
$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path $env:temp\bootstrap-trend-deploy.log -append
Write-Host "$(Get-Date -format T) - DSA download started"
$baseUrl="https://$($trendUrl):443/"
if ( [intptr]::Size -eq 8 ) { 
   $sourceUrl=-join($baseurl, "software/agent/Windows/x86_64/") 
}else {
   $sourceUrl=-join($baseurl, "software/agent/Windows/i386/") 
}
Write-Host "$(Get-Date -format T) - Download Deep Security Agent Package" $sourceUrl
(New-Object System.Net.WebClient).DownloadFile($sourceUrl,  "$env:temp\agent.msi")

if ( (Get-Item "$env:temp\agent.msi").length -eq 0 ) {
    Write-Host "Failed to download the Deep Security Agent. Please check if the package is imported into the Deep Security Manager. "
    exit 1 
}

Write-Host "$(Get-Date -format T) - Downloaded File Size:" (Get-Item "$env:temp\agent.msi").length
Write-Host "$(Get-Date -format T) - DSA install started"
Write-Host "$(Get-Date -format T) - Installer Exit Code:" (Start-Process -FilePath msiexec -ArgumentList "/i $env:temp\agent.msi /qn ADDLOCAL=ALL /l*v `"$env:temp\bootstrap-trend-install.log`"" -Wait -PassThru).ExitCode 
Write-Host "$(Get-Date -format T) - DSA activation started"
Start-Sleep -s 50
& $Env:ProgramFiles"\Trend Micro\Deep Security Agent\dsa_control" -r
if ( $policyId) {
    & $Env:ProgramFiles"\Trend Micro\Deep Security Agent\dsa_control" -a dsm://$($trendUrl):4120/ "policyid:$($policyId)"
}
else {
    & $Env:ProgramFiles"\Trend Micro\Deep Security Agent\dsa_control" -a dsm://$($trendUrl):4120/
}
Write-Host "$(Get-Date -format T) - DSA Deployment Finished"
Stop-Transcript