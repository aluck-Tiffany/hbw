#Usage: Script is to be scheduled using task scheduler on the WSUS server itself with WSUS IAM role and to be run every week on patch dat/time as
#       the script will detect if its the 3rd week of the month (eg 3rdnd Tuesday of the month) for Production group patches.
#       Script is to be executed with permissions to WSUS (WSUS local administrator)
#       Remove the -WhatIf switch when going live with script
# Change History:
#  Initial version: Martin Sustaric (MartinSustaric@datacom.com.au)
#  16/8/2018 Eric Ho (eric.ho@datacom.com.au)
#    - Get AWS region, accountId, SNS topic Arn, credentials from Instance Metadata
#    - Create logfile if not exists
#    - Post to SNS topic using instance IAM profile 

Import-Module AWSPowerShell

#Script variables
$logfile = "C:\autopatching\autopatchingprod.log"

function Write-Log {
    param ( 
        [Parameter(Mandatory)][string]$Message
    )
    $DateTime = Get-Date -Format "dd-MM-yy HH:mm:ss"
    Add-Content -Value "$DateTime - $Message" -Path $logfile
}

if ( !(Test-Path $logfile)) { 
    Set-Content $logfile "Auto Patching Log file for Dev"
}

#test variables update to required schedule<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$FindNthDay = 3
$WeekDay = "Wednesday"
$wsushostname = "localhost"
$wsusport = "8530"
#Email SNS variables
$subject = "OLGR - WSUS Patching Prod"

$awsRegion = (Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/placement/availability-zone) -replace '\w$',''
$iamProfile = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/iam/info/
$instanceId = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/instance-id

if ($iamProfile) {
    $accountId = $iamProfile.InstanceProfileArn.Split(':')[4]
    $snstopicarn = "arn:aws:sns:${awsRegion}:${accountId}:${accountId}-WSUS"
    write-host "SNS Topic Arn: $snstopicarn"
}
else {
    Write-host "No Instance Profile is attached to WSUS instance $instanceId, quit!"
    exit 1
}

Write-Log -Message "### Production Auto Patching Script Executing ###"

#workout if this is the 3rd Wednesday of the month
$patchprod = $false
[datetime]$Today = [datetime]::NOW
$todayM = $Today.Month.ToString()
$todayY = $Today.Year.ToString()
[datetime]$StrtMonth = $todayM + "/1/" + $todayY
while ($StrtMonth.DayofWeek -ine $WeekDay ) {
    $StrtMonth=$StrtMonth.AddDays(1)
}

$prodpatchdate = $StrtMonth.AddDays(7*($FindNthDay-1))

Write-Log -Message "Checking if its Production patch day - Variables are FindNthDay = $FindNthDay and WeekDay = $WeekDay "

#Dev Patch Day
if ($prodpatchdate.DayOfYear -eq $Today.DayOfYear){
    $patchprod = $true
    Write-Log -Message "Patch Day = $patchprod"
} else {
    Write-Log -Message "Patch Day = $patchprod"
    Write-Log -Message "### Auto Patching Script Finished ###"
    Exit
}

#get WSUS server detials
$wsusserver = Get-WSUSServer -Name $wsushostname -Port 8530 
#$wsusserver.GetConfiguration()

#Load file with patch info applied to Dev
$wsusupdates = Import-Csv C:\autopatching\devpatches.csv
#Check if there are patches
if($wsusupdates.Count -gt 0){
    Write-Log -Message "Applying Updates to Production group"
    foreach ($update in $wsusupdates){
    #remove the WhatIf switch when live<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    #Get-WsusUpdate -UpdateId $update.Guid | Approve-WsusUpdate -Action Install -TargetGroupName "Production" -WhatIf
    Get-WsusUpdate -UpdateId $update.Guid | Approve-WsusUpdate -Action Install -TargetGroupName "Production"
    }
    
    #Send email
    $updatecount = $wsusupdates.Count
    Write-Log -Message "Number of updates available $updatecount" 

    $patchmessagelist = "Patches applied to Production group:" + "`n" + "`n"
    foreach ($_ in $wsusupdates){
        $patchmessagelist += "Title: " + $_.Title + " `n"
        $patchmessagelist += "URL: " + $_.AdditionalInformationUrls + " `n"
        $patchmessagelist += "Guid: " + $_.Guid + " `n" + "`n"
    }
    $patchmessagelist
    Write-Log -Message "Sending SNS notification"
    Publish-SNSMessage -TopicArn $snstopicarn -Subject $subject -Message $patchmessagelist -Region $awsRegion
   
    #Archive CSV
    Write-Log -Message "Archiving CSV"
    $path = "C:\autopatching\archive\"
    If(!(test-path $path))
    {
        New-Item -ItemType Directory -Force -Path $path
    }
    Move-Item "C:\autopatching\devpatches.csv" ("C:\autopatching\archive\devpatches{0:yyyyMMdd}.csv" -f (get-date))
    Write-Log -Message "### Auto Patching Script Finished ###"
} else {
    Write-Log -Message "No Patches found in CSV to apply to Production"
    Write-Log -Message "Sending SNS notification"


    #Send SNS notification
    Publish-SNSMessage -TopicArn $snstopicarn -Subject $subject -Message "No updates were found to be applied for Production" -Region $awsRegion
    Write-Log -Message "### Auto Patching Script Finished ###"
    Exit
}

# End