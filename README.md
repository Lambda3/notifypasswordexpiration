# Notify Active Directory Password Expiration

Scripts to help notify and identity expired users in Active Directory.

This repository contains `Dockerfile` definitions for
[lambda3/notifypasswordexpiration](https://github.com/lambda3/notifypasswordexpiration).

[![Downloads from Docker Hub](https://img.shields.io/docker/pulls/lambda3/notifypasswordexpiration.svg)](https://registry.hub.docker.com/u/lambda3/notifypasswordexpiration)
[![Build](https://github.com/lambda3/notifypasswordexpiration/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/Lambda3/notifypasswordexpiration/actions/workflows/build.yml)

## Supported tags

- [`latest` (*agent/Dockerfile*)](https://github.com/Lambda3/notifypasswordexpiration/blob/main/Dockerfile)

## Supported OS

Currently this only run on Windows Server 2022 containers, but you can adapt the Dockerfile for earlier versions easily.

## Running

You need to set pass the parameters according to each script. The main script is
[MessageExpiringUsers.ps1](https://github.com/Lambda3/notifypasswordexpiration/blob/main/MessageExpiringUsers.ps1).
Call it like this from PowerShell (example with GMail server):

````powershell
docker run --rm -ti -v c:\path\to\your\templates:c:\temp\:ro -v c:\path\to\your\logs\:c:\logs\ lambda3/notifypasswordexpiration `
    -adUsername user@youraddomain.com.br `
    -adPassword YourPassword `
    -adDomain 'youraddomain.com.br' `
    -adSearchBase "'OU=Some OU,OU=YourDomain,DC=youraddomain,DC=com,DC=br'" `
    -emailBodyTemplateFile c:\temp\BodyTemplate_Expiring.tpl `
    -emailSubjectTemplateFile c:\temp\SubjectTemplate_Expiring.tpl `
    -logFile 'c:\logs\expiring_mail.csv' `
    -excludeExpiredUsers `
    -smtpServer smtp.gmail.com `
    -smtpPort 587 `
    -from someusernamethatyoulluse@gmail.com `
    -smtpPassword YourSMTPPassword
````

To run it with the other 3 scripts, you have to inform the entrypoint and the script (which is in the `scripts folder`), like so:

````powershell
docker run --rm -ti -v c:\path\to\your\templates:c:\temp\:ro -v c:\path\to\your\logs\:c:\logs\ --entrypoint powershell lambda3/notifypasswordexpiration c:\script\MessageExpiredUsers.ps1 (...other parameters)
````

## Maintainers

- [Giovanni Bassi](http://blog.lambda3.com.br/L3/giovannibassi/), aka Giggio, [Lambda3](http://www.lambda3.com.br), [@giovannibassi](https://twitter.com/giovannibassi)

## License

This software is open source, licensed under the MIT.
See [LICENSE](https://github.com/Lambda3/notifypasswordexpiration/blob/main/LICENSE) for details.
Check out the terms of the license before you contribute, fork, copy or do anything
with the code. If you decide to contribute you agree to grant copyright of all your contribution to this project, and agree to
mention clearly if do not agree to these terms. Your work will be licensed with the project at Apache V2, along the rest of the code.
