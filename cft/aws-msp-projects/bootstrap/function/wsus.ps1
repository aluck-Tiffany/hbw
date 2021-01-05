$WUSServer = "http://$($wsusUrl):8530"
$capTargetGroup = $targetGroup.substring(0,1).toUpper()+$targetGroup.substring(1).toLower()
#Scheduled Install Time value between 0 and 23
$ScheduledInstallTime = 23
#ScheduledInstallDay Accepted values are: "Everyday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
$ScheduledInstallDay = "Wednesday"
#Convert ScheduledInstallTime to Dword for reg
if($ScheduledInstallTime -gt 9){
    switch ($ScheduleInstallTime) {
        "10" {$ScheduledInstallTime = "0000000a"}
        "11" {$ScheduledInstallTime = "0000000b"}
        "12" {$ScheduledInstallTime = "0000000c"}
        "13" {$ScheduledInstallTime = "0000000d"}
        "14" {$ScheduledInstallTime = "0000000e"}
        "15" {$ScheduledInstallTime = "0000000f"}
        "16" {$ScheduledInstallTime = "00000010"}
        "17" {$ScheduledInstallTime = "00000011"}
        "18" {$ScheduledInstallTime = "00000012"}
        "19" {$ScheduledInstallTime = "00000013"}
        "20" {$ScheduledInstallTime = "00000014"}
        "21" {$ScheduledInstallTime = "00000015"}
        "22" {$ScheduledInstallTime = "00000016"}
        "23" {$ScheduledInstallTime = "00000017"}
        }
} else {
    $ScheduledInstallTime = "0000000" + $ScheduledInstallTime
} 
#Convert ScheduledInstallDay to Dword for reg
switch ($ScheduledInstallDay) {
    "Everyday"  {$ScheduledInstallDay = "00000000"}
    "Monday"    {$ScheduledInstallDay = "00000001"}
    "Tuesday"   {$ScheduledInstallDay = "00000002"}
    "Wednesday" {$ScheduledInstallDay = "00000003"}
    "Thursday"  {$ScheduledInstallDay = "00000004"}
    "Friday"    {$ScheduledInstallDay = "00000005"}
    "Saturday"  {$ScheduledInstallDay = "00000006"}
    "Sunday"    {$ScheduledInstallDay = "00000007"}
}
#Build Registry file
$wsusclientreg = @"
Windows Registry Editor Version 5.00
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate]
"TargetGroupEnabled"=dword:00000001
"TargetGroup"="$capTargetGroup"
"WUServer"="$WUSServer"
"WUStatusServer"="$WUSServer"
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
"ScheduleInstallTime"=dword:$ScheduledInstallTime
"NoAutoUpdate"=dword:00000000
"AUOptions"=dword:00000004
"ScheduledInstallDay"=dword:$ScheduledInstallDay
"ScheduledInstallTime"=dword:$ScheduledInstallTime
"UseWUServer"=dword:00000001
"@
#Save Reg file into temp dir
$dir = $env:TEMP + "\wsus"
New-Item -ItemType directory -Path $dir -ErrorAction Ignore
cd $dir
$wsusclientreg | Out-File "$env:temp\wsus\wsusclient.reg"
#Load registry
regedit /s "$env:temp\wsus\wsusclient.reg"