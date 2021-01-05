param(
    [string]
    $CertURL,

    [string]
    $CertPassword
)

try {
    Start-Transcript -Path C:\cfn\log\Install-SSLCert.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    $CertPass = ConvertTo-SecureString $CertPassword -AsPlainText -Force

    $ADFSCertificate = "C:\Windows\Temp\" + $CertUrl.Split("/")[-1]
    
    wget $CertURL -OutFile $ADFSCertificate

    Import-PfxCertificate –FilePath $ADFSCertificate -CertStoreLocation cert:\localMachine\my -Password $CertPass

}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}
