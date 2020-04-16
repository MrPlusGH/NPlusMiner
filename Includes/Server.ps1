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
            ".json" = "application/json"
            ".css"  = "text/css"
            ".txt"  = "text/plain"
            ".ico"  = "image/x-icon"
            ".ps1"  = "text/html" # ps1 files get executed, assume their response is html
        }

        # Load Branding
        If (Test-Path ".\Config\Branding.json") {
            $Branding = Get-Content ".\Config\Branding.json" | ConvertFrom-Json
        } Else {
            $Branding = [PSCustomObject]@{
                LogoPath = "https://raw.githubusercontent.com/MrPlusGH/NPlusMiner/master/Includes/NPM.png"
                BrandName = "NPlusMiner"
                BrandWebSite = "https://github.com/MrPlusGH/NPlusMiner"
                ProductLable = "NPlusMiner"
            }
        }

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
            While ($ServerListener.IsListening) {
                if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}
                $HC = $ServerListener.GetContext()
                $HReq = $HC.Request
                # $Hreq | Out-Host
                # $Hreq | convertto-json -Depth 10 | Out-File ".\Logs\HReq.json"
                $Path = $Hreq.Url.LocalPath
                $ClientAddress = $Hreq.RemoteEndPoint.Address
                $ClientPort = $Hreq.RemoteEndPoint.Port
                $HRes = $HC.Response
                $HRes.Headers.Add("Content-Type","text/html")      
                
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
                    $StatusCode  = [System.Net.HttpStatusCode]::Unauthorized
                    $ContentType = "text/html"
                    $AuthSuccess = $False
                } else {
                    $Header =
@"
                        <header>
                        <img src=$($Branding.LogoPath)>
                        Copyright (c) 2018-2020 MrPlus    ++ $(Get-Date) ++ $($Branding.ProductLable) $($Variables.CurrentVersion) ++ Runtime $(("{0:dd\ \d\a\y\s\ hh\:mm}" -f ((get-date)-$Variables.ScriptStartDate))) ++ Path: $($BasePath)
                        </header>
"@
                    
                    $AuthSuccess = $True
                    $HReq.RawUrl | write-Host
                    Switch($Path) {
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
                        }
                        "/ping" {
                                $Content = "Server Alive"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                        }
                        "/ClearCache" {
                                $CacheHits = 0
                                $WebHits = 0
                                rv ProxyCache
                                [System.Collections.ArrayList]$ProxyCache = @()
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                        }
                        "/ExportCache" {
                                $ProxyCache | convertto-json | Out-File ".\logs\ProxyCache.json"
                                $Content = "OK"
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                        }
                        "/RunningMiners" {
                                $Title = "Running Miners"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"
                                $ContentType = $MIMETypes[".html"]
                                $Content = $Variables.ActiveMinerPrograms | ? {$_.Status -eq "Running"} | select Type,Algorithms,Coin,Name,@{Name="HashRate";Expression={"$($_.HashRate | ConvertTo-Hash)/s"}},@{Name="Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f $_.Active}},@{Name="Total Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f $_.TotalActive}},Host | sort Type | ConvertTo-Html -CssUri "http://$($Config.Server_ClientIP):$($Config.Server_ClientPort)/Includes/Web.css" -Title $Title -PreContent $Header
                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                        }
                        "/Benchmarks" {
                                $Title = "Benchmarks"
                                # $Content = ConvertTo-Html -CssUri "file:///d:/Nplusminer/Includes/Web.css " -Title $Title -Body "<h1>$Title</h1>`n<h5>Updated: on $(Get-Date)</h5>"

                                $ContentType = $MIMETypes[".html"]
                                $Content = [System.Collections.ArrayList]@($Variables.Miners | Select @(
                                    @{Name = "Type";Expression={$_.Type}},
                                    @{Name = "Miner";Expression={$_.Name}},
                                    @{Name = "Algorithm";Expression={$_.HashRates.PSObject.Properties.Name}},
                                    @{Name = "Coin"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Info)"}}},
                                    @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)"}}},
                                    @{Name = "Speed"; Expression={$_.HashRates.PSObject.Properties.Value | ForEach {if($_ -ne $null){"$($_ | ConvertTo-Hash)/s"}else{"Benchmarking"}}}},
                                    # @{Name = "mBTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){($_*1000).ToString("N3")}else{"Benchmarking"}}}},
                                    @{Name = "mBTC/Day"; Expression={(($_.Profits.PSObject.Properties.Value | Measure -Sum).Sum *1000).ToString("N3")}},
                                    # @{Name = "BTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){$_.ToString("N5")}else{"Benchmarking"}}}},
                                    @{Name = "BTC/Day"; Expression={(($_.Profits.PSObject.Properties.Value | Measure -Sum).Sum).ToString("N3")}},
                                    # @{Name = "BTC/GH/Day"; Expression={$_.Pools.PSObject.Properties.Value.Price | ForEach {($_*1000000000).ToString("N15")}}}
                                    @{Name = "BTC/GH/Day"; Expression={(($_.Pools.PSObject.Properties.Value.Price | Measure -Sum).Sum *1000000000).ToString("N5")}}
                                ) | sort "mBTC/Day" -Descending) | ConvertTo-Html -CssUri "http://$($Config.Server_ClientIP):$($Config.Server_ClientPort)/Includes/Web.css" -Title $Title -PreContent $Header


                                $StatusCode  = [System.Net.HttpStatusCode]::OK
                        }
                        "/Cmd-Pause" {
                                    $Variables.StatusText = "Pause Mining requested via API."
                                    $Variables.Paused = $True
                                    $Variables.RestartCycle = $True
                                    
                                    $Title = "Pause Command"
                                    $Content = "OK"
                                    $StatusCode  = [System.Net.HttpStatusCode]::OK
                        }
                        "/Cmd-Mine" {
                                    $Variables.StatusText = "Start Mining requested via API."
                                    $Variables.Paused = $False
                                    $Variables | Add-Member -Force @{LastDonated = (Get-Date).AddDays(-1).AddHours(1)}
                                    $Variables.RestartCycle = $True
                                    
                                    $Title = "Mine Command"
                                    $Content = "OK"
                                    $StatusCode  = [System.Net.HttpStatusCode]::OK
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
                    $Buf = [Text.Encoding]::UTF8.GetBytes($Content)
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
                }
            }
        $Hso.Stop()

    })
    $Server.Runspace = $ServerRunspace
    $Handle = $Server.BeginInvoke()

}

