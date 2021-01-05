
<#
DistinguishedName : CN=AWS-195623400101-instanceops,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=a
GroupCategory     : Security
GroupScope        : Global
Name              : AWS-195623400101-instanceops
ObjectClass       : group
ObjectGUID        : a9509474-e577-4af2-9b14-43d9b91a5b78
SamAccountName    : AWS-195623400101-instanceops
SID               : S-1-5-21-2201383587-432749142-605814149-1144
#>



$UserName = "Arthur.Bruton" 
Add-ADGroupMember -Identity "jump-prod" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"
Add-ADGroupMember -Identity "jump-dev" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"
Add-ADGroupMember -Identity "jump-test" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"
# Add DELWP Usert to jump-dev group
$UserName="brett.miller" 
Add-ADGroupMember -Identity "jump-dev" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"

function Create-ADAccount {
    param (
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        [Parameter(Mandatory=$True)]
        [string]$PlainPassword
    )
    try{
        get-aduser $UserName
        Write-host "Account $UserName already exists"
        return
    }catch{
        Write-host "Creating Account $UserName"
    }

    try {
        # Sleep a bit 
        Start-Sleep -Seconds 3
        $Password = ConvertTo-SecureString $PlainPassword -AsPlainText -Force
        $UserPrincipalName = "$UserName@nrtd.delwp.aws"
        $Email = "$UserName@datacom.com.au"

        New-ADUser -Name "$UserName" -UserPrincipalName $UserPrincipalName -AccountPassword $Password -Enabled $true -EmailAddress $Email
        Set-ADUser -Identity "$UserName" -ChangePasswordAtLogon $true -Description "Datacom Ops"
        Write-Host "User Account $UserName created"

        Write-Host "Adding user to groups"

        Add-ADGroupMember -Identity "AWS-617064384260-admin" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"
        Add-ADGroupMember -Identity "AWS-455963695269-admin" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"
        Add-ADGroupMember -Identity "AWS-195623400101-admin" -Members "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"

    }
    catch {
        Write-host $_.Exception
        Write-host "Failed to create account $UserName"
    }
}


#Create-ADAccount -UserName "Kevin.Yan" -PlainPassword "goipei5il2uZe0ooNee8io0e"

function Remove-ADAccount {
    param (
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        [Parameter(Mandatory=$True)]
        [string]$PlainPassword
 
    )
    Write-Host "Removing Account $UserName"
    Remove-ADUser -Identity "CN=$UserName,OU=Users,OU=nrtd,DC=nrtd,DC=delwp,DC=aws"
}


$Users = Get-ADUser -Filter * -Properties DisplayName, EmailAddress, Title, sAMAccountName, Description
 
 
foreach ( $user in $Users) {
    if ( $user.EmailAddress) {
        if (! $user.EmailAddress.ToLower().EndsWith('@datacom.com.au')) {
             $Groups = [string]::Join(',',(Get-ADPrincipalGroupMembership $user.SamAccountName).name)
             write-output ("{0},{1},{2},{3}" -f  ($user.Description,$user.SamAccountName,$User.EmailAddress,$Groups)) | out-file -Append -FilePath C:\setup\user-list.csv
             
        }
      
    }
}

# Setup userid 
function Rename-ADAccount {
param (
        [Parameter(Mandatory=$True)]
        [string]$UserName,
        [Parameter(Mandatory=$True)]
        [string]$NewName
 
    )
    try{
        $user = Get-ADUser -Filter {cn -eq $UserName }             
        Write-Host $user.DistinguishedName
        Set-ADUser -identity $user -UserPrincipalName "$NewName"
        Write-host "Account $UserName OK"
    }
    catch {
        Write-host $_.Exception
        Write-host "Failed to rename  account $UserName"
    }
}
