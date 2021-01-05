param(
    [string]$DomainDNSName,
    [string]$AdfsSvcUserPW
)

try {
    start-Transcript -Path C:\cfn\log\Install-ADFS2.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    Install-WindowsFeature ADFS-Federation -IncludeManagementTools

    $PrimaryComputerName = "ADFS1.${DomainDNSName}"

    $i = 0
    while (-not (Resolve-DnsName -Name $PrimaryComputerName -ErrorAction SilentlyContinue) -and ($i -lt 60)) { 
        Write-Verbose "Unable to resolve $PrimaryComputerName, Waiting for 5 seconds before retrying."
        Start-Sleep 5 
        $i += 1
    }

    try {
        $adfsPass = ConvertTo-SecureString $AdfsSvcUserPW -AsPlainText -Force
        $DomainNetBIOSName = $DomainDNSName.Split('.')[0]
        $svcCred = New-Object System.Management.Automation.PSCredential -ArgumentList "${DomainNetBIOSName}\svc_adfs",$adfsPass
        $thumbprint = (dir Cert:\LocalMachine\My)[0].thumbprint
        Add-AdfsFarmNode -PrimaryComputerName $PrimaryComputerName -ServiceAccountCredential $svcCred  -CertificateThumbprint $thumbprint 
    } catch {
        Write-Warning "Adding ADFS2 to ADFS FARM failed"
    }
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
