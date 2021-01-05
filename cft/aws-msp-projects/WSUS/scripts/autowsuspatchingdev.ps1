#Usage: 
# Script is to be scheduled using task scheduler on the WSUS server itself with WSUS IAM role and to be run every week on 
# patch dat/time as the script will detect if its the 2nd week of the month (eg 2nd Tuesday of the month) for Developmnt group patches.
# Script is to be executed with permissions to WSUS (WSUS local administrator)
# Remove the -WhatIf switch when going live with script
# Change History:
#  Initial version: Martin Sustaric (MartinSustaric@datacom.com.au)
#  16/8/2018 Eric Ho (eric.ho@datacom.com.au)
#    - Get AWS region, accountId, SNS topic Arn, credentials from Instance Metadata
#    - Create logfile if not exists
#    - Post to SNS topic using instance IAM profile 

Import-Module AWSPowerShell

#Script variables
$logfile = "C:\autopatching\autopatchingdev.log"

#Logfile function
function Write-Log {
    param ( 
        [Parameter(Mandatory)][string]$Message
    )
    $DateTime = Get-Date -Format "dd-MM-yy HH:mm:ss"
    Add-Content -Value "$DateTime - $Message" -Path $logfile
    Write-Host "$DateTime - $Message" -BackgroundColor Black -ForegroundColor Green
}

if ( !(Test-Path $logfile)) { 
    Set-Content $logfile "Auto Patching Log file for Dev"
}

#test variables update to required schedule<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#Default Schedule for Dev patching is 2nd Monday of the Month @9PM
$FindNthDay = 2
$WeekDay = "Wednesday"
#$wsushostname = hostname
$wsushostname = "localhost"
$wsusport = "8530"
#Email SNS variables
$subject = "OLGR - WSUS Patching Dev"

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

Write-Log -Message "### Development Auto Patching Script Executing ###"

#Workout if this is the 2nd Monday of the month
$patchdev = $false
[datetime]$Today = [datetime]::NOW
$todayM = $Today.Month.ToString()
$todayY = $Today.Year.ToString()
[datetime]$StrtMonth = $todayM + "/1/" + $todayY
while ($StrtMonth.DayofWeek -ine $WeekDay ) {
    $StrtMonth=$StrtMonth.AddDays(1)
    }
$devpatchdate = $StrtMonth.AddDays(7*($FindNthDay-1))

Write-Log -Message "Checking if its patch day - Variables are FindNthDay = $FindNthDay and WeekDay = $WeekDay "

#Dev Patch Day
if ($devpatchdate.DayOfYear -eq $Today.DayOfYear){
    $patchdev = $true
    Write-Log -Message "Patch Day = $patchdev"
} else {
    Write-Log -Message "Patch Day = $patchdev"
    Write-Log -Message "### Auto Patching Script Finished ###"
    exit
}
Write-Log -Message "patchdev = $patchdev"


#Connect to WSUS server
Write-Log -Message "Connecting to WSUS Server:$wsushostname on port:$wsusport"
try {
    $wsusserver = Get-WSUSServer -Name $wsushostname -Port $wsusport

} Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Log -Message "Error Connecting to WSUS Server:$wsushostname on port:$wsusport"
    Write-Log -Message "### Auto Patching Script Finished ###"
    Exit
}
Write-Log -Message "Connected to $wsushostname Server on port $wsusport"
#$wsusserver.GetConfiguration()


#get wsus patches availabe for critical and security critical updates
Write-Log -Message "Gathering Patches"
$updatescritical = Get-WsusUpdate -Approval unapproved -status Any -Classification Critical
$updatessecurity = Get-WsusUpdate -Approval unapproved -status Any -Classification Security

#initalize custom ps object
$wsusupdates = @()

#Add details for each security update available
foreach($update in $updatessecurity) {
    $wsusupdate = new-object psobject
    Add-Member -InputObject $wsusupdate -MemberType NoteProperty -Name Title -Value $update.Update.Title
    [string]$guid = $update.Update.AdditionalInformationUrls
    Add-Member -InputObject $wsusupdate -MemberType NoteProperty -Name AdditionalInformationUrls -Value $guid
    Add-Member -InputObject $wsusupdate -MemberType NoteProperty -Name Guid -Value $update.Update.Id.UpdateId.Guid
    $wsusupdates += $wsusupdate
}

#Add details for each critical update available
foreach($update in $updatescritical) {
    $wsusupdate = new-object psobject
    Add-Member -InputObject $wsusupdate -MemberType NoteProperty -Name Title -Value $update.Update.Title
    [string]$guid = $update.Update.AdditionalInformationUrls
    Add-Member -InputObject $wsusupdate -MemberType NoteProperty -Name AdditionalInformationUrls -Value $guid
    Add-Member -InputObject $wsusupdate -MemberType NoteProperty -Name Guid -Value $update.Update.Id.UpdateId.Guid
    $wsusupdates += $wsusupdate
}
$updatecount = $wsusupdates.Count
Write-Log -Message "Number of updates available $updatecount"

#If no updates to be applied exit
if($updatecount -eq 0){
    Write-Log -Message "No updates to be applied"
    Write-Log -Message "Sending SNS notification"

    #Get AWS Credentials 
    Write-Log -Message "Getting AWS Credentials"
    #$awscredentails = ConvertFrom-Json (Invoke-WebRequest http://169.254.169.254/latest/meta-data/iam/security-credentials/WSUS/).Content
    #Send SNS notification
    #Publish-SNSMessage -TopicArn $snstopicarn -Subject $subject -Message "No updates were found to be applied for Development" -Region ap-southeast-2 -AccessKey $awscredentails.AccessKeyId -SecretKey $awscredentails.SecretAccessKey -SessionToken $awscredentails.Token
    Publish-SNSMessage -TopicArn $snstopicarn -Subject $subject -Message "No updates were found to be applied for Development" -Region $awsRegion
    Write-Log -Message "### Auto Patching Script Finished ###"
    Exit
}


#Exort patch info to CSV
$wsusupdates | Export-Csv C:\autopatching\devpatches.csv -NoTypeInformation

Write-Log -Message "Approving Development patches"
#Apply patches to development group
foreach ($update in $wsusupdates){
    #remove the WhatIf switch when live<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    #Get-WsusUpdate -UpdateId $update.Guid | Approve-WsusUpdate -Action Install -TargetGroupName "Development" -WhatIf
    Get-WsusUpdate -UpdateId $update.Guid | Approve-WsusUpdate -Action Install -TargetGroupName "Development"
}


#Create Email Body message
$patchmessagelist = "Patches applied to Development group:" + "`n" + "`n"
foreach ($_ in $wsusupdates){
     $patchmessagelist += "Title: " + $_.Title + " `n"
     $patchmessagelist += "URL: " + $_.AdditionalInformationUrls + " `n"
     $patchmessagelist += "Guid: " + $_.Guid + " `n" + "`n"
}


#Get AWS Credentials 
#Write-Log -Message "Getting AWS Credentials"
#$awscredentails = ConvertFrom-Json (Invoke-WebRequest http://169.254.169.254/latest/meta-data/iam/security-credentials/WSUS/).Content

#Send SNS notification
Write-Log -Message "Sending SNS notification"
Publish-SNSMessage -TopicArn $snstopicarn -Subject $subject -Message $patchmessagelist -Region $awsRegion
#Publish-SNSMessage -TopicArn $snstopicarn -Subject $subject -Message $patchmessagelist -Region ap-southeast-2 -AccessKey $awscredentails.AccessKeyId -SecretKey $awscredentails.SecretAccessKey -SessionToken $awscredentails.Token

Write-Log -Message "### Auto Patching Script Finished ###"

#ENd