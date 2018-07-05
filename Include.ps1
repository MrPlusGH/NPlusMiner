<#
This file is part of NPlusMiner
Copyright (c) 2018 Nemo
Copyright (c) 2018 MrPlus

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
File:           include.ps1
version:        4.0
version date:   20180703
#>

# New-Item -Path function: -Name ((Get-FileHash $MyInvocation.MyCommand.path).Hash) -Value {$true} -EA SilentlyContinue | out-null
# Get-Item function::"$((Get-FileHash $MyInvocation.MyCommand.path).Hash)" | Add-Member @{"File" = $MyInvocation.MyCommand.path} -EA SilentlyContinue
 
Function Global:RegisterLoaded ($File) {
    New-Item -Path function: -Name Script:"$((Get-FileHash (Resolve-Path $File)).Hash)" -Value {$true} -EA SilentlyContinue | out-null
    Get-Item function::"$((Get-FileHash (Resolve-Path $File)).Hash)" | Add-Member @{"File" = (Resolve-Path $File).Path} -EA SilentlyContinue
    $Variables.StatusText = "File loaded - $($file) - $((Get-PSCallStack).Command[1])"
}
    
Function Global:IsLoaded ($File) {
    $Hash = (Get-FileHash (Resolve-Path $File).Path).hash
    If (Test-Path function::$Hash) {
        $True
    }
    else {
        ls function: | ? {$_.File -eq (Resolve-Path $File).Path} | Remove-Item
        $false
    }
}

Function Update-Status ($Text) {
    $Text | out-host
    # $Variables.StatusText = $Text 
    $LabelStatus.Lines += $Text
    If ($LabelStatus.Lines.Count -gt 20) {$LabelStatus.Lines = $LabelStatus.Lines[($LabelStatus.Lines.count - 10)..$LabelStatus.Lines.Count]}
    $LabelStatus.SelectionStart = $LabelStatus.TextLength;
    $LabelStatus.ScrollToCaret();
    $LabelStatus.Refresh | out-null
}

Function Update-Notifications ($Text) {
    $LabelNotifications.Lines += $Text
    If ($LabelNotifications.Lines.Count -gt 20) {$LabelNotifications.Lines = $LabelNotifications.Lines[($LabelNotifications.Lines.count - 10)..$LabelNotifications.Lines.Count]}
    $LabelNotifications.SelectionStart = $LabelStatus.TextLength;
    $LabelNotifications.ScrollToCaret();
    $LabelStatus.Refresh | out-null
}

Function DetectGPUCount {
    Update-Status("Fetching GPU Count")
    try {
        $DetectedGPU = @(Get-WmiObject Win32_PnPSignedDriver | Select DeviceName, DriverVersion, Manufacturer, DeviceClass | Where { $_.Manufacturer -like "*NVIDIA*" -and $_.DeviceClass -like "*display*"}) 
    }
    catch { $DetectedGPU = @()}
    $DetectedGPUCount = $DetectedGPU.Count
    # $DetectedGPUCount = @(Get-WmiObject Win32_PnPSignedDriver | Select DeviceName,DriverVersion,Manufacturer,DeviceClass | Where { $_.Manufacturer -like "*NVIDIA*" -and $_.DeviceClass -like "*display*"}).count } catch { $DetectedGPUCount = 0}
    $i = 0
    $DetectedGPU | foreach {Update-Status("$($i): $($_.DeviceName)") | Out-Null; $i++}
    Update-Status("Found $($DetectedGPUCount) GPU(s)")
    $DetectedGPUCount
}

Function Load-Config {
    param(
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile
    )
    If (Test-Path $ConfigFile) {
        $ConfigLoad = Get-Content $ConfigFile | ConvertFrom-json
        $Config = [hashtable]::Synchronized(@{}); $configLoad | % {$_.psobject.properties | sort Name | % {$Config | Add-Member -Force @{$_.Name = $_.Value}}}
        $Config
    }
}

Function Write-Config {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        [Parameter(Mandatory = $true)]
        [String]$ConfigFile
    )
    If ($Config.ManualConfig) {Update-Status("Manual config mode - Not saving config"); return}
    If ($Config -ne $null) {
        if (Test-Path $ConfigFile) {Copy-Item $ConfigFile "$($ConfigFile).backup"}
        $OrderedConfig = [PSCustomObject]@{}; ($config | select -Property * -ExcludeProperty PoolsConfig) | % {$_.psobject.properties | sort Name | % {$OrderedConfig | Add-Member -Force @{$_.Name = $_.Value}}}
        $OrderedConfig | ConvertTo-json | out-file $ConfigFile
        $PoolsConfig = Get-Content ".\Config\PoolsConfig.json" | ConvertFrom-Json
        $OrderedPoolsConfig = [PSCustomObject]@{}; $PoolsConfig | % {$_.psobject.properties | sort Name | % {$OrderedPoolsConfig | Add-Member -Force @{$_.Name = $_.Value}}}
        $OrderedPoolsConfig.default | Add-member -Force @{Wallet = $Config.Wallet}
        $OrderedPoolsConfig.default | Add-member -Force @{UserName = $Config.UserName}
        $OrderedPoolsConfig.default | Add-member -Force @{WorkerName = $Config.WorkerName}
        $OrderedPoolsConfig.default | Add-member -Force @{APIKey = $Config.APIKey}
        $OrderedPoolsConfig | ConvertTo-json | out-file ".\Config\PoolsConfig.json"
    }
}

Function Get-FreeTcpPort ($StartPort) {
    # While ($Port -le ($StartPort + 10) -and !$PortFound) {try{$Null = New-Object System.Net.Sockets.TCPClient -ArgumentList 127.0.0.1,$Port;$Port++} catch {$Port;$PortFound=$True}}
    # $UsedPorts = (Get-NetTCPConnection | ? {$_.state -eq "listen"}).LocalPort
    # While ($StartPort -in $UsedPorts) {
    While (Get-NetTCPConnection -LocalPort $StartPort -EA SilentlyContinue) {$StartPort++}
    $StartPort
}

function Set-Stat {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name, 
        [Parameter(Mandatory = $true)]
        [Double]$Value, 
        [Parameter(Mandatory = $false)]
        [DateTime]$Date = (Get-Date)
    )

    $Path = "Stats\$Name.txt"
    $Date = $Date.ToUniversalTime()
    $SmallestValue = 1E-20

    $Stat = [PSCustomObject]@{
        Live = $Value
        Minute = $Value
        Minute_Fluctuation = 1 / 2
        Minute_5 = $Value
        Minute_5_Fluctuation = 1 / 2
        Minute_10 = $Value
        Minute_10_Fluctuation = 1 / 2
        Hour = $Value
        Hour_Fluctuation = 1 / 2
        Day = $Value
        Day_Fluctuation = 1 / 2
        Week = $Value
        Week_Fluctuation = 1 / 2
        Updated = $Date
    }

    if (Test-Path $Path) {$Stat = Get-Content $Path | ConvertFrom-Json}

    $Stat = [PSCustomObject]@{
        Live = [Double]$Stat.Live
        Minute = [Double]$Stat.Minute
        Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
        Minute_5 = [Double]$Stat.Minute_5
        Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
        Minute_10 = [Double]$Stat.Minute_10
        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
        Hour = [Double]$Stat.Hour
        Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
        Day = [Double]$Stat.Day
        Day_Fluctuation = [Double]$Stat.Day_Fluctuation
        Week = [Double]$Stat.Week
        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
        Updated = [DateTime]$Stat.Updated
    }
    
    $Span_Minute = [Math]::Min(($Date - $Stat.Updated).TotalMinutes, 1)
    $Span_Minute_5 = [Math]::Min((($Date - $Stat.Updated).TotalMinutes / 5), 1)
    $Span_Minute_10 = [Math]::Min((($Date - $Stat.Updated).TotalMinutes / 10), 1)
    $Span_Hour = [Math]::Min(($Date - $Stat.Updated).TotalHours, 1)
    $Span_Day = [Math]::Min(($Date - $Stat.Updated).TotalDays, 1)
    $Span_Week = [Math]::Min((($Date - $Stat.Updated).TotalDays / 7), 1)

    $Stat = [PSCustomObject]@{
        Live = $Value
        Minute = ((1 - $Span_Minute) * $Stat.Minute) + ($Span_Minute * $Value)
        Minute_Fluctuation = ((1 - $Span_Minute) * $Stat.Minute_Fluctuation) + 
        ($Span_Minute * ([Math]::Abs($Value - $Stat.Minute) / [Math]::Max([Math]::Abs($Stat.Minute), $SmallestValue)))
        Minute_5 = ((1 - $Span_Minute_5) * $Stat.Minute_5) + ($Span_Minute_5 * $Value)
        Minute_5_Fluctuation = ((1 - $Span_Minute_5) * $Stat.Minute_5_Fluctuation) + 
        ($Span_Minute_5 * ([Math]::Abs($Value - $Stat.Minute_5) / [Math]::Max([Math]::Abs($Stat.Minute_5), $SmallestValue)))
        Minute_10 = ((1 - $Span_Minute_10) * $Stat.Minute_10) + ($Span_Minute_10 * $Value)
        Minute_10_Fluctuation = ((1 - $Span_Minute_10) * $Stat.Minute_10_Fluctuation) + 
        ($Span_Minute_10 * ([Math]::Abs($Value - $Stat.Minute_10) / [Math]::Max([Math]::Abs($Stat.Minute_10), $SmallestValue)))
        Hour = ((1 - $Span_Hour) * $Stat.Hour) + ($Span_Hour * $Value)
        Hour_Fluctuation = ((1 - $Span_Hour) * $Stat.Hour_Fluctuation) + 
        ($Span_Hour * ([Math]::Abs($Value - $Stat.Hour) / [Math]::Max([Math]::Abs($Stat.Hour), $SmallestValue)))
        Day = ((1 - $Span_Day) * $Stat.Day) + ($Span_Day * $Value)
        Day_Fluctuation = ((1 - $Span_Day) * $Stat.Day_Fluctuation) + 
        ($Span_Day * ([Math]::Abs($Value - $Stat.Day) / [Math]::Max([Math]::Abs($Stat.Day), $SmallestValue)))
        Week = ((1 - $Span_Week) * $Stat.Week) + ($Span_Week * $Value)
        Week_Fluctuation = ((1 - $Span_Week) * $Stat.Week_Fluctuation) + 
        ($Span_Week * ([Math]::Abs($Value - $Stat.Week) / [Math]::Max([Math]::Abs($Stat.Week), $SmallestValue)))
        Updated = $Date
    }

    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory"}
    [PSCustomObject]@{
        Live = [Decimal]$Stat.Live
        Minute = [Decimal]$Stat.Minute
        Minute_Fluctuation = [Double]$Stat.Minute_Fluctuation
        Minute_5 = [Decimal]$Stat.Minute_5
        Minute_5_Fluctuation = [Double]$Stat.Minute_5_Fluctuation
        Minute_10 = [Decimal]$Stat.Minute_10
        Minute_10_Fluctuation = [Double]$Stat.Minute_10_Fluctuation
        Hour = [Decimal]$Stat.Hour
        Hour_Fluctuation = [Double]$Stat.Hour_Fluctuation
        Day = [Decimal]$Stat.Day
        Day_Fluctuation = [Double]$Stat.Day_Fluctuation
        Week = [Decimal]$Stat.Week
        Week_Fluctuation = [Double]$Stat.Week_Fluctuation
        Updated = [DateTime]$Stat.Updated
    } | ConvertTo-Json | Set-Content $Path

    $Stat
}

function Get-Stat {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name
    )
    
    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory"}
    Get-ChildItem "Stats" | Where-Object Extension -NE ".ps1" | Where-Object BaseName -EQ $Name | Get-Content | ConvertFrom-Json
}

function Get-ChildItemContent {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [Array]$Include = @()
    )

    $ChildItems = Get-ChildItem -Recurse -Path $Path -Include $Include | ForEach-Object {
        $Name = $_.BaseName
        $Content = @()
        if ($_.Extension -eq ".ps1") {
            $Content = &$_.FullName
        }
        else {
            $Content = $_ | Get-Content | ConvertFrom-Json
        }
        $Content | ForEach-Object {
            [PSCustomObject]@{Name = $Name; Content = $_}
        }
    }
    
    $ChildItems | ForEach-Object {
        $Item = $_
        $ItemKeys = $Item.Content.PSObject.Properties.Name.Clone()
        $ItemKeys | ForEach-Object {
            if ($Item.Content.$_ -is [String]) {
                $Item.Content.$_ = Invoke-Expression "`"$($Item.Content.$_)`""
            }
            elseif ($Item.Content.$_ -is [PSCustomObject]) {
                $Property = $Item.Content.$_
                $PropertyKeys = $Property.PSObject.Properties.Name
                $PropertyKeys | ForEach-Object {
                    if ($Property.$_ -is [String]) {
                        $Property.$_ = Invoke-Expression "`"$($Property.$_)`""
                    }
                }
            }
        }
    }
    
    $ChildItems
}
<#
function Set-Algorithm {
    param(
        [Parameter(Mandatory=$true)]
        [String]$API, 
        [Parameter(Mandatory=$true)]
        [Int]$Port, 
        [Parameter(Mandatory=$false)]
        [Array]$Parameters = @()
    )
    
    $Server = "localhost"
    
    switch($API)
    {
        "nicehash"
        {
        }
    }
}
#>
function Get-HashRate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$API, 
        [Parameter(Mandatory = $true)]
        [Int]$Port, 
        [Parameter(Mandatory = $false)]
        [Object]$Parameters = @{}, 
        [Parameter(Mandatory = $false)]
        [Bool]$Safe = $false
    )
    
    $Server = "localhost"
    
    $Multiplier = 1000
    $Delta = 0.05
    $Interval = 5
    $HashRates = @()
    $HashRates_Dual = @()

    try {
        switch ($API) {
            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
            
                do {
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

                    $HashRate = if ($Data.SUMMARY.HS_5s -ne $null) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow($Multiplier, 0)}
                    elseif ($Data.SUMMARY.KHS_5s -ne $null) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow($Multiplier, 1)}
                    elseif ($Data.SUMMARY.MHS_5s -ne $null) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow($Multiplier, 2)}
                    elseif ($Data.SUMMARY.GHS_5s -ne $null) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow($Multiplier, 3)}
                    elseif ($Data.SUMMARY.THS_5s -ne $null) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow($Multiplier, 4)}
                    elseif ($Data.SUMMARY.PHS_5s -ne $null) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow($Multiplier, 5)}

                    if ($HashRate -ne $null) {
                        $HashRates += $HashRate
                        if (-not $Safe) {break}
                    }

                    $HashRate = if ($Data.SUMMARY.HS_av -ne $null) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow($Multiplier, 0)}
                    elseif ($Data.SUMMARY.KHS_av -ne $null) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow($Multiplier, 1)}
                    elseif ($Data.SUMMARY.MHS_av -ne $null) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow($Multiplier, 2)}
                    elseif ($Data.SUMMARY.GHS_av -ne $null) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow($Multiplier, 3)}
                    elseif ($Data.SUMMARY.THS_av -ne $null) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow($Multiplier, 4)}
                    elseif ($Data.SUMMARY.PHS_av -ne $null) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow($Multiplier, 5)}

                    if ($HashRate -eq $null) {$HashRates = @(); break}
                    $HashRates += $HashRate
                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "ccminer" {
                $Message = "summary"

                do {
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request -split ";" | ConvertFrom-StringData

                    $HashRate = if ([Double]$Data.KHS -ne 0 -or [Double]$Data.ACC -ne 0) {$Data.KHS}

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]$HashRate * $Multiplier

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "cryptodredge" {
                $Message = "summary"

                do {
                    $Client = New-Object System.Net.Sockets.TcpClient $server, 4444
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.Write($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request -split ";" | ConvertFrom-StringData

                    $HashRate = if ([Double]$Data.KHS -ne 0 -or [Double]$Data.ACC -ne 0) {$Data.KHS}

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]$HashRate * $Multiplier

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "XMRig" {
                $Message = "summary"

                do {
                  
                    $Request = Invoke-WebRequest "http://$($Server):$Port/h" -UseBasicParsing
                    
                    $Data = $Request | ConvertFrom-Json

                    $HashRate = [Double]$Data.hashrate.total[0]
                    if ($HashRate -eq "") {$HashRate = [Double]$Data.hashrate.total[1]}
                    if ($HashRate -eq "") {$HashRate = [Double]$Data.hashrate.total[2]}
                    
                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]$HashRate

                    if (-not $Safe) {break}
                    
                    Start-Sleep $Interval
                }while ($HashRates.count -lt 6)
            }
            "dstm" {
                $Message = "summary"

                do {
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json

                    $HashRate = [Double]($Data.result.sol_ps | Measure-Object -Sum).Sum
                    if (-not $HashRate) {$HashRate = [Double]($Data.result.speed_sps | Measure-Object -Sum).Sum} #ewbf fix
            
                    if ($HashRate -eq $null) {$HashRates = @(); break}
                    
                    $HashRates += [Double]$HashRate
                    
                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "nicehashequihash" {
                $Message = "status"

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true

                do {
                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.result.speed_hps
                    
                    if ($HashRate -eq $null) {$HashRate = $Data.result.speed_sps}

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]$HashRate

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "nicehash" {
                $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true

                do {
                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.algorithms.workers.speed

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]($HashRate | Measure-Object -Sum).Sum

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true

                do {
                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.result.speed_sps

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]($HashRate | Measure-Object -Sum).Sum

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "claymore" {
                do {
                    $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
                    
                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                    
                    $HashRate = $Data.result[2].Split(";")[0]
                    $HashRate_Dual = $Data.result[4].Split(";")[0]

                    if ($HashRate -eq $null -or $HashRate_Dual -eq $null) {$HashRates = @(); $HashRate_Dual = @(); break}

                    if ($Request.Content.Contains("ETH:")) {$HashRates += [Double]$HashRate * $Multiplier; $HashRates_Dual += [Double]$HashRate_Dual * $Multiplier}
                    else {$HashRates += [Double]$HashRate; $HashRates_Dual += [Double]$HashRate_Dual}

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "fireice" {
                do {
                    $Request = Invoke-WebRequest "http://$($Server):$Port/h" -UseBasicParsing
                    
                    $Data = $Request.Content -split "</tr>" -match "total*" -split "<td>" -replace "<[^>]*>", ""
                    
                    $HashRate = $Data[1]
                    if ($HashRate -eq "") {$HashRate = $Data[2]}
                    if ($HashRate -eq "") {$HashRate = $Data[3]}

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]$HashRate

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
            "wrapper" {
                do { 

                    $HashRate = Get-Content ".\Bminer.txt"
                
                    if ($HashRate -eq $null) {Start-Sleep $Interval; $HashRate = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
                    }

                    if ($HashRate -eq $null) {$HashRates = @(); break}

                    $HashRates += [Double]$HashRate

                    if (-not $Safe) {break}

                    Start-Sleep $Interval
                } while ($HashRates.Count -lt 6)
            }
        }

        $HashRates_Info = $HashRates | Measure-Object -Maximum -Minimum -Average
        if ($HashRates_Info.Maximum - $HashRates_Info.Minimum -le $HashRates_Info.Average * $Delta) {$HashRates_Info.Maximum}

        $HashRates_Info_Dual = $HashRates_Dual | Measure-Object -Maximum -Minimum -Average
        if ($HashRates_Info_Dual.Maximum - $HashRates_Info_Dual.Minimum -le $HashRates_Info_Dual.Average * $Delta) {$HashRates_Info_Dual.Maximum}
    }
    catch {
    }
}

filter ConvertTo-Hash { 
    $Hash = $_
    switch ([math]::truncate([math]::log($Hash, [Math]::Pow(1000, 1)))) {
        0 {"{0:n2}  H" -f ($Hash / [Math]::Pow(1000, 0))}
        1 {"{0:n2} KH" -f ($Hash / [Math]::Pow(1000, 1))}
        2 {"{0:n2} MH" -f ($Hash / [Math]::Pow(1000, 2))}
        3 {"{0:n2} GH" -f ($Hash / [Math]::Pow(1000, 3))}
        4 {"{0:n2} TH" -f ($Hash / [Math]::Pow(1000, 4))}
        Default {"{0:n2} PH" -f ($Hash / [Math]::Pow(1000, 5))}
    }
}

function Get-Combination {
    param(
        [Parameter(Mandatory = $true)]
        [Array]$Value, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMax = $Value.Count, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMin = 1
    )

    $Combination = [PSCustomObject]@{}

    for ($i = 0; $i -lt $Value.Count; $i++) {
        $Combination | Add-Member @{[Math]::Pow(2, $i) = $Value[$i]}
    }

    $Combination_Keys = $Combination | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    for ($i = $SizeMin; $i -le $SizeMax; $i++) {
        $x = [Math]::Pow(2, $i) - 1

        while ($x -le [Math]::Pow(2, $Value.Count) - 1) {
            [PSCustomObject]@{Combination = $Combination_Keys | Where-Object {$_ -band $x} | ForEach-Object {$Combination.$_}}
            $smallest = ($x -band - $x)
            $ripple = $x + $smallest
            $new_smallest = ($ripple -band - $ripple)
            $ones = (($new_smallest / $smallest) -shr 1) - 1
            $x = $ripple -bor $ones
        }
    }
}

function Start-SubProcess {
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = ""
    )

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        $ProcessParam.Add("WindowStyle", 'Minimized')
        if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
        if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
        $Process = Start-Process @ProcessParam -PassThru
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}
        
        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process
}


function Expand-WebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $true)]
        [String]$Path
    )

    $FolderName_Old = ([IO.FileInfo](Split-Path $Uri -Leaf)).BaseName
    $FolderName_New = Split-Path $Path -Leaf
    $FileName = "$FolderName_New$(([IO.FileInfo](Split-Path $Uri -Leaf)).Extension)"

    if (Test-Path $FileName) {Remove-Item $FileName}
    if (Test-Path "$(Split-Path $Path)\$FolderName_New") {Remove-Item "$(Split-Path $Path)\$FolderName_New" -Recurse}
    if (Test-Path "$(Split-Path $Path)\$FolderName_Old") {Remove-Item "$(Split-Path $Path)\$FolderName_Old" -Recurse}

    Invoke-WebRequest $Uri -OutFile $FileName -TimeoutSec 15 -UseBasicParsing
    Start-Process "7z" "x $FileName -o$(Split-Path $Path)\$FolderName_Old -y -spe" -Wait
    if (Get-ChildItem "$(Split-Path $Path)\$FolderName_Old" | Where-Object PSIsContainer -EQ $false) {
        Rename-Item "$(Split-Path $Path)\$FolderName_Old" "$FolderName_New"
    }
    else {
        Get-ChildItem "$(Split-Path $Path)\$FolderName_Old" | Where-Object PSIsContainer -EQ $true | ForEach-Object {Move-Item "$(Split-Path $Path)\$FolderName_Old\$_" "$(Split-Path $Path)\$FolderName_New"}
        Remove-Item "$(Split-Path $Path)\$FolderName_Old"
    }
}

function Get-Algorithm {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )
    
    $Algorithms = Get-Content "Algorithms.txt" | ConvertFrom-Json

    $Algorithm = (Get-Culture).TextInfo.ToTitleCase(($Algorithm -replace "-", " " -replace "_", " ")) -replace " "

    if ($Algorithms.$Algorithm) {$Algorithms.$Algorithm}
    else {$Algorithm}
}

function Get-Location {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Location
    )
    
    $Locations = Get-Content "Locations.txt" | ConvertFrom-Json

    $Location = (Get-Culture).TextInfo.ToTitleCase(($Location -replace "-", " " -replace "_", " ")) -replace " "

    if ($Locations.$Location) {$Locations.$Location}
    else {$Location}
}

Function Autoupdate {
    # GitHub Supporting only TLSv1.2 on feb 22 2018
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)
    Write-host (Split-Path $script:MyInvocation.MyCommand.Path)
    Update-Status("Checking AutoUpdate")
    Update-Notifications("Checking AutoUpdate")
    # write-host "Checking autoupdate"
    try {
        $AutoUpdateVersion = Invoke-WebRequest "http://tiny.cc/rd3ssy" -TimeoutSec 15 -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json
    }
    catch {$AutoUpdateVersion = Get-content ".\Config\AutoUpdateVersion.json" | Convertfrom-json}
    If ($AutoUpdateVersion -ne $null) {$AutoUpdateVersion | ConvertTo-json | Out-File ".\Config\AutoUpdateVersion.json"}
    If ($AutoUpdateVersion.Product -eq $Variables.CurrentProduct -and [Version]$AutoUpdateVersion.Version -gt $Variables.CurrentVersion -and $AutoUpdateVersion.AutoUpdate) {
        Update-Status("Version $($AutoUpdateVersion.Version) available. (You are running $($Variables.CurrentVersion))")
        # Write-host "Version $($AutoUpdateVersion.Version) available. (You are running $($Variables.CurrentVersion))"
        $LabelNotifications.ForeColor = "Green"
        $LabelNotifications.Lines += "Version $([Version]$AutoUpdateVersion.Version) available"

        If ($AutoUpdateVersion.Autoupdate) {
            $LabelNotifications.Lines += "Starting Auto Update"
            # Setting autostart to true
            $Config.autostart = $true
            Write-Config -ConfigFile $ConfigFile -Config $Config
            
            # Download CRC File from a different location
            # Abort if failed
            Update-Status("Retrieving update CRC")
            try {
                $UpdateCRC = Invoke-WebRequest "http://tiny.cc/NPlusMinerUpdateCRC" -TimeoutSec 15 -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json
                $UpdateCRC = $UpdateCRC | ? {$_.Product -eq $AutoUpdateVersion.Product -and $_.Version -eq $AutoUpdateVersion.Version}
            }
            catch {Update-Status("Cannot get update CRC from server"); return}
            If (! $UpdateCRC) {
                Update-Status("Cannot find CRC for version $($AutoUpdateVersion.Version)")
                Update-Notifications("Cannot find CRC for version $($AutoUpdateVersion.Version)")
                $LabelNotifications.ForeColor = "Red"
                return
            }
            
            # Download update file
            $UpdateFileName = ".\$($AutoUpdateVersion.Product)-$($AutoUpdateVersion.Version)"
            Update-Status("Downloading version $($AutoUpdateVersion.Version)")
            Update-Notifications("Downloading version $($AutoUpdateVersion.Version)")
            try {
                Invoke-WebRequest $AutoUpdateVersion.Uri -OutFile "$($UpdateFileName).zip" -TimeoutSec 15 -UseBasicParsing
            }
            catch {Update-Status("Update download failed"); Update-Notifications("Update download failed"); $LabelNotifications.ForeColor = "Red"; return}
            If (!(test-path ".\$($UpdateFileName).zip")) {
                Update-Status("Cannot find update file")
                Update-Notifications("Cannot find update file")
                $LabelNotifications.ForeColor = "Red"
                return
            }
            
            # Calculate and validate update file CRC
            # Abort if any issue
            Update-Status("Validating update file")
            If ((Get-FileHash ".\$($UpdateFileName).zip").Hash -ne $UpdateCRC.CRC) {
                Update-Status("Update file CRC not valid!"); return
            }
            else {
                Update-Status("Update file validated. Updating NPlusMiner")
            }
            
            # Backup current version folder in zip file
            Update-Status("Backing up current version...")
            Update-Notifications("Backing up current version...")
            $BackupFileName = ("AutoupdateBackup-$(Get-Date -Format u).zip").replace(" ", "_").replace(":", "")
            Start-Process "7z" "a $($BackupFileName) .\* -x!*.zip" -Wait -WindowStyle hidden
            If (!(test-path .\$BackupFileName)) {Update-Status("Backup failed"); return}
            
            # unzip in child folder excluding config
            Update-Status("Unzipping update...")
            Start-Process "7z" "x $($UpdateFileName).zip -o.\ -y -spe -xr!config" -Wait -WindowStyle hidden
            
            # copy files 
            Update-Status("Copying files...")
            Copy-Item .\$UpdateFileName\* .\ -force -Recurse

            # update specific actions if any
            # Use UpdateActions.ps1 in new release to place code
            If (Test-Path ".\$UpdateFileName\UpdateActions.ps1") {
                Invoke-Expression (get-content ".\$UpdateFileName\UpdateActions.ps1" -Raw)
            }
            
            #Remove temp files
            Update-Status("Removing temporary files...")
            Remove-Item .\$UpdateFileName -Force -Recurse
            Remove-Item ".\$($UpdateFileName).zip" -Force
            If (Test-Path ".\UpdateActions.ps1") {Remove-Item ".\UpdateActions.ps1" -Force}
            
            # Start new instance (Wait and confirm start)
            # Kill old instance
            If ($AutoUpdateVersion.RequireRestart) {
                Update-Status("Starting my brother")
                $StartCommand = ((gwmi win32_process -filter "ProcessID=$PID" | select commandline).CommandLine)
                $NewKid = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList @($StartCommand, (Split-Path $script:MyInvocation.MyCommand.Path))
                # Giving 10 seconds for process to start
                $Waited = 0
                sleep 10
                While (!(Get-Process -id $NewKid.ProcessId -EA silentlycontinue) -and ($waited -le 10)) {sleep 1; $waited++}
                If (!(Get-Process -id $NewKid.ProcessId -EA silentlycontinue)) {
                    Update-Status("Failed to start new instance of NPlusMiner")
                    Update-Notifications("NPlusMiner auto updated to version $($AutoUpdateVersion.Version) but failed to restart.")
                    $LabelNotifications.ForeColor = "Red"
                    return
                }
                
                $TempVerObject = (Get-Content .\Version.json | ConvertFrom-Json)
                $TempVerObject | Add-Member -Force @{AutoUpdated = (Get-Date)}
                $TempVerObject | ConvertTo-Json | Out-File .\Version.json
                
                Update-Status("NPlusMiner successfully updated to version $($AutoUpdateVersion.Version)")
                Update-Notifications("NPlusMiner successfully updated to version $($AutoUpdateVersion.Version)")

                Update-Status("Killing myself")
                If (Get-Process -id $NewKid.ProcessId) {Stop-process -id $PID}
            }
            else {
                $TempVerObject = (Get-Content .\Version.json | ConvertFrom-Json)
                $TempVerObject | Add-Member -Force @{AutoUpdated = (Get-Date)}
                $TempVerObject | ConvertTo-Json | Out-File .\Version.json
                
                Update-Status("NPlusMiner successfully updated to version $($AutoUpdateVersion.Version)")
                Update-Notifications("NPlusMiner successfully updated to version $($AutoUpdateVersion.Version)")
                $LabelNotifications.ForeColor = "Green"
            }
        }
        elseif (!($Config.Autostart)) {
            UpdateStatus("Cannot autoupdate as autostart not selected")
            Update-Notifications("Cannot autoupdate as autostart not selected")
            $LabelNotifications.ForeColor = "Red"
        }
        else {
            UpdateStatus("New version available $($AutoUpdateVersion.Product)-$($AutoUpdateVersion.Version). No candidate for Autoupdate")
            Update-Notifications("New version available $($AutoUpdateVersion.Product)-$($AutoUpdateVersion.Version). No candidate for Autoupdate")
            $LabelNotifications.ForeColor = "Red"
        }
    }
    else {
        Update-Status("Not candidate for Autoupdate")
        Update-Notifications("Not candidate for Autoupdate")
        $LabelNotifications.ForeColor = "Green"
    }
}
