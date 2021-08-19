# script inspired from Robert Pearman's, and was later found at: https://gist.github.com/meoso/de56bdc68eced50a65d38e99e306ee42

<#
.SYNOPSIS
Sends a message to an user that is about to expire their password.
.PARAMETER simulate
Won't send a message, only write to the console.
.PARAMETER from
E-mail address used to send the messages.
Use a valid e-mail address.
.PARAMETER smtpUser
Used to authenticate to the SMTP server. If not supplied the script will take the result from the 'from' parameter.
Use a valid e-mail address.
#>
[CmdletBinding(DefaultParameterSetName = 'sendsmail')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Will run in Docker, we can''t  pass a SecureString.')]
param (
    [Parameter(Mandatory)][string] $adUsername,
    [Parameter(Mandatory)][string] $adPassword,
    [ValidatePattern('^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*)$')]
    [Parameter(Mandatory)][string]$adDomain,
    [Parameter(Mandatory)][string]$adSearchBase,
    [switch]$excludeExpiredUsers,
    [ValidatePattern('^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))|(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])(\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]))*)$')]
    [Parameter(Mandatory, ParameterSetName = "sendsmail")][string]$smtpServer,
    [ValidateRange(1, [System.UInt16]::MaxValue)][Parameter(Mandatory, ParameterSetName = "sendsmail")][int]$smtpPort,
    [ValidatePattern('^(([^<>()[\]\.,;:\s@\"]+(\.[^<>()[\]\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\.,;:\s@\"]+\.)+[^<>()[\]\.,;:\s@\"]{2,})$')]
    [Parameter(Mandatory, ParameterSetName = "sendsmail")][string]$from,
    [Parameter(ParameterSetName = "sendsmail")][string]$smtpUser,
    [Parameter(Mandatory, ParameterSetName = "sendsmail")][string]$smtpPassword,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [string]$emailBodyTemplateFile,
    [ValidateScript( { Test-Path $_ -PathType Leaf })]
    [string]$emailSubjectTemplateFile,
    [int]$expireInDays = 5,
    [int]$highPriorityInDays = 3,
    [ValidateScript( { Test-Path (Split-Path $_) -PathType Container })]
    [string]$logFile,
    [ValidatePattern('^(([^<>()[\]\.,;:\s@\"]+(\.[^<>()[\]\.,;:\s@\"]+)*)|(\".+\"))@(([^<>()[\]\.,;:\s@\"]+\.)+[^<>()[\]\.,;:\s@\"]{2,})$')]
    [string]$singleRecipient,
    [switch]$noProgress,
    [Parameter(ParameterSetName = "doesnotsendmail")][switch]$simulate
)
Set-StrictMode -Version 3.0

function Get-MaxPasswordAge($user, $adCredential, $defaultmaxPasswordAge, $adDomain) {
    $PasswordPol = Get-AduserResultantPasswordPolicy $user -Credential $adCredential -Server $adDomain
    if ($null -ne $PasswordPol) {
        $maxPasswordAge = $PasswordPol.MaxPasswordAge
    } else {
        $maxPasswordAge = $defaultmaxPasswordAge
    }
    return $maxPasswordAge
}

Write-Verbose "Starting..."

$adCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adUsername, (ConvertTo-SecureString $adPassword -AsPlainText -Force)
if ($emailSubjectTemplateFile) {
    $subjectTemplate = Get-Content $emailSubjectTemplateFile -Raw -Encoding "utf8"
} else {
    $subjectTemplate = 'Your password $(if ($daysToExpire -eq 0) { "expires today ️⚠️" } elseif ($daysToExpire -lt 0) { "has expired $([math]::Abs($daysToExpire)) days ago 😲" } else { "will expire in $daysToExpire days" })'
}
if ($emailBodyTemplateFile) {
    $emailBodyTemplate = Get-Content $emailBodyTemplateFile -Raw -Encoding "utf8"
} else {
    $emailBodyTemplate = @'
<p>Dear $name,</p>
<p>
    Your Password will expire in $daysToExpire day(s).<br>
    To change your password on Windows press CTRL ALT Delete and choose Change Password or
    <a href="https://account.activedirectory.windowsazure.com/ChangePassword.aspx">go to the Portal</a> and change it there.<br />
    If you forgot your password you can reset it <a href="https://passwordreset.microsoftonline.com/">clicking here</a>.<br />
</p>
<p>Thanks,<br>
<p>Your administrador<br>
'@
}
if ($logFile.Trim()) {
    $logFile = $logFile.Trim()
    Write-Verbose "Running with log at: $logFile."
} else {
    $logFile = ""
}

$theSingleRecipient = ""
if ($singleRecipient.Trim()) {
    $theSingleRecipient = $singleRecipient.Trim()
    Write-Output "Running with sigle recipient: $theSingleRecipient."
}

if ($logFile) {
    if (!(Test-Path $logFile)) {
        New-Item $logfile -ItemType File | Out-Null
        Add-Content $logfile "Date,Name,EmailAddress,DaystoExpire,ExpiresOn"
    }
}

$users = Get-ADUser -Server $adDomain -filter * -SearchBase $adSearchBase -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress -Credential $adCredential `
| Where-Object { $_.Enabled -eq $true -and $_.PasswordNeverExpires -eq $false -and $null -ne $_.EmailAddress } `
| Sort-Object -Property Name
if ($excludeExpiredUsers) {
    $users = $users | Where-Object { $_.PasswordExpired -eq $false }
}
$defaultmaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy -Server $adDomain -Credential $adCredential).MaxPasswordAge
$today = Get-Date
$formattedDate = Get-Date -Format yyyyMMdd

if (!($smtpUser)) {
    $smtpUser = $from
}
if (!($simulate)) {
    Write-Verbose "Going to send messages using server $smtpServer`:$smtpPort from $from."
    $smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUser, (ConvertTo-SecureString $smtpPassword -AsPlainText -Force)
}
[decimal]$count = $users.Count
[decimal]$currentPosition = 0
Write-Verbose "Found $count users."
foreach ($user in $users) {
    $currentPosition++
    $Name = $user.Name
    $maxPasswordAge = Get-MaxPasswordAge $user $adCredential $defaultmaxPasswordAge $adDomain
    $expiresOn = $user.PasswordLastSet + $maxPasswordAge
    $daysToExpire = (New-TimeSpan -Start $today -End $expiresOn).Days

    $emailaddress = $user.EmailAddress
    if ($theSingleRecipient) {
        $emailaddress = $theSingleRecipient
    }
    if ($daysToExpire -le $expireInDays) {
        $priority = "Normal"
        if ($daysToExpire -le $highPriorityInDays) {
            $priority = "High"
        }
        $body = $ExecutionContext.InvokeCommand.ExpandString($emailBodyTemplate)
        $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectTemplate)
        if ($emailaddress -ne $user.EmailAddress) {
            $completeEmailAddress = "$emailaddress ($($user.EmailAddress))"
        } else {
            $completeEmailAddress = $emailaddress
        }
        if ($simulate) {
            Write-Output "`nWould have sent message to $completeEmailAddress with priority $priority`:`nSubject: $subject`nBody:`n$body"
        } else {
            Write-Verbose "`nSending message to $completeEmailAddress..."
            Send-MailMessage -SmtpServer $smtpServer -Port $smtpPort -From $from -To $emailaddress -Subject $subject -Body $body -BodyAsHtml -Priority $priority -Encoding "utf8" -UseSsl -Credential $smtpCredential
        }
        if ($logFile) { Add-Content $logfile "$formattedDate,$Name,$emailaddress,$daysToExpire,$(Get-Date $expiresOn -Format yyyyMMdd)" }
    }
    $percentComplete = [math]::Round($currentPosition * 100.0 / $count, 2)
    if (!($noProgress)) {
        Write-Progress -Activity "Checking users..." -Status "$percentComplete% Complete:" -PercentComplete $percentComplete
    }
}
if (!($noProgress)) {
    Write-Progress -Activity "Checking users..." -Status "Ready" -Completed
}

Write-Verbose "`nDone."