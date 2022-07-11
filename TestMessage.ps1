<#
.SYNOPSIS
Sends an e-mail test message
.PARAMETER from
E-mail address used to send the messages.
Use a valid e-mail address.
.PARAMETER smtpUser
Used to authenticate to the SMTP server. If not supplied the script will take the result from the 'from' parameter.
Use a valid e-mail address.
.PARAMETER smtpPassword
Optional, only if the server requires authentication.
#>
[CmdletBinding(DefaultParameterSetName = 'sendsmail')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Will run in Docker, we can''t  pass a SecureString.')]
param (
    [ValidatePattern('^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*)$')]
    [Parameter(Mandatory)]
    [string]$smtpServer,
    [ValidateRange(1, [System.UInt16]::MaxValue)]
    [int]$smtpPort = 25,
    [ValidatePattern('^(([^<>()[\]\.,;:\s@\"]+(\.[^<>()[\]\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\.,;:\s@\"]+\.)+[^<>()[\]\.,;:\s@\"]{2,})$')]
    [Parameter(Mandatory)]
    [string]$from,
    [ValidatePattern('^(([^<>()[\]\.,;:\s@\"]+(\.[^<>()[\]\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\.,;:\s@\"]+\.)+[^<>()[\]\.,;:\s@\"]{2,})$')]
    [Parameter(Mandatory)]
    [string]$destinationAddress,
    [string]$smtpUser,
    [string]$smtpPassword
)
Set-StrictMode -Version 3.0

Write-Verbose "Starting..."

$body = @'
<p>Hello,</p>
<p>
    This is a test e-mail message.<br />
</p>
<p>Thanks,<br>
<p>Your administrador<br>
'@

if (!($smtpUser)) {
    $smtpUser = $from
}
if ($smtpPassword) {
    $smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUser, (ConvertTo-SecureString $smtpPassword -AsPlainText -Force)
} else {
    $smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUser
}

Send-MailMessage -SmtpServer $smtpServer -Port $smtpPort -From $from -To $destinationAddress -Subject "Test message" -Body $body -BodyAsHtml -Priority "High" -Encoding "utf8" -UseSsl -Credential $smtpCredential

Write-Verbose "Done."