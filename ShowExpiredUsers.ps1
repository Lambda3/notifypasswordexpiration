<#
.SYNOPSIS
Shows expired users
#>
[CmdletBinding(DefaultParameterSetName = 'sendsmail')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Will run in Docker, we can''t  pass a SecureString.')]
param (
    [Parameter(Mandatory)][string] $adUsername,
    [Parameter(Mandatory)][string] $adPassword,
    [ValidatePattern('^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*)$')]
    [Parameter(Mandatory)][string]$adDomain,
    [Parameter(Mandatory)][string]$adSearchBase
)
Set-StrictMode -Version 3.0

Write-Verbose "Starting..."

$adCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adUsername, (ConvertTo-SecureString $adPassword -AsPlainText -Force)

$users = Get-ADUser -Server $adDomain -filter * -SearchBase $adSearchBase -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress -Credential $adCredential `
| Where-Object { $_.Enabled -eq $true -and $_.passwordexpired -eq $true }

Write-Output "Found $($users.Count) users expired."
$today = Get-Date
Write-Output "Sorted by name:"
$users | Sort-Object -Property Name | ForEach-Object { "$($_.Name), $($_.EmailAddress), $($_.PasswordLastSet), $([math]::Round(($today - $_.PasswordLastSet).TotalDays, 0)) days" }
Write-Output "`nSorted by last password set:"
$users | Sort-Object -Property PasswordLastSet | ForEach-Object { "$($_.Name), $($_.EmailAddress), $($_.PasswordLastSet), $([math]::Round(($today - $_.PasswordLastSet).TotalDays, 0)) days" }
Write-Verbose "`nDone."