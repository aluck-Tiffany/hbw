[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$DomainDNSName,
    [Parameter(Mandatory=$true)][string]$FederationServiceName
)

try {
    $ComputerFQDNName = $env:COMPUTERNAME + '.' + $DomainDNSName

    $DomainNetBIOSName = $DomainDNSName.Split('.')[0].ToLower()

    try {
       (Get-Content C:\cfn\scripts\tsgateway.xml).Replace('__DomainNetBIOSName__',$DomainNetBIOSName).Replace('__ComputerFQDNName__', $ComputerFQDNName) |Out-File C:\Users\Administrator\Desktop\tsgateway.xml

       foreach ($cert in (dir Cert:\LocalMachine\My\)) {
         if ( $cert.Subject.Tolower() -match $FederationServiceName.ToLower()) {
            $ThumbPrint = $cert.Thumbprint
            break
         }
       }

       if ($ThumbPrint.length -eq 40) {
        write-host "Set remote Desktop SSL cert to $ThumbPrint"

        #set-item -Path "RDS:\GatewayServer\SSLCertificate\Thumbprint" $thumbprint
        #Restart-Service tsgateway

       }
    }  catch {
        Write-host $_.Exception
    }
} catch {
    Write-host $_.Exception
}
