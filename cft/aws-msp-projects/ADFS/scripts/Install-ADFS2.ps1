param(
    [string]
    $DomainDNSName = "olgr.ces.aws",


    [string]
    $DomainNetBIOSName = "olgr",

    [string]
    $Username = "svc_adfs",

    [string]
    $Password = "Datacom2018!",

    [string]
    $ADFSServerNetBIOSName1 = "ADFS1"
)


try {
    Start-Transcript -Path C:\cfn\log\Install-ADFS.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    #Domain user credential
    $Pass = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBIOSName\$Username", $Pass


    $MyCert = (dir Cert:\LocalMachine\My)[0]
    
    $CertificateThumbprint =$MyCert.thumbprint

    $FederationServiceName = ($MyCert.Subject.Split(',') | ? { $_ -match "CN="}).replace('CN=','')

    Install-WindowsFeature ADFS-Federation -IncludeManagementTools

    $PrimaryComputerName = $ADFSServerNetBIOSName1 + "." + $DomainDNSName

    Add-AdfsFarmNode -CertificateThumbprint $MyCert.thumbprint -ServiceAccountCredential $Credential -PrimaryComputerName $PrimaryComputerName -PrimaryComputerPort 80

}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
}