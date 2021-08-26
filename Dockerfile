FROM mcr.microsoft.com/windows/servercore:ltsc2019
ENTRYPOINT [ "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "c:\\script\\MessageExpiringUsers.ps1" ]
SHELL [ "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" ]
RUN Add-WindowsFeature -Name RSAT-AD-PowerShell -IncludeAllSubFeature
COPY [ "MessageExpiringUsers.ps1", "MessageExpiredUsers.ps1", "ShowNonExpiringUsers.ps1", "ShowExpiredUsers.ps1", "ShowExpiringUsers.ps1", "c:/script/" ]