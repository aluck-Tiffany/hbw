param (
   [Parameter(Mandatory=$True, position=1)][string]$UserName,
   [Parameter(Mandatory=$False, position=2)][string]$ADGroups,
   [Parameter(Mandatory=$False, position=3)][string]$emailDomain = "datacom.com.au"
)


$URL = "https://domain/adfs/portal/updatepassword/"

$UsersContainter = (Get-ADDomain).UsersContainer
$DomaiName = (Get-ADDomain).DNSRoot

function Create-ADAccount {
    param (
        [Parameter(Mandatory=$True)][string]$UserName,
        [Parameter(Mandatory=$False)][string]$emailDomain = "datacom.com.au" 
    )

    try{
        get-aduser $UserName
        Write-host "Account $UserName already exists"

    }catch{
        try {
            Write-host "Creating Account $UserName"
            $Password = ([char[]]([char]33..[char]95) + ([char[]]([char]97..[char]126)) + 0..9 | sort {Get-Random})[0..9] -join ''
            write-host $Password

            $Pass = ConvertTo-SecureString $Password -AsPlainText -Force
            $UserPrincipalName = "$UserName@$DomaiName"
            $Email = "$UserName@$emailDomain"

            New-ADUser -Name "$UserName" -UserPrincipalName $UserPrincipalName -AccountPassword $Pass -Enabled $true -EmailAddress $Email
            Set-ADUser -Identity "$UserName" -ChangePasswordAtLogon $true -Description "Datacom Ops"
            Write-Host "User Account $UserName created"
        } catch {
            Write-host $_.Exception
            Write-host "Failed to create account $UserName"
        }
    }
   
}

function Remove-ADAccount {
    param (
        [Parameter(Mandatory=$True)][string]$UserName

    )
    Write-Host "Removing Account $UserName"
    Remove-ADUser -Identity "CN=$UserName,$UsersContainter"
}

# Setup userid
function Rename-ADAccount {
    param (
        [Parameter(Mandatory=$True)][string]$UserName,
        [Parameter(Mandatory=$True)][string]$NewName
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

Create-ADAccount -UserName $UserName -emailDomain $emailDomain

$ADGroupNames = (Get-ADGroup -Filter *).Name

if ($ADGroups) {
    foreach ($GroupName in ($ADGroups).Split(',').Trim()) {

        $UserGroupMembership = (Get-ADPrincipalGroupMembership $UserName).name 

        if ($UserGroupMembership -contains $GroupName) {
            write-host "User $UserName is in group $GroupName, no action ..."  -ForegroundColor Yellow
        } else {
            if ($ADGroupNames -contains $GroupName) {
                write-host "Add $UserName to AD group $GroupName ..."
                Add-ADGroupMember -Identity $GroupName -Members "CN=$UserName,$UsersContainter"
            }
            else {
                 write-host "Add user $UserName to $GroupName failed (AD group not exist!) " -ForegroundColor Red
            }
        }
   
    }
}

#End

