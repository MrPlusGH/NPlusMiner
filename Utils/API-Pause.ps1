
Write-Host "Sending Pause command to NPlusMiner via API"

. .\Includes\Include.ps1

$Variables = [hashtable]::Synchronized(@{})
$ConfigFile = ".\Config\Config.json"
$Config = Load-Config -ConfigFile $ConfigFile

$ServerPasswd = ConvertTo-SecureString $Config.Server_Password -AsPlainText -Force
$ServerCreds = New-Object System.Management.Automation.PSCredential ($Config.Server_User, $ServerPasswd)

Invoke-WebRequest "http://127.0.0.1:$($Config.Server_Port)/Cmd-Pause" -Credential $ServerCreds

