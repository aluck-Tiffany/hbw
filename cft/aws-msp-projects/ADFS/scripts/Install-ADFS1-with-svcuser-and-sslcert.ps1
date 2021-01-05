param(
    [string]$DomainDNSName,
    [string]$DomainAdminPW,
    [string]$DomainAdminUser = "Admin",
    [string]$AdfsSvcUserPW,
    [string]$LegacyADOuName = "",
    [string]$FederationServiceName
)

try {
    start-Transcript -Path C:\cfn\log\Install-ADFS1.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
	[Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
        Break

    }

    if (-not ([System.Environment]::OSVersion.Version.Major -ge 10 -and [System.Environment]::OSVersion.Version.Minor -ge 0))
    {
        Write-Warning "AD FS 2016 can only be installed on Windows Server 2016."
        Break
    }

    Install-WindowsFeature -Name RSAT-AD-PowerShell

    $Pass = ConvertTo-SecureString $DomainAdminPW -AsPlainText -Force
    $DomainNetBIOSName = $DomainDNSName.Split('.')[0]
    $DomainCred = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBIOSName\$DomainAdminUser", $Pass

    $adfsPass = ConvertTo-SecureString $AdfsSvcUserPW -AsPlainText -Force
    $svcCred = New-Object System.Management.Automation.PSCredential -ArgumentList "${DomainNetBIOSName}\svc_adfs",$adfsPass
    $ADPath = "DC=" + [string]::Join(",DC=",$DomainDNSName.Split('.'))

    if ($LegacyADOuName) {
	 write-host "----------- Deploy ADFS on Legacy AD Controller ------------------"
	 $AdfsPath = "OU=${LegacyAdOuName},DC=" + [string]::Join(",DC=",$DomainDNSName.Split('.'))

        $AdfsOU = Get-ADOrganizationalUnit $AdfsPath

        if ( $AdfsOU) {
            write-host "OU $ADPath exists ..."
        }
        else {
            try {
                write-host "Create AWS Organization Unit $AdfsPath ..."
                New-ADOrganizationalUnit -Name $LegacyADOuName -Path $ADPath -Credential $DomainCred
            }  catch {
                write-host $_.Exception
            }
        }
    } else {
	write-host "----------- Deploy ADFS on AWS Directory Service ------------------"
    	$AdfsPath = "OU=${DomainNetBIOSName},DC=" + [string]::Join(",DC=",$DomainDNSName.Split('.'))
    }

    $GuidPath = "CN=ADFS,${AdfsPath}"

    try {
       Get-ADUser svc_adfs  -Credential $DomainCred
       write-host "Account svc_adfs exists, ignore account creation"
    }
    catch {
       write-host "Create ADFS Service user account"
       New-ADUser -Name svc_adfs -PasswordNeverExpires $true -AccountPassword $adfsPass -Enabled $True -SamAccountName svc_adfs -Credential $DomainCred
    }

    $AdfsContainer =  Get-ADObject -SearchBase $AdfsPath -Filter {(objectClass -eq "Container") -and (Name -eq 'ADFS')}  -Credential $DomainCred

    if ($AdfsContainer) {
       write-host "ADFS Container exists!"
    }
    else  {
       write-host "Create ADFS Container"
       New-ADObject -Name "ADFS" -Type Container -Path $AdfsPath -Credential $DomainCred
    }

    $Guid = (Get-ADObject  -SearchBase $GuidPath -Filter {(objectClass -eq "Container") -and -not (Name -eq 'ADFS')} -Credential $DomainCred).Name
    
    if ($Guid)  {
        write-host "GUID Container $Guid exists, Path'CN=${Guid},${GuidPath}'"
    }
    else {
       $Guid = [guid]::NewGuid().Guid
       write-host "Create container 'CN=${Guid},${GuidPath}'"
       New-ADObject -Name $Guid -Type Container -Path  $GuidPath -Credential $DomainCred
    }

    $adminConfig = @{"DKMContainerDn"="CN=${Guid},${GuidPath}"}

    Install-WindowsFeature ADFS-Federation -IncludeManagementTools

    $MyCert = (dir Cert:\LocalMachine\My)[0]
    $thumbprint =$MyCert.thumbprint

    try {
        Install-ADFSFarm -CertificateThumbprint  $thumbprint `
            -FederationServiceName "$FederationServiceName" `
            -ServiceAccountCredential $svcCred `
            -Credential $DomainCred `
            -OverwriteConfiguration `
            -AdminConfiguration $adminConfig `
            -SigningCertificateThumbprint $thumbprint `
            -DecryptionCertificateThumbprint  $thumbprint

    }  catch {
        Write-host $_.Exception
        Write-host "Failed to install ADFS! "
    }
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
#__EOF__
