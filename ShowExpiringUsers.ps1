<#
.SYNOPSIS
Shows expiring users
#>
[CmdletBinding(DefaultParameterSetName = 'sendsmail')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Will run in Docker, we can''t  pass a SecureString.')]
param (
    [Parameter(Mandatory, ParameterSetName = "providesauth")][string] $adUsername,
    [Parameter(Mandatory, ParameterSetName = "providesauth")][string] $adPassword,
    [ValidatePattern('^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*)$')]
    [string]$adDomain,
    [Parameter(Mandatory)][string]$adSearchBase,
    [switch]$excludeExpiredUsers,
    [int]$expireInDays = 5,
    [switch]$noProgress
)
Set-StrictMode -Version 3.0

function Get-MaxPasswordAge($user, $adCredential, $defaultmaxPasswordAge, $adDomain) {
    $commandExpression = 'Get-AduserResultantPasswordPolicy $user -Server $adDomain'
    if ($adCredential) {
        $commandExpression += ' -Credential $adCredential'
    }
    $PasswordPol = Invoke-Expression $commandExpression
    if ($null -ne $PasswordPol) {
        $maxPasswordAge = $PasswordPol.MaxPasswordAge
    } else {
        $maxPasswordAge = $defaultmaxPasswordAge
    }
    return $maxPasswordAge
}

Write-Verbose "Starting..."

Import-Module ActiveDirectory
if (!($?)) {
    Write-Error "Could not import ActiveDirectory Module, exiting."
    exit 1
}

if (!($adDomain)) {
    $adDomain = (Get-ADDomain -Current LocalComputer).Forest
}

$adCredential = $null
if ($adUsername -and $adPassword) {
    $adCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adUsername, (ConvertTo-SecureString $adPassword -AsPlainText -Force)
}

$getADUserExpression = "Get-ADUser -Server $adDomain -filter * -SearchBase '$adSearchBase' -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress"
if ($adCredential) {
    $getADUserExpression += ' -Credential $adCredential'
}
$users = Invoke-Expression $getADUserExpression `
| Where-Object { $_.Enabled -eq $true -and $_.PasswordNeverExpires -eq $false -and $null -ne $_.EmailAddress } `
| Sort-Object -Property Name
if ($excludeExpiredUsers) {
    $users = $users | Where-Object { $_.PasswordExpired -eq $false }
}
$getADDefaultDomainPasswordPolicyExpression = 'Get-ADDefaultDomainPasswordPolicy -Server $adDomain'
if ($adCredential) {
    $getADDefaultDomainPasswordPolicyExpression += ' -Credential $adCredential'
}
$defaultmaxPasswordAge = (Invoke-Expression $getADDefaultDomainPasswordPolicyExpression).MaxPasswordAge
$today = Get-Date
[decimal]$count = $users.Count
[decimal]$currentPosition = 0
foreach ($user in $users) {
    $currentPosition++
    $maxPasswordAge = Get-MaxPasswordAge $user $adCredential $defaultmaxPasswordAge $adDomain
    $expiresOn = $user.PasswordLastSet + $maxPasswordAge
    $daysToExpire = (New-TimeSpan -Start $today -End $expiresOn).Days
    $user.DaysToExpire = $daysToExpire
    $user.AboutToExpire = $daysToExpire -le $expireInDays
    if ($user.AboutToExpire) {
        Write-Verbose "User $($user.Name) is about to expire. Max pwd age: $maxPasswordAge, days to expire: $($user.DaysToExpire), pwd last set: $($user.PasswordLastSet)"
    }
    if (!($noProgress)) {
        $percentComplete = [math]::Round($currentPosition * 100.0 / $count, 2)
        Write-Progress -Activity "Checking users..." -Status "$percentComplete% Complete:" -PercentComplete $percentComplete
    }
}
if (!($noProgress)) {
    Write-Progress -Activity "Checking users..." -Status "Ready" -Completed
}
[array]$expiringUsers = $users | Where-Object { $_.AboutToExpire }

if ($expiringUsers) {
    Write-Output "Found $($expiringUsers.Count) users about to expire."
    Write-Output "Sorted by name:"
    $expiringUsers | Sort-Object -Property Name | ForEach-Object { "$($_.Name), $($_.EmailAddress), $($_.PasswordLastSet), $([math]::Round(($today - $_.PasswordLastSet).TotalDays, 0)) days since set, $($_.DaysToExpire) days to expire" }
    Write-Output "`nSorted by last password set:"
    $expiringUsers  | Sort-Object -Property PasswordLastSet | ForEach-Object { "$($_.Name), $($_.EmailAddress), $($_.PasswordLastSet), $([math]::Round(($today - $_.PasswordLastSet).TotalDays, 0)) days since set, $($_.DaysToExpire) days to expire" }
} else {
    Write-Output "No users are about to expire."
}
Write-Verbose "`nDone."