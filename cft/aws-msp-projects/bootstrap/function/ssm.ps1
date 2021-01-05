$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path $env:temp\bootstrap-ssm-install.log -append
# Uninstall SSM
Write-Host "Searching For SSM Install"
$uninstallfile = Get-ChildItem -Path  "C:\ProgramData\Package Cache" -Filter AmazonSSMAgentSetup.exe -Recurse -ErrorAction SilentlyContinue -Force | %{$_.FullName} | sort LastWriteTime | select -last 1
if($uninstallfile){
    Write-Host "Running SSM Uninstall"
    Start-Process $uninstallfile -ArgumentList "/uninstall /silent" -Wait
    Remove-Item -path "C:\ProgramData\Amazon\SSM" -Recurse -force
}
# Download SSM
Write-Host "Downloading SSM"
(New-Object System.Net.WebClient).DownloadFile("https://amazon-ssm-ap-southeast-2.s3.amazonaws.com/latest/windows_amd64/AmazonSSMAgentSetup.exe", "$env:temp\AmazonSSMAgentSetup.exe")
Write-Host "Getting Instance ID"
$instanceId = Invoke-RestMethod -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
# Get activation code for SSM
Write-Host "Getting Activation Code for $instanceId"
$activation = Invoke-RestMethod -Method GET -Uri "https://$ssmUrl/latest/activate?instanceName=$instanceId"
$activationId = $activation.ActivationId
$activationCode = $activation.ActivationCode
#Install SSM
Write-Host "Installing SSM with $activationId and $activationCode"
Start-Process $env:temp\AmazonSSMAgentSetup.exe -ArgumentList "/quiet /log $env:temp\ssm-agent-install.log CODE=$activationCode ID=$activationId REGION=ap-southeast-2" -Wait
$managedInstanceId = (Get-Content ($env:ProgramData + "\Amazon\SSM\InstanceData\registration") | ConvertFrom-Json).ManagedInstanceID
Get-Service -Name "AmazonSSMAgent"
Write-Host "Registered with Managed Instance ID $managedInstanceId"
# Tag instance in SSM
if ($enforce) {
    $Body = @{
        managedInstanceId = $managedInstanceId
        os = $os + "-enforce" 
    }
} else {
    $Body = @{
        managedInstanceId = $managedInstanceId
        os = $os
    }
}

Write-Host "Tagging Instance"
Invoke-RestMethod -Method POST -Uri "https://$ssmUrl/latest/tag" -Body ($body | ConvertTo-Json)
Stop-Transcript