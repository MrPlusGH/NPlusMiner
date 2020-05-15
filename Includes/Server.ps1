<#
This file is part of NPlusMiner
Copyright (c) 2018 Nemo
Copyright (c) 2018-2020 MrPlus

NPlusMiner is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

NPlusMiner is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

<#
Product:        NPlusMiner
File:           Server.ps1
version:        6.2.0
version date:   20201208
#>


function Test-ServerRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [string]$Type = "all" # all, urlacl, firewall, firewall-tcp, firewall-udp
    )
    $ServerRulesStatus = $true
    if ($ServerRulesStatus -and ($Type -eq "firewall" -or $Type -eq "firewall-tcp" -or $Type -eq "all")) {
        $RuleName = "NPlusMiner Server $($Port) TCP"
        $RuleACLs = & netsh advfirewall firewall show rule name="$($RuleName)" | Out-String
        if (-not $RuleACLs.Contains($RuleName)) {$ServerRulesStatus = $false}
    }
    if ($ServerRulesStatus -and ($Type -eq "firewall" -or $Type -eq "firewall-udp" -or $Type -eq "all")) {
        $RuleName = "NPlusMiner Server $($Port) UDP"
        $RuleACLs = & netsh advfirewall firewall show rule name="$($RuleName)" | Out-String
        if (-not $RuleACLs.Contains($RuleName)) {$ServerRulesStatus = $false}
    }
    if ($ServerRulesStatus -and ($Type -eq "urlacl" -or $Type -eq "all")) {
        $urlACLs = & netsh http show urlacl | Out-String
        if (-not $urlACLs.Contains("http://+:$($Port)/")) {$ServerRulesStatus = $false}
    }
    $ServerRulesStatus
}

function Initialize-ServerRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )

    if (-not (Test-ServerRules -Port $Port -Type "urlacl")) {
        # S-1-5-32-545 = SID for Users group
        (Start-Process netsh -Verb runas -PassThru -ArgumentList "http add urlacl url=http://+:$($Port)/ sddl=D:(A;;GX;;;S-1-5-32-545) user=everyone").WaitForExit(5000)>$null
    }

    if (-not (Test-ServerRules -Port $Port -Type "firewall-tcp")) {
        (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"NPlusMiner Server $($Port) TCP`" dir=in action=allow protocol=TCP localport=$($Port)").WaitForExit(5000)>$null
    }

    if (-not (Test-ServerRules -Port $Port -Type "firewall-udp")) {
        (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall add rule name=`"NPlusMiner Server $($Port) UDP`" dir=in action=allow protocol=UDP localport=$($Port)").WaitForExit(5000)>$null
    }
}

function Reset-ServerRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Int]$Port
    )

    if (Test-ServerRules -Port $Port -Type "urlacl") {
        (Start-Process netsh -Verb runas -PassThru -ArgumentList "http delete urlacl url=http://+:$($Port)/").WaitForExit(5000)>$null
    }

    if (Test-ServerRules -Port $Port -Type "firewall")  {
        (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall delete rule name=`"NPlusMiner Server $($Port) TCP`"").WaitForExit(5000)>$null
        (Start-Process netsh -Verb runas -PassThru -ArgumentList "advfirewall firewall delete rule name=`"NPlusMiner Server $($Port) UDP`"").WaitForExit(5000)>$null
    }
}

Function Start-Server {
    if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}
    Initialize-ServerRules $Config.Server_Port

    # Setup runspace to launch the API webserver in a separate thread
    $ServerRunspace = [runspacefactory]::CreateRunspace()
    $ServerRunspace.Open()
    $ServerRunspace.SessionStateProxy.SetVariable("Config", $Config)
    $ServerRunspace.SessionStateProxy.SetVariable("Variables", $Variables)
    $ServerRunspace.SessionStateProxy.Path.SetLocation($pwd) | Out-Null
    
    $Server = [PowerShell]::Create().AddScript({
        . .\Includes\include.ps1
        
        Load-CoinsIconsCache
        
        Function Get-StringHash([String] $String,$HashName = "MD5")
        {
        $StringBuilder = New-Object System.Text.StringBuilder
        [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{
        [Void]$StringBuilder.Append($_.ToString("x2"))
        }
        $StringBuilder.ToString()
        }
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

        $BasePath = "$($pwd)"
        if ($MyInvocation.MyCommand.Path) {
            Set-Location (Split-Path $MyInvocation.MyCommand.Path)
            $BasePath = $MyInvocation.MyCommand.Path
        }

        $MIMETypes = @{ 
            ".js"   = "application/x-javascript"
            ".html" = "text/html"
            ".htm"  = "text/html"
            ".json" = "application/json;charset=UTF-8"
            ".css"  = "text/css"
            ".txt"  = "text/plain"
            ".ico"  = "image/x-icon"
            ".ps1"  = "text/html" # ps1 files get executed, assume their response is html
            ".png"  = "image/png"
        }

        # Load Branding
        If (Test-Path ".\Config\Branding.json") {
            $Branding = Get-Content ".\Config\Branding.json" | ConvertFrom-Json
        } Else {
            $Branding = [PSCustomObject]@{
                LogoPath = "http://tiny.cc/yvlaoz"
                BrandName = "NPlusMiner"
                BrandWebSite = "https://github.com/MrPlusGH/NPlusMiner"
                ProductLable = "NPlusMiner"
            }
        }

        If (Test-Path ".\Logs\Server.log") {Remove-Item ".\Logs\Server.log" -Force}
        Start-Transcript ".\Logs\ServerTR.log"
        # $pid | out-host
        if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
            [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
        }
        
        [System.Collections.ArrayList]$ProxyCache = @()
        
        [System.Collections.ArrayList]$Clients = @()

        $ServerListener = New-Object Net.HttpListener
        $ServerListener.Prefixes.Add("http://+:$($Config.Server_Port)/")
        $ServerListener.AuthenticationSchemes = [System.Net.AuthenticationSchemes]::Basic

        

        #ignore self-signed/invalid ssl certs
        # Breaks TLS all up !
        # [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$True}
 
        Foreach ($P in $Up) {$Hso.Prefixes.Add($P)} 
            $ServerListener.Start()
            While ($ServerListener.IsListening -and -not $Variables.StopServer) {
                if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}
                # $HC = $ServerListener.GetContext()
                
                $contextTask = $ServerListener.GetContextAsync()
                while (-not $contextTask.AsyncWaitHandle.WaitOne(500)) { }
                $HC = $contextTask.GetAwaiter().GetResult()

                $HReq = $HC.Request
                # $Hreq | Out-Host
                # $Hreq | convertto-json -Depth 10 | Out-File ".\Logs\HReq.json"
                $Path = $Hreq.Url.LocalPath
                $ClientAddress = $Hreq.RemoteEndPoint.Address.ToString()
                $ClientPort = $Hreq.RemoteEndPoint.Port
                $HRes = $HC.Response
                # $HRes.Headers.Add("Content-Type","text/html")      
                
                If (($Clients.Where({$_.Address -eq $ClientAddress})).count -lt 1) {
                    $Clients.Add([PSCustomObject]@{
                        Address = $ClientAddress
                    })
                }
                # $Hreq.RemoteEndPoint | Out-host
                # $ProxURL | Out-Host
                
                # If ("Proxy-Connection" -in $HReq.Headers -and $ProxURL) {
                # If ($ProxURL) {
                if((-not $HC.User.Identity.IsAuthenticated -or $HC.User.Identity.Name -ne $Config.Server_User -or $HC.User.Identity.Password -ne $Config.Server_Password)) {
                    $Data        = "Access denied"
                    $StatusCode  = [System.Net.HttpStatusCode]::Forbidden
                    $ContentType = "text/html"
                    $AuthSuccess = $False
                } else {

# Define Page Header
                    $Header =
@"
                        <meta charset="utf-8"/>
                        <link rel="icon" type="image/png" href="$($Branding.LogoPath)">
                        <header>
                        <img src=$($Branding.LogoPath)>
                        Copyright (c) 2018-$((Get-Date).year) MrPlus
                        <br>
                        
                        $(Get-Date) &nbsp&nbsp&nbsp <a href="https://github.com/MrPlusGH/NPlusMiner">$($Branding.ProductLable) $($Variables.CurrentVersion)</a>  &nbsp&nbsp&nbsp Runtime $(("{0:dd\ \d\a\y\s\ hh\:mm}" -f ((get-date)-$Variables.ScriptStartDate))) &nbsp&nbsp&nbsp Path: $($BasePath) &nbsp&nbsp&nbsp API Cache hit ratio: $("{0:N0}" -f $CacheHitsRatio)%<br>
                        Worker Name: <a href="./Status">$($Config.WorkerName)</a> 
                        &nbsp&nbsp&nbsp Average Profit:  $(((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum)).DisplayStringPerDay)
                        &nbsp&nbsp&nbsp $(If($Variables.Rates.($Config.Currency) -gt 0){"$($Config.Passwordcurrency)/$($Config.Currency) $($Variables.Rates.($Config.Currency).ToString("N2"))"})
                        </header>
                        <hr>
                        <a href="./RunningMiners">Running Miners</a>&nbsp&nbsp&nbsp&nbsp&nbsp<a href="./Benchmarks">Benchmarks</a>&nbsp&nbsp&nbsp&nbsp&nbsp<a href="./SwitchingLog">Switching log</a>
"@

                    If ($Variables.Paused) {
                        $Header += "&nbsp&nbsp&nbsp&nbsp&nbsp<img src=""https://img.icons8.com/flat_round/64/000000/play--v1.png"" width=""16"" height=""16""/>&nbsp<a href=""./Cmd-Mine"">Start Mining</a>"
                    } Else {
                        $Header += "&nbsp&nbsp&nbsp&nbsp&nbsp<img src=""https://img.icons8.com/flat_round/64/000000/pause--v1.png"" width=""16"" height=""16""/>&nbsp<a href=""./Cmd-Pause"">Pause Mining</a>"
                    }
                    $Header +=
@"
                        <span class="right">
                        <a href="https://discord.gg/2BCqPxe"><img src="https://img.shields.io/discord/522832112311599124.svg?label=Discord&style=popout&logo=discord" alt="Discord"></img></a>
                        </span><br>
"@

                        # <a href="https://github.com/MrPlusGH/NPlusMiner/releases/latest"><img src="https://img.shields.io/github/v/release/MRPlusGH/NPlusMiner.svg?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAAAAACPAi4CAAACpklEQVRYw+3XO2/TUBQH8PBB+ALMrEisSBAhEbUdGMsCQlEH1KELEoK1iC7AwsbA6JCGvgRCrSBVByKaVIEqqE2dRGkepGkeJLEPPufa12/7JkWiQpzBN77H/kV/+caxIxBSU5GQ+g+EA2H1ZwClSdXVPtb3WR1ajhlQ9xffL+jHtDgwlKlKI4A9iVWibwI96naN3Z/6IdKBE5DrJiD98AVy/oDcM4EtX2AjAKgoHEj0fACewAuQmxyQCj5ALhCQd3l7U2sk4lol7cBGMLDD25J2xjwutQUbYCbwBraptY6bfU8gx/suoGoCdNRHT2Cd913ASZ0DzQRuOx4AJUhVvYFR2QA6n3D73QOg7/5S8wagw4ED3H7wAChB1Q+AYwMYvMXh1AVQgneqLzAs6QB8xiHvAlgC8AXghAFtOMThvQtgCQIAlS2kMrAMcw5ATxAAAFvKhT6kcbzjAChBBoIA9mMqVNQijjMOgBIciwBya4gZbtkBI4EIIA+23YCRIABYvnYF63o0ejOqjRcRuBSLYsWmp69i700gsBgJrWdnBZbOOZB9gnfB+NIi1kL8Mp5x4yXtvXiMnUev9kDgMnbo7pS1X0ZaRTX6UYcDA5w4SlqBCjZWVUEAWjizZQUy2PgKooBa0WZyVmANG3VhAPqYIYbAHAHfKAGIA9DQpm4jMEtA2pJADFC0e/QsAjMd7K5YEogBeI++i8BU0ZlAEICafI+AHSPB7pjAqMSA1JEjgSgAbQZIWUcCYQDuM2DTkUAceMCAZJESNMYH5hkg0d/NGowP5JdfP334XHvisicQB7QVnedPNI2JAGim9PNXYTJASetAZkIAyjpQmRQAuoTSSjcAABWLPZXSo71iBU4bWG3r1NB8ATgnbyx/F7gQXOHAWd8K/wHgN3+TQF05kYYwAAAAAElFTkSuQmCC" alt=""></img></a>
                        # <a href="https://github.com/MrPlusGH/NPlusMiner/releases/latest"><img src="https://img.shields.io/github/release-date/MRPlusGH/NPlusMiner.svg" alt=""></img></a>

                    If (Test-Path ".\Config\Peers.json") {
                        $Header += "Rigs:&nbsp&nbsp&nbsp&nbsp&nbsp"
                        (get-content ".\Config\Peers.json" | ConvertFrom-Json) | Sort Name | foreach {
                            $Peer = $_
                            $Header += "<a href=""http://$($Peer.IP):$($Peer.Port)/Status"">$($Peer.Name)</a>&nbsp&nbsp&nbsp&nbsp&nbsp"
                        }
                        $Header += "<br>"
                    }

# Define Page Footer
                    $Footer =
@"
                        <br>
                        <Footer>
                        Copyright (c) 2018-2020 MrPlus
                        <span class="right">
                        <a href="httpss://icons8.com">icons8.com</a>
                        </span><br>
                        </Footer>
"@
 
                    
                    $AuthSuccess = $True
                    $HReq.RawUrl | write-Host
                    Switch($Path) {
                        "/StopServer" {
                            write-host "Stop Requested"
                            $Variables.StopServer = $True
                            $Variables.ServerRunning = $False
                            $Hso.Close()
                            $ContentType = "text/html"
                            $Content = "OK"
                            $StatusCode  = [System.Net.HttpStatusCode]::OK
                            Break
                        }
                         "/proxy/" {
                            $ProxyCache = $ProxyCache.Where({$_.Date -ge (Get-Date).AddMinutes(-$Config.Server_ServerProxyTimeOut)})
                            $ProxURL = $HReq.RawUrl.Replace("/Proxy/?url=","")
                            # $ProxURL = $HReq.QueryString['URL']
                            $ProxURLHash = Get-StringHash $ProxURL
                        
                            If (($ProxyCache.Where({$_.ID -eq $ProxURLHash -and $_.date -ge (Get-Date).AddMinutes(-$Config.Server_ServerProxyTimeOut)})).Content -ne $null) {
                                # "Get cache content" | Out-Host
                                $CacheHits++
                                $Content = ($ProxyCache.Where({$_.ID -eq $ProxURLHash})).Content
                                $StatusCode  = [System.Net.HttpStatusCode]::UseProxy
                            } else {
                                # "Web Query" | Out-Host
                                $WebHits++
                                $Wco = New-Object Net.Webclient
                                $Content = $Wco.downloadString("$ProxURL")
                                If ($Content) {
                                    $ProxyCache = $ProxyCache.Where({$_.ID -ne $ProxURLHash})
                                    $ProxyCache.Add([PSCustomObject]@{
                                        ID = $ProxURLHash
                                        URL = $ProxURL
                                        Date = Get-Date
                                        Content = $Content
                                    })
                                }
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                $Wco.Dispose()
                            }

                            If (($CacheHits + $WebHits)) {$CacheHitsRatio = $CacheHits / ($CacheHits + $WebHits) * 100}
                            Break
                        }
                        "/RegisterRig/" {
                                $ContentType = "text/html"

                                $Peers = @()
                                $PeerUpdate = $False
                                
                                $RegisterRigName =  $HReq.QueryString['Name']
                                $RegisterRigIP =  $HReq.QueryString['IP']
                                $RegisterRigPort =  $HReq.QueryString['Port']
                                $RegisterBackRegistrationNotAllowed =  If ($HReq.QueryString['BackRegistrationNotAllowed'] -eq "true") {$True} Else {$False}

                                If (!$RegisterRigName -or (!$RegisterRigIP -and !$ClientAddress) -or !$RegisterRigPort) {
                                    $StatusCode = 404
                                    $Content = "Incomplete registration"
                                } Else { 
                                    $Peer = [PSCustomObject]@{
                                        Name = $RegisterRigName
                                        IP = If (!$RegisterRigIP) {$ClientAddress} Else {$RegisterRigIP}
                                        Port = $RegisterRigPort
                                    }
                                    If (Test-Path ".\Config\Peers.json") {
                                        $Peers = Get-Content ".\Config\Peers.json" | convertfrom-json
                                        If (@($Peers).count -eq 1) { $Peers = @($Peers) }
                                    }
                                    
                                    If (($Peers | ? {$_.Name -eq $RegisterRigName}) -and !(compare $Peer $Peers -IncludeEqual -ExcludeDifferent) -and !($Peers | ? {$_.Name -eq $RegisterRigName}).PreventUpdates) {
                                        ($Peers | ? {$_.Name -eq $RegisterRigName}).IP = $Peer.IP
                                        ($Peers | ? {$_.Name -eq $RegisterRigName}).Port = $Peer.Port
                                        $PeerUpdate = $True
                                    } elseif (!($Peers | ? {$_.Name -eq $RegisterRigName})) {
                                        $Peers += $Peer
                                        $PeerUpdate = $True
                                    }
                                    
                                    $PeerPing = 
                                    If ( $Peer.Name -eq $Config.WorkerName ) {
                                        $True
                                    } Else {
                                        Try { (Invoke-WebRequest "http://$($Peer.IP):$($Peer.Port)/ping" -Credential $Variables.ServerClientCreds -TimeoutSec 3).content -eq "Server Alive" } Catch {$False}
                                    }
                                    
                                    If ($PeerUpdate -and $PeerPing) {
                                        $Peers | convertto-json | out-file ".\Config\Peers.json"
                                        If ($RegisterRigName -ne $Config.WorkerName -and !$RegisterBackRegistrationNotAllowed){
                                            # Back registration won't work until we switch the listener to ASync
                                            # Try { (Invoke-WebRequest "http://$($Peer.IP):$($Peer.Port)/RegisterRig/?Name=$($Config.WorkerName)&Port=$($Config.Server_Port)&RegisterBackRegistrationNotAllowed=true" -Credential $Variables.ServerClientCreds -TimeoutSec 3).content -eq "Server Alive" } Catch {$False}
                                        }

                                        $Content = "$($Peer.Name)`n$($Peer.IP)`n$($Peer.Port)"
                                        $StatusCode  = [System.Net.HttpStatusCode]::OK
                                    } Else {
                                        $StatusCode = 404
                                        $Content = "Peer not responding"
                                    }
                                }
                                $Peers = $Null
                                Break
                        }
                        "/ping" {
                                $ContentType = "text/html"
                                $Content = "Server Alive"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/ClearCache" {
                                $ContentType = "text/html"
                                $CacheHits = 0
                                $WebHits = 0
                                rv ProxyCache
                                [System.Collections.ArrayList]$ProxyCache = @()
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/ExportCache" {
                                $ContentType = "text/html"
                                $ProxyCache | convertto-json | Out-File ".\logs\ProxyCache.json"
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Config.json" {
                                $Title = "Config.json"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".json"]
                                $Content = $Config | ConvertTo-Json -Depth 10
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Variables.json" {
                                $Title = "Variables.json"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".json"]
                                $Content = $Variables | ConvertTo-Json -Depth 10
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Earnings.json" {
                                $Title = "Earnings.json"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".json"]
                                $Content = $Variables.Earnings | ConvertTo-Json -Depth 10
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/RunningMiners.json" {
                                $Title = "RunningMiners.json"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".json"]
                                $Content = $Variables.ActiveMinerPrograms.Clone().Where( {$_.Status -eq "Running"} ) | Sort Type | ConvertTo-Json -Depth 10
                                If ($Variables.Paused) {
                                    $Content = [PSCustomObject]@{
                                        Type = "Paused"
                                    } | ConvertTo-Json
                                }
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Benchmarks.json" {
                                $Title = "Benchmarks.json"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".json"]
                                $Content = $Variables.Miners | ConvertTo-Json -Depth 10
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Peers.json" {
                                $Title = "Peers.json"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".json"]
                                If (Test-Path ".\Config\Peers.json") {$Content = Get-Content ".\Config\Peers.json" -Raw}
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Status" {
                                $Title = "Status"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".html"]

                                $EarningsTrends = [PSCustomObject]@{}
                                $TrendSign = switch ([Math]::Round((($Variables.Earnings.Values | measure -Property Growth1 -Sum).sum*1000*24),3) - [Math]::Round((($Variables.Earnings.Values | measure -Property Growth6 -Sum).sum*1000*4),3)) {
                                        {$_ -eq 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/metro/26/000000/equal-sign-2.png alt="" ""  width=""16"">"}
                                        {$_ -gt 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/color/26/000000/bullish.png alt="" ""  width=""16"">"}
                                        {$_ -lt 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/color/26/000000/bearish.png alt="" ""  width=""16"">"}
                                    }
                                $EarningsTrends | Add-Member -Force @{"Last  1h $TrendSign" = ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth1 -Sum).sum 24)).DisplayStringPerDay}
                                $TrendSign = switch ([Math]::Round((($Variables.Earnings.Values | measure -Property Growth6 -Sum).sum*1000*4),3) - [Math]::Round((($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum*1000),3)) {
                                        {$_ -eq 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/metro/26/000000/equal-sign-2.png alt="" ""  width=""16"">"}
                                        {$_ -gt 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/color/26/000000/bullish.png alt="" ""  width=""16"">"}
                                        {$_ -lt 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/color/26/000000/bearish.png alt="" ""  width=""16"">"}
                                    }
                                $EarningsTrends | Add-Member -Force @{"Last  6h $TrendSign" = ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth6 -Sum).sum 4)).DisplayStringPerDay}
                                $TrendSign = switch ([Math]::Round((($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum*1000),3) - [Math]::Round((($Variables.Earnings.Values | measure -Property BTCD -Sum).sum*1000*0.96),3)) {
                                        {$_ -eq 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/metro/26/000000/equal-sign-2.png alt="" ""  width=""16"">"}
                                        {$_ -gt 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/color/26/000000/bullish.png alt="" ""  width=""16"">"}
                                        {$_ -lt 0}
                                            {"&nbsp&nbsp<img src=https://img.icons8.com/color/26/000000/bearish.png alt="" ""  width=""16"">"}
                                    }
                                $EarningsTrends | Add-Member -Force @{"Last  24h $TrendSign" = ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum)).DisplayStringPerDay}
                                    $Header += $EarningsTrends | ConvertTo-Html -CssUri "./Includes/Web.css" 

                                If (Test-Path ".\logs\DailyEarnings.csv"){
                                    $Chart1 = Invoke-Expression -Command ".\Includes\Charting.ps1 -Chart 'Front7DaysEarnings' -Width 505 -Height 85 -Currency $($Config.Passwordcurrency)"
                                    $Chart2 = Invoke-Expression -Command ".\Includes\Charting.ps1 -Chart 'DayPoolSplit' -Width 200 -Height 85 -Currency $($Config.Passwordcurrency)"


                                    $Header +=
@"
                        <hr>
                        <SectionTitle>
                        Earnings Tracker
                        </SectionTitle>
                        <br>
                        <EarningsCharts>
                        <table>
                        <tbody>
                        <tr>
                        <th>Past 7 days earnings</th>
                        <th>Per pool earnings</th>
                        </tr>
                        <tr>
                        <td>
                            <img src=./Logs/Front7DaysEarnings.png>
                        </td>
                        <td>
                            <img src=./Logs/DayPoolSplit.png>
                        </td>
                        </tr>
                        </tbody>
                        </table><br>
                        </EarningsCharts>
"@
                                }
                                
                                If ($Variables.Earnings -and $Config.TrackEarnings) {
                                    $DisplayEarnings = [System.Collections.ArrayList]@($Variables.Earnings.Values | select @(
                                        @{Name="Pool";Expression={"<img src=""$(Get-PoolIcon ($_.Pool))"" alt="" "" width=""16""></img>&nbsp&nbsp" +$_.Pool}},
                                        @{Name="Trust";Expression={"{0:P0}" -f $_.TrustLevel}},
                                        @{Name="Balance";Expression={$_.Balance}},
                                        # @{Name="Unpaid";Expression={$_.total_unpaid}},
                                        # @{Name="BTC/D";Expression={"{0:N8}" -f ($_.BTCD)}},
                                        @{Name="1h $((Get-DisplayCurrency $_.Growth1 24).UnitStringPerDay)";Expression={(Get-DisplayCurrency $_.Growth1 24).RoundedValue}},
                                        @{Name="6h $((Get-DisplayCurrency $_.Growth6 4).UnitStringPerDay)";Expression={(Get-DisplayCurrency $_.Growth6 4).RoundedValue}},
                                        @{Name="24h $((Get-DisplayCurrency $_.Growth24).UnitStringPerDay)";Expression={(Get-DisplayCurrency $_.Growth24).RoundedValue}},

                                        @{Name = "Est. Pay Date"; Expression = {if ($_.EstimatedPayDate -is 'DateTime') {$_.EstimatedPayDate.ToShortDateString()} else {$_.EstimatedPayDate}}},

                                        @{Name="PaymentThreshold";Expression={"$($_.PaymentThreshold) ($('{0:P0}' -f $($_.Balance / $_.PaymentThreshold)))"}}#,
                                        # @{Name="Wallet";Expression={$_.Wallet}}
                                    ) | Sort "1h $((Get-DisplayCurrency $_.Growth1 24).UnitStringPerDay)","6h $((Get-DisplayCurrency $_.Growth6 4).UnitStringPerDay)","24h $((Get-DisplayCurrency $_.Growth24).UnitStringPerDay)" -Descending)
                                    $DisplayEarnings = [System.Collections.ArrayList]@($DisplayEarnings) | ConvertTo-Html -CssUri "./Includes/Web.css" -Title $Title -PreContent $Header
                                    $Content = [System.Web.HttpUtility]::HtmlDecode($DisplayEarnings)
                                }
                                $Content += 
@"
                        <hr>
                        <SectionTitle>
                        Running Miners
                        </SectionTitle>
                        <br>
"@
                                
                                If (Test-Path ".\Config\Peers.json") {
                                    $Peers = Get-Content ".\Config\Peers.json" | ConvertFrom-Json
                                } Else {
                                    $Peers = @([PSCustomObject]@{ Name = $Config.WorkerName ; IP = "127.0.0.1" ; Port = $Config.Server_Port })
                                }
                                $Miners = @()
                                $Peers | foreach {
                                    $Peer = $_
                                    If ($Peer.Name -eq $Config.WorkerName) {
                                        $Miners += $Variables.ActiveMinerPrograms.Clone().Where( {$_.Status -eq "Running"} ) | select @{Name = "Rig";Expression={$Peer.Name}},*
                                    } else {
                                        $Miners += (Invoke-WebRequest "http://$($Peer.IP):$($Peer.Port)/RunningMiners.json" -Credential $Variables.ServerCreds -TimeoutSec 5 | ConvertFrom-Json) | select @{Name = "Rig";Expression={$Peer.Name}},*
                                    }
                                }
                                $MinersTable = [System.Collections.ArrayList]@($Miners | select @(
                                            @{Name = "Rig";Expression={$_.Rig}},
                                            @{Name = "Type";Expression={$_.Type}},
                                            @{Name = "Algorithm";Expression={$_.Algorithms}},
                                            # @{Name = "Coin"; Expression={"###CoinIcon###$($_.Coin.ToLower())###IconSize###" + $_.Coin}},
                                            # @{Name = "Coin"; Expression={If($_.Coin -and $_.Coin -ne ""){"<img src=""$(Get-CoinIcon ($_.Coin.ToString() -Replace '-.*', ''))"" alt="" "" width=""16""></img>&nbsp&nbsp" + $_.Coin}else{""}}},
                                            @{Name = "Coin"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {
                                                Try {
                                                    "<img src=""$(Get-CoinIcon ($_.Coin.ToString() -Replace '-.*', ''))"" alt="" "" width=""16""></img>&nbsp&nbsp" + $_.Coin
                                                } Catch {""}
                                            }}},
                                            @{Name = "Miner";Expression={$_.Name}},
                                            @{Name = "HashRate";Expression={"$($_.HashRate | ConvertTo-Hash)/s"}},
                                            @{Name = "Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f [TimeSpan]$_.Active.Ticks}},
                                            @{Name = "Total Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f [TimeSpan]$_.TotalActive.Ticks}},
                                            # @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)"}}} ) | sort Rig,Type
                                            @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"<img src=""$(Get-PoolIcon ($_.Name))"" alt="" "" width=""16""></img>&nbsp&nbsp" + $_.Name}}} ) | sort Rig,Type
                                        ) | ConvertTo-Html -CssUri "./Includes/Web.css"
                                # $MinersTable = $MinersTable -Replace "###CoinIcon###", "<img src=""https://cryptoicons.org/api/icon/"
                                # $MinersTable = $MinersTable -Replace "###IconSize###", "/16"" alt="" ""></img>&nbsp&nbsp"
                                
                                $MinersTable = [System.Web.HttpUtility]::HtmlDecode($MinersTable)
                                 
                                # $MinersTable = [regex]::Replace($MinersTable,'###CoinIcon###(.*)###IconSize###',{param($match) "<img src=""$(Get-CoinIcon $match.Groups[1].Value)"" alt="" ""></img>&nbsp&nbsp"})
                               
                                $Content += $MinersTable
                                
                                ForEach ($Type in ($Miners.Type | Sort -Unique)) {
                                    $Content = $Content -Replace "<td>$($Type)</td>", "<td><img src=""$(ConvertTo-ImagePath $Type)"" alt="" "" width=""16""></img>&nbsp&nbsp$($Type)</td>"
                                }
                                
                                $Content += $Footer
                                $Content = [System.Web.HttpUtility]::HtmlDecode($Content)

                                # $Content = $Header + $Content
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/RunningMiners" { 
                                $Title = "Running Miners"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".html"]
                                $Content = [System.Collections.ArrayList]@($Variables.ActiveMinerPrograms.Clone() | ? {$_.Status -eq "Running"} | select @(
                                    @{Name = "Type";Expression={$_.Type}},
                                    @{Name = "Algorithm";Expression={$_.Algorithms}},
                                    @{Name = "Coin"; Expression={$_.Coin}},
                                    @{Name = "Miner";Expression={$_.Name}},
                                    @{Name = "HashRate";Expression={"$($_.HashRate | ConvertTo-Hash)/s"}},
                                    @{Name = "Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f $_.Active}},
                                    @{Name = "Total Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f $_.TotalActive}},
                                    # @{Name = "Host";Expression={$_.Host}},
                                    @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)"}}}
                                    ) | sort Type
                                ) | ConvertTo-Html -CssUri "./Includes/Web.css" -Title $Title -PreContent $Header
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/PeersRunningMiners" {
                                $Title = "Peers Running Miners"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".html"]

                                If (Test-Path ".\Config\Peers.json") {
                                    $Peers = Get-Content ".\Config\Peers.json" | ConvertFrom-Json
                                } Else {
                                    $Peers = @([PSCustomObject]@{ Name = $Config.WorkerName ; IP = "127.0.0.1" ; Port = $Config.Server_Port })
                                }
                                $Miners = @()
                                
                                $Peers | foreach {
                                    $Peer = $_
                                    If ($Peer.Name -eq $Config.WorkerName) {
                                        $Miners += $Variables.ActiveMinerPrograms.Clone() | ? {$_.Status -eq "Running"} | select @{Name = "Rig";Expression={$Peer.Name}},*
                                    } else {
                                        $Miners += (Invoke-WebRequest "http://$($Peer.IP):$($Peer.Port)/RunningMiners.json" -Credential $Variables.ServerCreds | ConvertFrom-Json) | select @{Name = "Rig";Expression={$Peer.Name}},*
                                    }
                                }
                                $MinersTable = [System.Collections.ArrayList]@($Miners | select @(
                                            @{Name = "Rig";Expression={$_.Rig}},
                                            @{Name = "Type";Expression={$_.Type}},
                                            @{Name = "Algorithm";Expression={$_.Algorithms}},
                                            @{Name = "Coin"; Expression={"###CoinIcon###$($_.Coin.ToLower())###IconSize###" + $_.Coin}},
                                            @{Name = "Miner";Expression={$_.Name}},
                                            @{Name = "HashRate";Expression={"$($_.HashRate | ConvertTo-Hash)/s"}},
                                            @{Name = "Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f [TimeSpan]$_.Active.Ticks}},
                                            @{Name = "Total Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f [TimeSpan]$_.TotalActive.Ticks}},
                                            @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)"}}} ) | sort Rig,Type
                                        ) | ConvertTo-Html -CssUri "./Includes/Web.css" -Title $Title -PreContent $Header
                                $MinersTable = $MinersTable -Replace "###CoinIcon###", "<img src=""https://cryptoicons.org/api/icon/"
                                $MinersTable = $MinersTable -Replace "###IconSize###", "/16"" alt="" ""></img>&nbsp&nbsp"
                                $Content = $MinersTable
                                # $Content = $Header + $Content
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Benchmarks" { 
                                $Title = "Benchmarks"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                If (!$Variables.CoinsIconCacheLoaded -and !$Variables.CoinsIconCachePopulating) {Load-CoinsIconsCache}

                                $ContentType = $MIMETypes[".html"]
                                $Content = $Header
                                $Content += "<hr>"
                                
                                $Miners = $Variables["Miners"].Clone()
                                
                                ForEach ($Type in ($Miners.Type | Sort -Unique -Descending)) {
                                    $Content += "<img src=""$(ConvertTo-ImagePath $Type)"" alt="" "" width=""16""></img>&nbsp&nbsp<a href=""#$($Type)"">$($Type)</a>&nbsp&nbsp&nbsp&nbsp"
                                }
                                
                                ForEach ($Type in ($Miners.Type | Sort -Unique -Descending)) {
                                    $Content +=
@"
                        <hr>
                        <div id="$($Type)"></div>
                        <SectionTitle>
                        <span class="left"><img src="$(ConvertTo-ImagePath $Type)" alt=" " width="16"></img>&nbsp&nbsp$($Type)</span><span class="right"><a href="#"><img src="$(ConvertTo-ImagePath 'Top')" alt=" " width="16"></img></a></span><br>
                        </SectionTitle>
                        <br>
"@

                                    $DisplayEstimations = [System.Collections.ArrayList]@($Miners.Where( {$_.Type -eq $Type} ) | sort $_.Profits.PSObject.Properties.Value -Descending | Select @(
                                        @{Name = "Type";Expression={$_.Type}},
                                        @{Name = "Miner";Expression={$_.Name}},
                                        @{Name = "Algorithm";Expression={$_.HashRates.PSObject.Properties.Name}},
                                        # @{Name = "Coin"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Coin)"}}},
                                        @{Name = "Coin"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {
                                            If($Variables.CoinsIconCacheLoaded) {
                                                Try {
                                                    "<img src=""$(Get-CoinIcon ($_.Coin.ToString() -Replace '-.*', ''))"" alt="" "" width=""16""></img>&nbsp&nbsp" + $_.Coin
                                                } Catch {$_.Coin}
                                            }else{$_.Coin}
                                        }}},
                                        # @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)"}}},
                                                @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"<img src=""$(Get-PoolIcon ($_.Name))"" alt="" "" width=""16""></img>&nbsp&nbsp" + $_.Name}}},
                                        @{Name = "Speed"; Expression={$_.HashRates.PSObject.Properties.Value | ForEach {if($_ -ne $null){"$($_ | ConvertTo-Hash)/s"}else{"Benchmarking"}}}},
                                        # @{Name = "mBTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){($_*1000).ToString("N3")}else{"Benchmarking"}}}},
                                        @{Name = "mBTC/Day"; Expression={(($_.Profits.PSObject.Properties.Value | Measure -Sum).Sum *1000).ToString("N3")}},
                                        # @{Name = "BTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){$_.ToString("N5")}else{"Benchmarking"}}}},
                                        # @{Name = "BTC/Day"; Expression={(($_.Profits.PSObject.Properties.Value | Measure -Sum).Sum).ToString("N3")}},
                                        # @{Name = "BTC/GH/Day"; Expression={$_.Pools.PSObject.Properties.Value.Price | ForEach {($_*1000000000).ToString("N15")}}}
                                        @{Name = "BTC/GH/Day"; Expression={(($_.Pools.PSObject.Properties.Value.Price | Measure -Sum).Sum *1000000000).ToString("N5")}}
                                    # ) | sort "mBTC/Day" -Descending) | ConvertTo-Html -CssUri "http://$($Config.Server_ClientIP):$($Config.Server_ClientPort)/Includes/Web.css" -Title $Title -PreContent $Header
                                    ) | sort "mBTC/Day" -Descending)

                                    $DisplayEstimations = If ($Config.ShowOnlyTopCoins){
                                        [System.Collections.ArrayList]@($DisplayEstimations | sort "mBTC/Day" -Descending | Group "Type","Algorithm" | % { $_.Group | select -First 1})
                                    } else {
                                        $DisplayEstimations 
                                    }
                                    
                                    $Content += $DisplayEstimations | ConvertTo-Html -CssUri "./Includes/Web.css" -Title $Title
                                
                                }
                                
                                ForEach ($Type in ($Miners.Type | Sort -Unique)) {
                                    $Content = $Content -Replace "<td>$($Type)</td>", "<td><img src=""$(ConvertTo-ImagePath $Type)"" alt="" "" width=""16""></img>&nbsp&nbsp$($Type)</td>"
                                }
                                $Content += $Footer
                                $Content = [System.Web.HttpUtility]::HtmlDecode($Content)

                                $StatusCode  = [System.Net.HttpStatusCode]::OK


                                Break
                        }
                        "/SwitchingLog" {
                                $Title = "SwitchingLog"
                                $ContentType = $MIMETypes[".html"]

                                If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(@((get-content ".\Logs\switching.log" -First 1) , (get-content ".\logs\switching.log" -last 15)) | ConvertFrom-Csv | Select date,type,algo,coin,host -Last 13)}
                                $Content = $SwitchingArray | ConvertTo-Html -CssUri "./Includes/Web.css" -Title $Title -PreContent $Header
                                
                                $Content += $Footer 
                                
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Cmd-CleanIconCache" {
                                $ContentType = "text/html"
                                $Variables.CoinIcons = @()
                                $Variables.CoinsIconCacheLoaded = $False
                                $Variables.CoinsIconCachePopulating = $False
                                
                                $Title = "CleanIconCache"
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Cmd-Pause" {
                                $ContentType = "text/html"
                                $Variables.StatusText = "Pause Mining requested via API."
                                $Variables.Paused = $True
                                $Variables.RestartCycle = $True
                                
                                $Title = "Pause Command"
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Cmd-Mine" {
                                $ContentType = "text/html"
                                $Variables.StatusText = "Start Mining requested via API."
                                $Variables.Paused = $False
                                $Variables.LastDonated = (Get-Date).AddDays(-1).AddHours(1)
                                $Variables.RestartCycle = $True
                                
                                $Title = "Mine Command"
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        "/Cmd-ResetPeers" {
                                $ContentType = "text/html"
                                If (Test-Path ".\Config\Peers.json") {Remove-Item -Recurse -Force ".\Config\Peers.json"}
                                
                                $Title = "Peers Reset"
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                                Break
                        }
                        default { 
                            # Set index page
                            if ($Path -eq "/") { 
                                $Path = "/index.html"
                            }

                            # Check if there is a file with the requested path
                            $Filename = $BasePath + $Path
                            if (Test-Path $Filename -PathType Leaf -ErrorAction SilentlyContinue) { 
                                # If the file is a powershell script, execute it and return the output. A $Parameters parameter is sent built from the query string
                                # Otherwise, just return the contents of the file
                                $File = Get-ChildItem $Filename

                                if ($File.Extension -eq ".ps1") { 
                                    $Content = & $File.FullName -Parameters $Parameters
                                }
                                else { 
                                    $Content = Get-Content $Filename -Raw

                                    # Process server side includes for html files
                                    # Includes are in the traditional '<!-- #include file="/path/filename.html" -->' format used by many web servers
                                    if ($File.Extension -eq ".html") { 
                                        $IncludeRegex = [regex]'<!-- *#include *file="(.*)" *-->'
                                        $IncludeRegex.Matches($Content) | Foreach-Object { 
                                            $IncludeFile = $BasePath + '/' + $_.Groups[1].Value
                                            if (Test-Path $IncludeFile -PathType Leaf) { 
                                                $IncludeData = Get-Content $IncludeFile -Raw
                                                $Content = $Content -replace $_.Value, $IncludeData
                                            }
                                        }
                                    }
                                }

                                # Set content type based on file extension
                                if ($MIMETypes.ContainsKey($File.Extension)) { 
                                    $ContentType = $MIMETypes[$File.Extension]
                                    Switch ($File.Extension) {
                                        ".png"     {$Content = [System.IO.File]::ReadAllBytes($File.FullName)}
                                    }
                                }
                                else { 
                                    # If it's an unrecognized file type, prompt for download
                                    $ContentType = "application/octet-stream"
                                }
                            }
                            else { 
                                $StatusCode = 404
                                $ContentType = "text/html"
                                $Content = "URI '$Path' is not a valid resource. ($Filename)"
                            }
                        }
                    }
                    $HasContent = $content -ne $null

                    If ($Content.GetType() -ne [byte[]]) {
                        [byte[]] $Buf = [System.Text.Encoding]::UTF8.GetBytes($Content)
                    } Else {
                        [byte[]] $Buf = $Content
                    }

                    # $Buf = [Text.Encoding]::UTF8.GetBytes($Content)
                    $Hres.Headers.Add("Content-Type", $ContentType)
                    $HRes.ContentLength64 = $Buf.Length
                    $HRes.OutputStream.Write($Buf,0,$Buf.Length)
                    $HRes.OutputStream.Flush()
                    $HRes.OutputStream.Dispose()
                    $HRes.Close()
                    $Content = $null
                    $Buf = $null
                    # $ProxyCache | convertto-json | Out-File ".\logs\ProxyCache.json"
                }
                if ($Config.Server_Log) {
                    $LogEntry = [PSCustomObject]@{
                        CacheHitRatio = $CacheHitsRatio
                        StatusCode = $StatusCode.value__
                        Date = Get-date
                        ClientAddress = $ClientAddress
                        ClientPort = $ClientPort
                        Path = $Path
                        URL = $ProxURL
                        Content = $HasContent
                        AuthSuccess = $AuthSuccess
                        pid = $pid
                    }
                    $LogEntry | Export-Csv ".\Logs\Server.log" -NoTypeInformation -Append
                    rv LogEntry
                    $ProxURL = ""
                }
                $HCTemp = $null
            }
        Write-Host "Server stopping"
        $ServerListener.Stop()
        $ServerListener.Close()
        # $Variables.Server.Runspace.Close()
        # $Variables.Server.Dispose()

    })
    $Server.Runspace = $ServerRunspace
    # $Variables.Server | Add-Member -Force @{ServerListener = $ServerListener}
    $Variables.ServerRunspaceHandle = $Server.BeginInvoke()
}

