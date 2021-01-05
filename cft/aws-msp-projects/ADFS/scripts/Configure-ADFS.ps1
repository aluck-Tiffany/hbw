#########################################################################
# Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
#
# Updated By Eric Ho (eric.ho@datacom.com.au, hbwork@gmail.com)
# Last update: July 8, 2018
#
#########################################################################

param(
    [string]$AuthFile = "C:\cfn\scripts\auth.txt",
    [string]$ClaimFile = "C:\cfn\scripts\claims.txt",
    [string]$SAMLProviderName = ""
)

try {
    Start-Transcript -Path C:\cfn\log\Configure-ADFS.ps1.txt -Append

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

    $currentExecutionPolicy = Get-ExecutionPolicy

    if(-not ($currentExecutionPolicy -eq "Unrestricted")){
        Write-Warning "Temporarily setting execution policy unrestricted"
        Set-ExecutionPolicy Unrestricted -Force
    }

    if ( $SAMLProviderName) {
        (Get-Content $ClaimFile) | Foreach-Object { $_ -replace 'saml-provider/datacom',"saml-provider/${SAMLProviderName}" }  | Out-File $ClaimFile
    }

    try {
        Import-Module ADFS

        $ruleSet = New-AdfsClaimRuleSet -ClaimRuleFile $ClaimFile
        $authSet = New-AdfsClaimRuleSet -ClaimRuleFile $AuthFile
    
        Add-ADFSRelyingPartyTrust -Name "Amazon Web Services" -MetadataURL "https://signin.aws.amazon.com/static/saml-metadata.xml" -MonitoringEnabled:$true -AutoUpdateEnabled:$true
        Set-AdfsRelyingPartyTrust -TargetName "Amazon Web Services" -IssuanceTransformRules $ruleSet.ClaimRulesString -IssuanceAuthorizationRules $authSet.ClaimRulesString 
    
        Enable-AdfsEndpoint "/adfs/portal/updatepassword/"
        Set-AdfsEndpoint "/adfs/portal/updatepassword/" -Proxy:$true
        Restart-Service AdfsSrv -Force

        #$signInPage = "https://" + $FederationServiceName + "/adfs/ls/idpinitiatedsignon.aspx"
        #Start-Process $signInPage     
    } catch {
        Write-Warning "Configure ADFS failed, please run this script manually later"
    }

    if(-not ($currentExecutionPolicy -eq "Unrestricted")){
         Write-Host "`n"
         Write-Host "Restoring original execution policy" -ForegroundColor Green
         Set-ExecutionPolicy $currentExecutionPolicy -Force
    }
}
catch {
    Write-Verbose "$($_.exception.message)@ $(Get-Date)"
    $_ | Write-AWSQuickStartException
}

