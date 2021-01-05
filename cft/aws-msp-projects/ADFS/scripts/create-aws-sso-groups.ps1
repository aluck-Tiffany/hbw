param(
    [Parameter(Mandatory = $true, Position = 1)][string]$AccountId,
    [Parameter(Mandatory = $true, Position = 2)][string]$AccountName
)

$RoleNames = @("admin","poweruser","instanceops","readonly")

if (-not ($AccountId.Length -eq 12)) {
    throw "AWS Account ID must be 12 digital numbers"
    exit 1
}

foreach ($name in $RoleNames) {
    $groupName = "AWS-${AccountId}-${name}"
    $DisplayName = $AccountName + " " + $name

    write-host "Create Group $groupName ($DisplayName) ..."
    
    New-ADGroup -Name $groupName `
        -SamAccountName $groupName `
        -GroupCategory Security `
        -GroupScope Global `
        -DisplayName $DisplayName `
        -Description $AccountName
}
