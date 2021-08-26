<#
.SYNOPSIS
Show users who do not expire
#>
[CmdletBinding(DefaultParameterSetName = 'sendsmail')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Will run in Docker, we can''t  pass a SecureString.')]
param (
    [Parameter(Mandatory, ParameterSetName = "providesauth")][string] $adUsername,
    [Parameter(Mandatory, ParameterSetName = "providesauth")][string] $adPassword,
    [ValidatePattern('^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*)$')]
    [string]$adDomain,
    [Parameter(Mandatory)][string]$adSearchBase
)
Set-StrictMode -Version 3.0

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
| Where-Object { $_.Enabled -eq $true -and $_.PasswordNeverExpires -eq $true } `
| Sort-Object -Property Name
Write-Output "Found $($users.Count) users who do not expire."
foreach ($user in $users) {
    Write-Output "$($user.Name), $($user.EmailAddress)"
}
Write-Verbose "`nDone."