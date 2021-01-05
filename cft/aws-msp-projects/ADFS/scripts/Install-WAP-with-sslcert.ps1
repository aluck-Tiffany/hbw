#########################################################################
# Install-WAP.ps1 
# - Install and Configure Microsoft WAP for ADFS and RDGW with third-party
#   signed SSL certificate
# - Tested with Microsoft Windows Servedr 2016
#
# Updated By Eric Ho (eric.ho@datacom.com.au, hbwork@gmail.com)
# Last update: September 18, 2018
# - Bug fix: get SSL based on Subject name to address SSL cert order issue
#########################################################################
param(
    [string]$DomainDNSName,
    [string]$AdfsSvcUserPW,
    [string]$FederationServiceName
)

try {
    Start-Transcript -Path C:\cfn\log\Install-WAP.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    $adfsPass = ConvertTo-SecureString $AdfsSvcUserPW -AsPlainText -Force
    $DomainNetBIOSName = $DomainDNSName.Split('.')[0]
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBIOSName\svc_adfs", $adfsPass

    #$MyCert = (dir Cert:\LocalMachine\My)[0]
    $MyCert = dir cert:\\LocalMachine\My | ? { $_.Subject -match "Domain Control Validated"}
    $thumbprint =$MyCert.thumbprint

    Install-WindowsFeature Web-Application-Proxy -IncludeManagementTools

    $i = 0
    while (-not (Resolve-DnsName -Name $FederationServiceName -ErrorAction SilentlyContinue) -and ($i -lt 60)) { 
        Write-Verbose "Unable to resolve $FederationServiceName ,. Waiting for 5 seconds before retrying."
        Start-Sleep 5 
        $i += 1
    }

    try {
    	Install-WebApplicationProxy –CertificateThumbprint $thumbprint `
		-FederationServiceName $FederationServiceName `
		-FederationServiceTrustCredential $Credential
	
	Add-WebApplicationProxyApplication -BackendServerUrl "https://gateway.${FederationServiceName}" `
		-ExternalCertificateThumbprint $thumbprint `
		-ExternalUrl "https://gateway.${FederationServiceName}" `
		-Name 'RDGGateway' -ExternalPreAuthentication PassThrough
    } catch {
        Write-host $_.Exception
        Write-host "Failed to install WAP!"
    }
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
