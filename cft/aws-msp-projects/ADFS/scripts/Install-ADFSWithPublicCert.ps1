param(
    [string]
    $DomainDNSName,

    [string]
    $DCName,

    [string]
    $DomainNetBIOSName,

    [string]
    $Username,

    [string]
    $Password,

    [string]
    $ADFSServerNetBIOSName1,

    [string]
    $CertURL,

    [string]
    $CertPassword,

    [switch]
    $FirstServer
)

Function Get-CertificateFromS3Bucket {
    param (
        [Parameter(Mandatory=$true, HelpMessage = "Please enter the cert URL in formation of s3://.*")]
        [ValidatePattern("s3://.+/.*")]
        [string]$URL
    )

    $BucketName = $URL.split('/')[2]

    $KeyName = $URL.Replace("s3://${BucketName}/","")

    $FileName = "C:\Windows\Temp\" + $KeyName.Split('/')[-1]

    Read-S3Object -BucketName $BucketName -Key $KeyName -File $FileName | out-null

    return $FileName
}


try {
    Start-Transcript -Path C:\cfn\log\Install-ADFS.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    #Domain user credential
    $Pass = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBIOSName\$Username", $Pass

    #Cert password
    $CertPass = ConvertTo-SecureString $CertPassword -AsPlainText -Force

    $ADFSCertificate = Get-CertificateFromS3Bucket -URL $CertURL

    Import-PfxCertificate –FilePath $ADFSCertificate -CertStoreLocation cert:\localMachine\my -Password $CertPass

    $MyCert = (dir Cert:\LocalMachine\My)[0]
    
    $CertificateThumbprint =$MyCert.thumbprint

    $FederationServiceName = ($MyCert.Subject.Split(',') | ? { $_ -match "CN="}).replace('CN=','')

    if ( ! ( $FederationServiceName -match $DomainDNSName ) ) {
        throw "Cert subject $FerderationServiceName does not match DNS domain $DomainDNSName"
    }

    Install-WindowsFeature ADFS-Federation -IncludeManagementTools

    if($FirstServer) {

        Install-AdfsFarm -CertificateThumbprint $MyCert.thumbprint -FederationServiceDisplayName ADFS -FederationServiceName $FederationServiceName -ServiceAccountCredential $Credential
        
        Install-WindowsFeature RSAT-DNS-Server
        $netip = Get-NetIPConfiguration
        $ipconfig = Get-NetIPAddress | ?{$_.IpAddress -eq $netip.IPv4Address.IpAddress}

        $ADFSHostName = $FederationServiceName.Replace(".${DomainDNSName}","").split('.')[0]
        $Zones = $FederationServiceName.Replace(".${DomainDNSName}","").Replace("${ADFSHostName}.","").split('.')

        #Create sub domaon zone if Fedaration Service name is under subdomain

        $ZoneName = $DomainDNSName

        for ( $i = $Zones.count - 1; $i -ge 0 ; $i --) {

            $ZoneName = $Zones[$i] + ".${ZoneName}"

            if ( ! ( Get-DnsServerZone -ComputerName $DCName | ? { $_.ZoneName -ieq $ZoneName} ) ) {
                Write-Verbose "Create zone $ZoneName"
                Add-DnsServerPrimaryZone -Name $ZoneName -ReplicationScope "Domain" -ComputerName $DCName
            }
        }

        Add-DnsServerResourceRecordA -Name $ADFSHostName -ZoneName $ZoneName -IPv4Address $ipconfig.IPAddress -Computername $DCName
        
        Invoke-Command -ScriptBlock {repadmin /syncall /A /e /P} -ComputerName $DCName
    }
    else {

        $PrimaryComputerName = $ADFSServerNetBIOSName1 + "." + $DomainDNSName

        Add-AdfsFarmNode -CertificateThumbprint $MyCert.thumbprint -ServiceAccountCredential $Credential -PrimaryComputerName $PrimaryComputerName -PrimaryComputerPort 80
    }

    Write-Verbose "Sending CFN Signal @ $(Get-Date)"
    Write-AWSQuickStartStatus -Verbose
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}