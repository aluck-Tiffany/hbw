try {
    Start-Transcript -Path C:\cfn\log\Start-wsus-sync.ps1.txt -Append

    $ErrorActionPreference = "Stop"

    Set-WsusServerSynchronization -SyncFromMU
    $wsusServer = Get-WsusServer -Name localhost -Port 8530
    $wsusConfig = $wsusServer.GetConfiguration()
    $wsusConfig.AllUpdateLanguagesEnabled = $false
    $wsusConfig.SetEnabledUpdateLanguages("en")
    $wsusConfig.Save()
    Restart-Service wsusservice -Force

    $subscription = $wsus.GetSubscription()
    $subscription.StartSynchronization()
} catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
}
