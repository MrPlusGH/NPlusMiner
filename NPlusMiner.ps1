<#
This file is part of NPlusMiner
Copyright (c) 2018-2021 MrPlus

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
File:           NPlusMiner.ps1
version:        7.3.2
version date:   20200509
#>

param(
    [Parameter(Mandatory=$false)]
    [String]$Wallet = "bc1qh6c9544vpym6p5mrkukx3tek69ze2arqfvhwhl", 
    [Parameter(Mandatory=$false)]
    [String]$UserName = "MrPlus", 
    [Parameter(Mandatory=$false)]
    [String]$WorkerName = "ID=NPlusMiner2.2", 
    [Parameter(Mandatory=$false)]
    [Int]$API_ID = 0, 
    [Parameter(Mandatory=$false)]
    [String]$API_Key = "", 
    [Parameter(Mandatory=$false)]
    [Int]$Interval = 180, #seconds before between cycles after the first has passed 
    [Parameter(Mandatory=$false)]
    [Int]$FirstInterval = 30, #seconds of the first cycle of activated or started first time miner
    [Parameter(Mandatory=$false)]
    [Int]$StatsInterval = 300, #seconds of current active to gather hashrate if not gathered yet
    [Parameter(Mandatory=$false)]
    [String]$Location = "US", #europe/us/asia
    [Parameter(Mandatory=$false)]
    [Switch]$SSL = $false, 
    [Parameter(Mandatory=$false)]
    [Array]$Type = "nvidia", #AMD/NVIDIA/CPU
    [Parameter(Mandatory=$false)]
    [String]$SelGPUDSTM = "0 1",
    [Parameter(Mandatory=$false)]
    [String]$SelGPUCC = "0,1",
    [Parameter(Mandatory=$false)]
    [Array]$Algorithm = $null, #i.e. Ethash,Equihash,Cryptonight ect.
    [Parameter(Mandatory=$false)]
    [Array]$MinerName = $null, 
    [Parameter(Mandatory=$false)]
    [Array]$PoolName = $null, 
    [Parameter(Mandatory=$false)]
    [Array]$Currency = ("USD"), #i.e. GBP,USD,AUD,NZD ect.
    [Parameter(Mandatory=$false)]
    [Array]$Passwordcurrency = ("BTC"), #i.e. BTC,LTC,ZEC,ETH ect.
    [Parameter(Mandatory=$false)]
    [Int]$Donate = 5, #Minutes per Day
    [Parameter(Mandatory=$false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080 
    [Parameter(Mandatory=$false)]
    [Int]$Delay = 1, #seconds before opening each miner
    [Parameter(Mandatory=$false)]
    [Int]$GPUCount = 1, # Number of GPU on the system
    [Parameter(Mandatory=$false)]
    [Int]$ActiveMinerGainPct = 5, # percent of advantage that active miner has over candidates in term of profit
    [Parameter(Mandatory=$false)]
    [Float]$MarginOfError = 0, #0.4, # knowledge about the past wont help us to predict the future so don't pretend that Week_Fluctuation means something real
    [Parameter(Mandatory=$false)]
    [String]$UIStyle = "Light", # Light or Full. Defines level of info displayed
    [Parameter(Mandatory=$false)]
    [Bool]$TrackEarnings = $True, # Display earnings information
    [Parameter(Mandatory=$false)]
    [Bool]$Autoupdate = $True, # Autoupdate
    [Parameter(Mandatory=$false)]
    [String]$ConfigFile = ".\Config\config.json"
)


. .\Includes\include.ps1
. .\Includes\Core.ps1

@"
NPlusMiner
Copyright (c) 2018-2021 MrPlus

This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it
under certain conditions.
https://github.com/MrPlusGH/NPlusMiner/blob/master/LICENSE

NPlusMiner is licensed under the GNU General Public License v3.0

 Permissions of this strong copyleft license are conditioned on making
 available complete source code of licensed works and modifications,
 which include larger works using a licensed work, under the same license.
"@
Write-Host -F Yellow " Copyright and license notices must be preserved."
@"
+

"@

    $Global:Config = [hashtable]::Synchronized(@{})
    $Global:Config | Add-Member -Force @{ConfigFile = $ConfigFile}
    $Global:Variables = [hashtable]::Synchronized(@{})
    $Global:Variables | Add-Member -Force -MemberType ScriptProperty -Name 'StatusText' -Value{ $this._StatusText;$This._StatusText = [System.Collections.ArrayList]::Synchronized(@()) }  -SecondValue { If (!$this._StatusText){$this._StatusText=[System.Collections.ArrayList]::Synchronized(@())};$this._StatusText+=$args[0];$Variables.RefreshNeeded = $True }
    
    # Set Console size
    $ConsoleHeight = 50
    $ConsoleWidth = 160
    $pswindow = (get-host).ui.rawui
    $newsize = $pswindow.buffersize
    # $newsize.height = 3000
    $newsize.width = $ConsoleWidth
    $pswindow.buffersize = $newsize
    $newsize = $pswindow.windowsize
    # $newsize.height = $ConsoleHeight
    $newsize.width = $ConsoleWidth
    $pswindow.windowsize = $newsize
    
    rv ConsoleHeight, ConsoleWidth, pswindow, newsize

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
        
Function Global:TimerUITick
{
    $TimerUI.Stop()
    # If something (pause button, idle timer) has set the RestartCycle flag, stop and start mining to switch modes immediately
            If ($Variables.RestartCycle) {
                $Variables.RestartCycle = $False
                Stop-Mining
                Start-Mining
                If ($Variables.Paused) {
                    $EarningsDGV.DataSource = [System.Collections.ArrayList]@()
                    $RunningMinersDGV.DataSource = [System.Collections.ArrayList]@()
                    $LabelBTCD.ForeColor = "Red"
                    $TimerUI.Stop()
                }
            }

    If ($Variables.RefreshNeeded -and $Variables.Started -and -not $Variables.Paused) {
        If (!$Variables.EndLoop) {Update-Status($Variables.StatusText)}
        # $TimerUI.Interval = 1

    $LabelBTCD.ForeColor = "Green"
        Start-ChildJobs

        $Variables.EarningsTrackerJobs | ? {$_.state -eq "Running"} | foreach {
            $EarnTrack = $_ | Receive-Job
                If ($EarnTrack) {
                    # $Variables.Earnings = @{}
                    $EarnTrack | ? {$_.Pool -ne ""} | sort date,pool | select -Last ($EarnTrack.Pool | Sort -Unique).Count | ForEach {
                        If ($true) { #$_.Pool -in ($config.PoolName -replace "24hr","" -replace "plus","")) {
                            $Variables.EarningsPool = $_.Pool
                            $Variables.Earnings.($_.Pool) = $_
                            $Variables.Earnings.($_.Pool).PaymentThreshold =
                            If ($Config.PoolsConfig.($_.Pool).PayoutThreshold.($Config.Passwordcurrency)) {
                                $Config.PoolsConfig.($_.Pool).PayoutThreshold.($Config.Passwordcurrency)
                            } Else {
                                $_.PaymentThreshold
                            }
                        }
                    }
                    rv EarnTrack
               }
        }
        
        If ((compare -ReferenceObject $CheckedListBoxPools.Items -DifferenceObject ((Get-ChildItem ".\Pools").BaseName | sort -Unique) | ? {$_.SideIndicator -eq "=>"}).InputObject -gt 0) {
        (compare -ReferenceObject $CheckedListBoxPools.Items -DifferenceObject ((Get-ChildItem ".\Pools").BaseName | sort -Unique) | ? {$_.SideIndicator -eq "=>"}).InputObject | % { if ($_ -ne $null){}$CheckedListBoxPools.Items.AddRange($_)}
        $Config.PoolName | foreach {$CheckedListBoxPools.SetItemChecked($CheckedListBoxPools.Items.IndexOf($_),$True)}
        }
        $Variables.InCycle = $True
        # $MainForm.Number+=1
        $MainForm.Text = $Branding.ProductLable + " " + $Variables.CurrentVersion + " Runtime " + ("{0:dd\ \d\a\y\s\ hh\:mm}" -f ((get-date)-$Variables.ScriptStartDate)) + " Path: " + (Split-Path $script:MyInvocation.MyCommand.Path)
        $host.UI.RawUI.WindowTitle = $Branding.ProductLable + " " + $Variables.CurrentVersion + " Runtime " + ("{0:dd\ \d\a\y\s\ hh\:mm}" -f ((get-date)-$Variables.ScriptStartDate)) + " Path: " + (Split-Path $script:MyInvocation.MyCommand.Path)


        If ($Variables.EndLoop) {
        
            $SwitchingDisplayTypes = @()
            $SwitchingPageControls | foreach {if ($_.Checked){$SwitchingDisplayTypes += $_.Tag}}
            # If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(Import-Csv ".\Logs\switching.log" | ? {$_.Type -in $SwitchingDisplayTypes} | Select -Last 13)}
            # If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(Import-Csv ".\Logs\switching.log" | ? {$_.Type -in $SwitchingDisplayTypes} | Select -Last 13)}
            If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(@((get-content ".\Logs\switching.log" -First 1) , (get-content ".\logs\switching.log" -last 50)) | ConvertFrom-Csv | ? {$_.Type -in $SwitchingDisplayTypes} | Select -Last 13)}
            $SwitchingDGV.DataSource = $SwitchingArray
            
            # Fixed memory leak to to chart object not being properly disposed in 5.3.0
            # https://stackoverflow.com/questions/8466343/why-controls-do-not-want-to-get-removed

            If (Test-Path ".\logs\DailyEarnings.csv"){
                $Chart1 = Invoke-Expression -Command ".\Includes\Charting.ps1 -Chart 'Front7DaysEarnings' -Width 505 -Height 85 -Currency $($Config.Passwordcurrency)"
                $Chart1.top = 74
                $Chart1.left = 0
                $RunPage.Controls.Add($Chart1)
                $Chart1.BringToFront()

                $Chart2 = Invoke-Expression -Command ".\Includes\Charting.ps1 -Chart 'DayPoolSplit' -Width 200 -Height 85 -Currency $($Config.Passwordcurrency)"
                $Chart2.top = 74
                $Chart2.left = 500
                $RunPage.Controls.Add($Chart2)
                $Chart2.BringToFront()
                
                $RunPage.Controls | ? {($_.gettype()).name -eq "Chart" -and $_ -ne $Chart1 -and $_ -ne $Chart2} | % {$RunPage.Controls[$RunPage.Controls.IndexOf($_)].Dispose();$RunPage.Controls.Remove($_)}
            }

            If ($Variables.Earnings -and $Config.TrackEarnings) {
                $DisplayEarnings = [System.Collections.ArrayList]@($Variables.Earnings.Values | select @(
                    @{Name="Pool";Expression={$_.Pool}},
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
                $EarningsDGV.DataSource = [System.Collections.ArrayList]@($DisplayEarnings)
                $EarningsDGV.ClearSelection()
            }
            
            If ($Variables.Miners) {
                $DisplayEstimations = [System.Collections.ArrayList]@($Variables.Miners | Select @(
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
                ) | sort "mBTC/Day" -Descending)
                If ($Config.ShowOnlyTopCoins){
                    $EstimationsDGV.DataSource = [System.Collections.ArrayList]@($DisplayEstimations | sort "mBTC/Day" -Descending | Group "Type","Algorithm" | % { $_.Group | select -First 1} | sort "mBTC/Day" -Descending)
                } else {
                    $EstimationsDGV.DataSource = [System.Collections.ArrayList]@($DisplayEstimations)
                }
                $EstimationsDGV.Columns["mBTC/Day"].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightGray
            }
            $EstimationsDGV.ClearSelection()

            $SwitchingDGV.ClearSelection()

            If ($Variables.Workers -and $Config.ShowWorkerStatus) {
                $DisplayWorkers = [System.Collections.ArrayList]@($Variables.Workers | select @(
                        @{Name = "Worker"; Expression = {$_.worker}},
                        @{Name = "Status"; Expression = {$_.status}},
                        @{Name = "Last Seen"; Expression = {$_.timesincelastreport}},
                        @{Name = "Version"; Expression = {$_.version}},
                        @{Name = "Est. BTC/Day"; Expression = {[decimal]$_.profit}},
                        @{Name = "Miner"; Expression = {$_.data.name -join ','}},
                        @{Name = "Pool"; Expression = {$_.data.pool -join ','}},
                        @{Name = "Algo"; Expression = {$_.data.algorithm -join ','}},
                        @{Name = "Speed"; Expression = {if ($_.data.currentspeed) {($_.data.currentspeed | ConvertTo-Hash) -join ','} else {""}}},
                        @{Name = "Benchmark Speed"; Expression = {if ($_.data.estimatedspeed) {($_.data.estimatedspeed | ConvertTo-Hash) -join ','} else {""}}}
                    ) | Sort "Worker Name")
                $WorkersDGV.DataSource = [System.Collections.ArrayList]@($DisplayWorkers)

                # Set row color
                $WorkersDGV.Rows | ForEach-Object {
                    if ($_.DataBoundItem.Status -eq "Offline") {
                        $_.DefaultCellStyle.Backcolor = [System.Drawing.Color]::FromArgb(255, 213, 142, 176)
                    }
                    elseif ($_.DataBoundItem.Status -eq "Paused") {
                        $_.DefaultCellStyle.Backcolor = [System.Drawing.Color]::FromArgb(255, 247, 252, 168)
                    }
                    elseif ($_.DataBoundItem.Status -eq "Running") {
                        $_.DefaultCellStyle.Backcolor = [System.Drawing.Color]::FromArgb(255, 127, 191, 144)
                    }
                    else {
                        $_.DefaultCellStyle.Backcolor = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
                    }
                }

                $WorkersDGV.ClearSelection()
                $LabelMonitoringWorkers.text = "Worker Status - Updated $($Variables.WorkersLastUpdated.ToString())"
            }
            
            If ($Variables.ActiveMinerPrograms) {
                # $RunningMinersDGV.DataSource = [System.Collections.ArrayList]@($Variables.ActiveMinerPrograms | ? {$_.Status -eq "Running"} | select Type,Algorithms,Coin,Name,@{Name="HashRate";Expression={"$($_.HashRate | ConvertTo-Hash)/s"}},@{Name="Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f $_.Active}},@{Name="Total Active";Expression={"{0:hh}:{0:mm}:{0:ss}" -f $_.TotalActive}},Host | sort Type)
                $RunningMinersDGV.DataSource = [System.Collections.ArrayList]@($Variables.ActiveMinerPrograms.Clone() | ? {$_.Status -eq "Running"} | select @(
                    @{Name = "Type";Expression={$_.Type}},
                    @{Name = "Algorithm";Expression={$_.Algorithms}},
                    @{Name = "Coin"; Expression={$_.Coin}},
                    @{Name = "Miner";Expression={$_.Name}},
                    @{Name="HashRate";Expression={"$($_.HashRate | ConvertTo-Hash)/s"}},
                    @{Name ="Active";Expression={"{0:dd}:{0:hh}:{0:mm}:{0:ss}" -f $_.Active}},
                    @{Name ="Total Active";Expression={"{0:dd}:{0:hh}:{0:mm}:{0:ss}" -f $_.TotalActive}},
                    @{Name = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)"}}} ) | sort Type
                )
                $RunningMinersDGV.ClearSelection()
            
                [Array] $processRunning = $Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" }
                If ($ProcessRunning -eq $null){
                    # Update-Status("No miner running")
                }
            }
            $LabelBTCPrice.text = If($Variables.Rates.$Currency -gt 0){"$($Config.Passwordcurrency)/$($Config.Currency) $($Variables.Rates.($Config.Currency))"}
            $Variables.InCycle = $False
        
        
            If ($Variables.Earnings.Values -ne $Null){
                $LabelBTCD.Text = "Avg: " + ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum)).DisplayStringPerDay
                
                
                $LabelEarningsDetails.Lines = @()
                # If ((($Variables.Earnings.Values | measure -Property Growth1 -Sum).sum*1000*24) -lt ((($Variables.Earnings.Values | measure -Property BTCD -Sum).sum*1000)*0.999)) {
                    # $LabelEarningsDetails.ForeColor = "Red" } else { $LabelEarningsDetails.ForeColor = "Green" }
                $TrendSign = switch ([Math]::Round((($Variables.Earnings.Values | measure -Property Growth1 -Sum).sum*1000*24),3) - [Math]::Round((($Variables.Earnings.Values | measure -Property Growth6 -Sum).sum*1000*4),3)) {
                        {$_ -eq 0}
                            {"="}
                        {$_ -gt 0}
                            {">"}
                        {$_ -lt 0}
                            {"<"}
                    }
                $LabelEarningsDetails.Lines += "Last  1h: " + ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth1 -Sum).sum 24)).DisplayStringPerDay + " " + $TrendSign
                $TrendSign = switch ([Math]::Round((($Variables.Earnings.Values | measure -Property Growth6 -Sum).sum*1000*4),3) - [Math]::Round((($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum*1000),3)) {
                        {$_ -eq 0}
                            {"="}
                        {$_ -gt 0}
                            {">"}
                        {$_ -lt 0}
                            {"<"}
                    }
                $LabelEarningsDetails.Lines += "Last  6h: " + ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth6 -Sum).sum 4)).DisplayStringPerDay + " " + $TrendSign
                $TrendSign = switch ([Math]::Round((($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum*1000),3) - [Math]::Round((($Variables.Earnings.Values | measure -Property BTCD -Sum).sum*1000*0.96),3)) {
                        {$_ -eq 0}
                            {"="}
                        {$_ -gt 0}
                            {">"}
                        {$_ -lt 0}
                            {"<"}
                    }
                $LabelEarningsDetails.Lines += "Last 24h: " + ((Get-DisplayCurrency ($Variables.Earnings.Values | measure -Property Growth24 -Sum).sum)).DisplayStringPerDay + " " + $TrendSign
                rv TrendSign
            } else {
                $LabelBTCD.Text = "Waiting data from pools."
                $LabelEarningsDetails.Lines = @()
            }
        
            if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}
            if (!(IsLoaded(".\Includes\Core.ps1"))) {. .\Includes\Core.ps1;RegisterLoaded(".\Includes\Core.ps1")}
        
            $Variables.CurrentProduct = (Get-Content .\Version.json | ConvertFrom-Json).Product
            $Variables.CurrentVersion = [Version](Get-Content .\Version.json | ConvertFrom-Json).Version
            $Variables.CurrentVersionAutoUpdated = (Get-Content .\Version.json | ConvertFrom-Json).AutoUpdated.Value
            if ((Get-Content .\Version.json | ConvertFrom-Json).AutoUpdated -and $LabelNotifications.Lines[$LabelNotifications.Lines.Count-1] -ne "Auto Updated on $($Variables.CurrentVersionAutoUpdated)"){
                $LabelNotifications.ForeColor = "Green"
                Update-Notifications("Running $($Variables.CurrentProduct) Version $([Version]$Variables.CurrentVersion)")
                Update-Notifications("Auto Updated on $($Variables.CurrentVersionAutoUpdated)")
            }
        
            #Display mining information
            if($host.UI.RawUI.KeyAvailable){$KeyPressed = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp");sleep -Milliseconds 300;$host.UI.RawUI.FlushInputBuffer()
            If ($KeyPressed.KeyDown){
            Switch ($KeyPressed.Character) {
                    "s" {if ($Config.UIStyle -eq "Light"){$Config.UIStyle="Full"}else{$Config.UIStyle="Light"}}
                    "e" {$Config.TrackEarnings=-not $Config.TrackEarnings}
            }}}
            Clear-Host
            [Array] $processesIdle = $Variables.ActiveMinerPrograms | Where { $_.Status -eq "Idle" }
            IF ($Config.UIStyle -eq "Full"){
                if ($processesIdle.Count -gt 0) {
                    Write-Host "Idle: " $processesIdle.Count
                    $processesIdle | Sort {if($_.Process -eq $null){(Get-Date)}else{$_.Process.ExitTime}} | Format-Table -Wrap (
                        @{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
                        @{Label = "Exited"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.ExitTime}) }},
                        @{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
                        @{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
                        @{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                }
            }
            Write-Host "      1BTC = $($Variables.Rates.($Config.Currency)) $($Config.Currency)"
            # Get and display earnings stats
            If ($Variables.Earnings -and $Config.TrackEarnings) {
                # $Variables.Earnings.Values | select Pool,Wallet,Balance,AvgDailyGrowth,EstimatedPayDate,TrustLevel | ft *
                $Variables.Earnings.Values | foreach {
                    Write-Host "+++++" $_.Wallet -B DarkBlue -F DarkGray -NoNewline; Write-Host " " $_.pool "Balance="$_.balance ("{0:P0}" -f ($_.balance/$_.PaymentThreshold))
                    Write-Host "Trust Level                     " ("{0:P0}" -f $_.TrustLevel) -NoNewline; Write-Host -F darkgray " Avg based on [" ("{0:dd\ \d\a\y\s\ hh\:mm}" -f ($_.Date - $_.StartTime))"]"
                    Write-Host "Average BTC/H                    BTC =" ("{0:N8}" -f $_.AvgHourlyGrowth) "| mBTC =" ("{0:N3}" -f ($_.AvgHourlyGrowth*1000))
                    Write-Host "Average BTC/D" -NoNewline; Write-Host "                    BTC =" ("{0:N8}" -f ($_.BTCD)) "| mBTC =" ("{0:N3}" -f ($_.BTCD*1000)) -F Yellow
                    Write-Host "Estimated Pay Date              " $_.EstimatedPayDate ">" $_.PaymentThreshold "BTC"
                    # Write-Host "+++++" -F Blue
                }
            }
            Write-Host "+++++" -F Blue
            if ($Variables.Miners | ? {$_.HashRates.PSObject.Properties.Value -eq $null}) {$Config.UIStyle = "Full"}
            IF ($Config.UIStyle -eq "Full"){

                # $Variables.Miners | Sort -Descending Type,Profit | Format-Table -GroupBy Type (
                # @{Label = "Miner"; Expression={$_.Name}}, 
                # @{Label = "Algorithm"; Expression={$_.HashRates.PSObject.Properties.Name}}, 
                # @{Label = "Speed"; Expression={$_.HashRates.PSObject.Properties.Value | ForEach {if($_ -ne $null){"$($_ | ConvertTo-Hash)/s"}else{"Benchmarking"}}}; Align='right'}, 
                # @{Label = "mBTC/Day"; Expression={$_.Profits.PSObject.Properties.Value*1000 | ForEach {if($_ -ne $null){$_.ToString("N3")}else{"Benchmarking"}}}; Align='right'}, 
                # @{Label = "BTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){$_.ToString("N5")}else{"Benchmarking"}}}; Align='right'}, 
                # @{Label = "$($Config.Currency)/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){($_ * $Variables.Rates.($Config.Currency)).ToString("N3")}else{"Benchmarking"}}}; Align='right'}, 
                # @{Label = "BTC/GH/Day"; Expression={$_.Pools.PSObject.Properties.Value.Price | ForEach {($_*1000000000).ToString("N5")}}; Align='right'},
                # @{Label = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)-$($_.Info)"}}}
                # ) | Out-Host

                If ($Config.ShowOnlyTopCoins){
                    $DisplayEstimations | sort "mBTC/Day" -Descending | Group "Type","Algorithm" | % { $_.Group | select -First 1} | sort Type,"mBTC/Day" -Descending | Format-Table -GroupBy Type | Out-Host
                } else {
                    $DisplayEstimations | sort Type,"mBTC/Day" -Descending | Format-Table -GroupBy Type | Out-Host
                }
                
                
                    #Display active miners list
                [Array] $processRunning = $Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" }
                Write-Host "Running:"
                $processRunning | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Format-Table -Wrap (
                    @{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
                    @{Label = "Started"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.StartTime}) }},
                    @{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
                    @{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
                    @{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                ) | Out-Host
                [Array] $processesFailed = $Variables.ActiveMinerPrograms | Where { $_.Status -eq "Failed" }
                if ($processesFailed.Count -gt 0) {
                    Write-Host -ForegroundColor Red "Failed: " $processesFailed.Count
                    $processesFailed | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Format-Table -Wrap (
                        @{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
                        @{Label = "Exited"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.ExitTime}) }},
                        @{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
                        @{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
                        @{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                }
                Write-Host "--------------------------------------------------------------------------------"
            
            } else {
                [Array] $processRunning = $Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" }
                Write-Host "Running:"
                $processRunning | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Format-Table -Wrap (
                    @{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
                    @{Label = "Started"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.StartTime}) }},
                    @{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
                    @{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
                    @{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                ) | Out-Host
                Write-Host "--------------------------------------------------------------------------------"
            }
            Write-Host -ForegroundColor Yellow "Last refresh: $(Get-Date)   |   Next refresh: $((Get-Date).AddSeconds($Variables.TimeToSleep))"
            Update-Status($Variables.StatusText)
        }
        if (Test-Path ".\EndUIRefresh.ps1"){Invoke-Expression (Get-Content ".\EndUIRefresh.ps1" -Raw)}

        $Variables.RefreshNeeded = $False
    }
    $TimerUI.Start()
}

Function Form_Load
{
    $DblBuff = ($MainForm.GetType()).GetProperty("DoubleBuffered", ('Instance','NonPublic'))
    $DblBuff.SetValue($MainForm, $True, $null)

    $MainForm.Text = "$($Branding.ProductLable) $($Variables.CurrentVersion)"
    $LabelBTCD.Text = "$($Branding.ProductLable) $($Variables.CurrentVersion)"
    $MainForm.Number = 0
    $TimerUI.Add_Tick({
        # Timer never disposes objects until it is disposed
        $MainForm.Number = $MainForm.Number + 1
        $TimerUI.Stop()
        TimerUITick
        If ($MainForm.Number -gt 6000) {
            # Write-Host -B R "Releasing Timer"
            $MainForm.Number = 0
            # $TimerUI.Stop()
            $TimerUI.Remove_Tick({TimerUITick})
            $TimerUI.Dispose()
            $TimerUI = New-Object System.Windows.Forms.Timer
            $TimerUI.Add_Tick({TimerUITick})
            # $TimerUI.Start()
        }
        $TimerUI.Start()
    })
    $TimerUI.Interval = 50
    $TimerUI.Stop()
        
        If ($CheckBoxConsole.Checked) {
            $null = $ShowWindow::ShowWindowAsync($ConsoleHandle, 0)
            Update-Status("Console window hidden")
        }
        else {
            $null = $ShowWindow::ShowWindowAsync($ConsoleHandle, 8)
            # Update-Status("Console window shown")
        }

}

Function CheckedListBoxPools_Click ($Control) {
    $Config | Add-Member -Force @{$Control.Tag = $Control.CheckedItems}
    $EarningTrackerConfig = Get-Content ".\Config\EarningTrackerConfig.json" | ConvertFrom-JSON
    $EarningTrackerConfig | Add-Member -Force @{"Pools" = ($Control.CheckedItems.Replace("24hr", "")).Replace("Plus", "") | sort -Unique}
    $EarningTrackerConfig | ConvertTo-JSON | Out-File ".\Config\EarningTrackerConfig.json"
}

Function PrepareWriteConfig{
    If ($Variables.DonationRunning) {Update-Status("Donation Running - Not saving config"); return}
    If ($Config.ManualConfig) {Update-Status("Manual config mode - Not saving config"); return}
    If ($Config -eq $null){$Config = [hashtable]::Synchronized(@{})}
    $Config | Add-Member -Force @{$TBAddress.Tag = $TBAddress.Text}
    $Config | Add-Member -Force @{$TBWorkerName.Tag = $TBWorkerName.Text}
    $ConfigPageControls | ? {(($_.gettype()).Name -eq "CheckBox")} | foreach {$Config | Add-Member -Force @{$_.Tag = $_.Checked}}
    $ConfigPageControls | ? {(($_.gettype()).Name -eq "TextBox")} | foreach {$Config | Add-Member -Force @{$_.Tag = $_.Text}}
    $ConfigPageControls | ? {(($_.gettype()).Name -eq "TextBox") -and ($_.Tag -eq "GPUCount")} | foreach {
        $Config | Add-Member -Force @{$_.Tag = [Int]$_.Text}
        If ($CheckBoxDisableGPU0.checked -and [Int]$_.Text -gt 1){$FirstGPU = 1}else{$FirstGPU = 0}
        $Config | Add-Member -Force @{SelGPUCC = (($FirstGPU..($_.Text-1)) -join ",")}
        $Config | Add-Member -Force @{SelGPUDSTM = (($FirstGPU..($_.Text-1)) -join " ")}
    }
	$ConfigPageControls | ? {(($_.gettype()).Name -eq "TextBox") -and ($_.Tag -eq "MaxTTFSeconds")} | foreach {
		        $Config | Add-Member -Force @{$_.Tag = [Int]$_.Text}
	}

    $ConfigPageControls | ? {(($_.gettype()).Name -eq "TextBox") -and ($_.Tag -eq "Algorithm")} | foreach {
        $Config | Add-Member -Force @{$_.Tag = @($_.Text -split ",")}
    }
    $ConfigPageControls | ? {(($_.gettype()).Name -eq "TextBox") -and ($_.Tag -in @("Donate","Interval","ActiveMinerGainPct"))} | foreach {
        $Config | Add-Member -Force @{$_.Tag = [Int]$_.Text}
    }
    $Config | Add-Member -Force @{$CheckedListBoxPools.Tag = $CheckedListBoxPools.CheckedItems}
    
    $ServermodePageControls | ? {(($_.gettype()).Name -eq "CheckBox")} | foreach {$Config | Add-Member -Force @{$_.Tag = $_.Checked}}
    $ServermodePageControls | ? {(($_.gettype()).Name -eq "TextBox")} | foreach {$Config | Add-Member -Force @{$_.Tag = $_.Text}}

    $MonitoringSettingsControls | ? {(($_.gettype()).Name -eq "CheckBox")} | foreach {$Config | Add-Member -Force @{$_.Tag = $_.Checked}}
    $MonitoringSettingsControls | ? {(($_.gettype()).Name -eq "TextBox")} | foreach {$Config | Add-Member -Force @{$_.Tag = $_.Text}}

    Write-Config -ConfigFile $ConfigFile -Config $Config
    $Config = Load-Config -ConfigFile $ConfigFile
    
    $ServerPasswd = ConvertTo-SecureString $Config.Server_Password -AsPlainText -Force
    $ServerCreds = New-Object System.Management.Automation.PSCredential ($Config.Server_User, $ServerPasswd)
    $Variables.ServerCreds = $ServerCreds
    $ServerClientPasswd = ConvertTo-SecureString $Config.Server_ClientPassword -AsPlainText -Force
    $ServerClientCreds = New-Object System.Management.Automation.PSCredential ($Config.Server_ClientUser, $ServerClientPasswd)
    $Variables.ServerClientCreds = $ServerClientCreds
    
    $MainForm.Refresh
    # [windows.forms.messagebox]::show("Please restart NPlusMiner",'Config saved','ok','Information') | out-null
}

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# If (Test-Path ".\Logs\switching.log"){$log=Import-Csv ".\Logs\switching.log" | Select -Last 14}
# $SwitchingArray = [System.Collections.ArrayList]@($Log)
If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(Import-Csv ".\Logs\switching.log" | Select -Last 14)}

[environment]::currentdirectory = (Split-Path $script:MyInvocation.MyCommand.Path)

$MainForm = New-Object system.Windows.Forms.Form
$NPMIcon = New-Object system.drawing.icon (".\Includes\NPM.ICO")
$MainForm.Icon                  = $NPMIcon
$MainForm.ClientSize            = '740,450' # best to keep under 800,600
$MainForm.text                  = "Form"
$MainForm.TopMost               = $false
$MainForm.FormBorderStyle       = 'Fixed3D'
$MainForm.MaximizeBox           = $false

$MainForm.add_Shown({
    # Check if new version is available
    Update-Status("Checking version")
    try {
        $Version = Invoke-WebRequest "http://tiny.cc/m155qy" -TimeoutSec 15 -UseBasicParsing -Headers $Variables.APIHeaders | ConvertFrom-Json} catch {$Version = Get-content ".\Config\version.json" | Convertfrom-json}
    If ($Version -ne $null){$Version | ConvertTo-json | Out-File ".\Config\version.json"}
    If ($Version.Product -eq $Variables.CurrentProduct -and [Version]$version.Version -gt $Variables.CurrentVersion -and $Version.Update) {
        Update-Status("Version $($version.Version) available. (You are running $($Variables.CurrentVersion))")
        # If ([version](GetNVIDIADriverVersion) -ge [Version]$Version.MinNVIDIADriverVersion){
            $LabelNotifications.ForeColor = "Green"
            $LabelNotifications.Lines += "Version $([Version]$version.Version) available"
            $LabelNotifications.Lines += $version.Message
            If ($Config.Autoupdate -and ! $Config.ManualConfig) {Autoupdate}
        # } else {
            # Update-Status("Version $($version.Version) available. Please update NVIDIA driver. Will not AutoUpdate")
            # $LabelNotifications.ForeColor = "Red"
            # $LabelNotifications.Lines += "Driver update required. Version $([Version]$version.Version) available"
        # }
        
    }

    # Check prereqs
    Update-Status("Checking Prerequisites")
    # $PreReqsCheck = Get-SubScriptContent ".\Utils\CheckPreReqs.ps1"
    If (-not (Get-SubScriptContent ".\Utils\CheckPreReqs.ps1").Content) {
        Update-Status("Please wait and answer YES to install if asked...")
		if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) { Get-ChildItem . -Recurse | Unblock-File }        Update-Status("Please wait and answer YES to install if asked...")
        Start-Process (@{desktop = "powershell"; core = "pwsh" }.$PSEdition) "-File $(Resolve-Path .\Utils\InstallPreReqs.ps1)" -Verb runAs
        Sleep 30
    }
    # Invoke-Expression -Command ".\Utils\CheckPreReqs.ps1"
    Update-Status("Done and ready")

    # TimerCheckVersion
    $TimerCheckVersion = New-Object System.Windows.Forms.Timer
    $TimerCheckVersion.Enabled = $true
    $TimerCheckVersion.Interval = 480*60*1000
    $TimerCheckVersion.Add_Tick({
        Update-Status("Checking version")
        try {
            $Version = Invoke-WebRequest "http://tiny.cc/rrxqry" -TimeoutSec 15 -UseBasicParsing -Headers $Variables.APIHeaders | ConvertFrom-Json} catch {$Version = Get-content ".\Config\version.json" | Convertfrom-json}
        If ($Version -ne $null){$Version | ConvertTo-json | Out-File ".\Config\version.json"}
        If ($Version.Product -eq $Variables.CurrentProduct -and [Version]$version.Version -gt $Variables.CurrentVersion -and $Version.Update) {
            Update-Status("Version $($version.Version) available. (You are running $($Variables.CurrentVersion))")
            # If ([version](GetNVIDIADriverVersion) -ge [Version]$Version.MinNVIDIADriverVersion){
                $LabelNotifications.ForeColor = "Green"
                $LabelNotifications.Lines += "Version $([Version]$version.Version) available"
                $LabelNotifications.Lines += $version.Message
                If ($Config.Autoupdate -and ! $Config.ManualConfig) {Autoupdate}
            # } else {
                # Update-Status("Version $($version.Version) available. Please update NVIDIA driver. Will not AutoUpdate")
                # $LabelNotifications.ForeColor = "Red"
                # $LabelNotifications.Lines += "Driver update required. Version $([Version]$version.Version) available"
            # }
            
        }
    })
    # Detects GPU count if 0 or Null in config
    # Added DetectedGPU in 7.8.0 to store GPU details in Config
    If ($Config.DetectedGPU.Count -eq 0 -or $Config.GPUCount -eq $null -or $Config.GPUCount -lt 1){
        If ($Config -eq $null){$Config = [hashtable]::Synchronized(@{})}
        $DetectedGPU = @(DetectGPUCount)
        $Config | Add-Member -Force @{DetectedGPU = $DetectedGPU}
        $Config | Add-Member -Force @{GPUCount = $DetectedGPU.Count}
        $TBGPUCount.Text = $Config.GPUCount
        PrepareWriteConfig
    }
    # Start on load if Autostart
    If ($Config.Autostart){$ButtonStart.PerformClick()}
    If ($Config.StartGUIMinimized){$MainForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized}
})

$MainForm.Add_FormClosing({
        $TimerUI.Stop()
        Update-Status("Stopping jobs and miner")

        if ($Variables.EarningsTrackerJobs) {$Variables.EarningsTrackerJobs | %{$_ | Stop-Job | Remove-Job}}
        if ($Variables.BrainJobs) {$Variables.BrainJobs | %{$_ | Stop-Job | Remove-Job}}

        If ($Variables.ActiveMinerPrograms) {
            $Variables.ActiveMinerPrograms | ForEach {
                [Array]$filtered = ($BestMiners_Combo | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments)
                if($filtered.Count -eq 0)
                {
                    if($_.Process -eq $null)
                    {
                        $_.Status = "Failed"
                    }
                    elseif($_.Process.HasExited -eq $false)
                    {
                    $_.Active += (Get-Date)-$_.Process.StartTime
                       $_.Process.CloseMainWindow() | Out-Null
                       Sleep 1
                       # simply "Kill with power"
                       Stop-Process $_.Process -Force | Out-Null
                       Write-Host -ForegroundColor Yellow "closing miner"
                       Sleep 1
                       $_.Status = "Idle"
                    }
                }
            }
        }

        # $Result = $powershell.EndInvoke($Variables.CycleRunspaceHandle)
        if ($CycleRunspace) {$CycleRunspace.Close()}
        if ($powershell) {$powershell.Dispose()}

        if ($IdleRunspace) {$IdleRunspace.Close()}
        if ($idlePowershell) {$idlePowershell.Dispose()}

})

$Config = Load-Config -ConfigFile $ConfigFile
If ($Config -and $Config.Interval -and $Config.PoolName -and (-not $Config.InstanceGuid -or -not $Config.RigID)) {
	$Config | Add-Member -Force @{InstanceGuid = (New-Guid).Guid}
}
$Config | Add-Member -Force @{RigID = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID}
If ( ! $Config.ConfigFile ) { $Config | Add-Member -Force @{ConfigFile = ".\Config\Config.json"} }
If ( $Config.ConfigFile -and (ls Function:\Write-Config) ) {
    Write-Config -ConfigFile $Config.ConfigFile -Config $Config
    $ConfigLoad = Get-Content $Config.ConfigFile | ConvertFrom-json
    $ConfigLoad | % {$_.psobject.properties | sort Name | % {$Config | Add-Member -Force @{$_.Name = $_.Value}}}
} 	

$Config | Add-Member -Force -MemberType ScriptProperty -Name "PoolsConfig" -Value {
    If (Test-Path ".\Config\PoolsConfig.json"){
        get-content ".\Config\PoolsConfig.json" | ConvertFrom-json
    }else{
        [PSCustomObject]@{default=[PSCustomObject]@{
            Wallet = "bc1qh6c9544vpym6p5mrkukx3tek69ze2arqfvhwhl"
            UserName = "mrplus"
            WorkerName = "NPlusMinerNoCfg"
            PricePenaltyFactor = 1
        }}
    }
}

$MainForm | Add-Member -Name "Config" -Value $Config -MemberType NoteProperty -Force

$SelGPUDSTM = $Config.SelGPUDSTM
$SelGPUCC = $Config.SelGPUCC
$MainForm | Add-Member -Name "Variables" -Value $Variables -MemberType NoteProperty -Force

$Variables.CurrentProduct = (Get-Content .\Version.json | ConvertFrom-Json).Product
$Variables.CurrentVersion = [Version](Get-Content .\Version.json | ConvertFrom-Json).Version
$Variables.CurrentVersionAutoUpdated = (Get-Content .\Version.json | ConvertFrom-Json).AutoUpdated.Value
$Variables.APIHeaders = @{"Cache-Control"="no-cache";referer="https://$($Variables.CurrentProduct)/$($Variables.CurrentVersion)/$($Config.WorkerName)/$($Config.InstanceGuid)"}
$Variables.StatusText = "Idle"
$TabControl = New-object System.Windows.Forms.TabControl

Try{
    $DblBuff = ($TabControl.GetType()).GetProperty("DoubleBuffered", ('Instance','NonPublic'))
    $DblBuff.SetValue($MainForm, $True, $null)
} catch {}

$RunPage = New-Object System.Windows.Forms.TabPage
$RunPage.Text = "Run"
$SwitchingPage = New-Object System.Windows.Forms.TabPage
$SwitchingPage.Text = "Switching"
$ConfigPage = New-Object System.Windows.Forms.TabPage
$ConfigPage.Text = "Config"
$MonitoringPage = New-Object System.Windows.Forms.TabPage
$MonitoringPage.Text = "Monitoring"
$EstimationsPage = New-Object System.Windows.Forms.TabPage
$EstimationsPage.Text = "Benchmarks"
$ServerModePage = New-Object System.Windows.Forms.TabPage
$ServerModePage.Text = "Server Mode"

$tabControl.DataBindings.DefaultDataSourceUpdateMode = 0
$tabControl.Location = New-Object System.Drawing.Point(10,91)
$tabControl.Name = "tabControl"
$tabControl.width = 720
$tabControl.height = 359
$MainForm.Controls.Add($tabControl)
$TabControl.Controls.AddRange(@($RunPage, $SwitchingPage, $ConfigPage, $MonitoringPage, $EstimationsPage, $ServerModePage))

# Form Controls
    $MainFormControls = @()

    # $Logo = [System.Drawing.Image]::Fromfile('.\config\logo.png')
    $pictureBoxLogo = new-object Windows.Forms.PictureBox
    $pictureBoxLogo.Width = 47 #$img.Size.Width
    $pictureBoxLogo.Height = 47 #$img.Size.Height
    # $pictureBoxLogo.Image = $Logo
    $pictureBoxLogo.SizeMode = 1
    $pictureBoxLogo.ImageLocation = $Branding.LogoPath
    $MainFormControls += $pictureBoxLogo

    $LabelEarningsDetails                          = New-Object system.Windows.Forms.TextBox
    $LabelEarningsDetails.Tag                      = ""
    $LabelEarningsDetails.MultiLine                = $true
    $LabelEarningsDetails.text                     = ""
    $LabelEarningsDetails.AutoSize                 = $false
    $LabelEarningsDetails.width                    = 382 #200
    $LabelEarningsDetails.height                   = 47 #62
    $LabelEarningsDetails.location                 = New-Object System.Drawing.Point(57,2)
    $LabelEarningsDetails.Font                     = 'lucida console,10'
    $LabelEarningsDetails.BorderStyle              = 'None'
    $LabelEarningsDetails.BackColor                = [System.Drawing.SystemColors]::Control
    $LabelEarningsDetails.ForeColor                = "Green"
    $LabelEarningsDetails.Visible                  = $True
    # $TBNotifications.TextAlign                = "Right"
    $MainFormControls += $LabelEarningsDetails

    $LabelBTCD                          = New-Object system.Windows.Forms.Label
    $LabelBTCD.text                     = "BTC/D"
    $LabelBTCD.AutoSize                 = $False
    $LabelBTCD.width                    = 473
    $LabelBTCD.height                   = 35
    $LabelBTCD.location                 = New-Object System.Drawing.Point(247,2)
    $LabelBTCD.Font                     = 'Microsoft Sans Serif,14'
    $LabelBTCD.TextAlign                = "MiddleRight"
    $LabelBTCD.ForeColor                = "Green"
    $LabelBTCD.Backcolor               = "Transparent"
    # $LabelBTCD.BorderStyle              = 'FixedSingle'
    $MainFormControls += $LabelBTCD

    $LabelBTCPrice                          = New-Object system.Windows.Forms.Label
    $LabelBTCPrice.text                     = If($Variables.Rates.$Currency -gt 0){"BTC/$($Config.Currency) $($Variables.Rates.$Currency)"}
    $LabelBTCPrice.AutoSize                 = $false
    $LabelBTCPrice.width                    = 400
    $LabelBTCPrice.height                   = 20
    $LabelBTCPrice.location                 = New-Object System.Drawing.Point(630,39)
    $LabelBTCPrice.Font                     = 'Microsoft Sans Serif,8'
    # $LabelBTCPrice.ForeColor              = "Gray"
    $MainFormControls += $LabelBTCPrice

    $ButtonPause                         = New-Object system.Windows.Forms.Button
    $ButtonPause.text                    = "Pause"
    $ButtonPause.width                   = 60
    $ButtonPause.height                  = 30
    $ButtonPause.location                = New-Object System.Drawing.Point(610,62)
    $ButtonPause.Font                    = 'Microsoft Sans Serif,10'
    $ButtonPause.Visible                 = $False
    $MainFormControls += $ButtonPause

    $ButtonStart                         = New-Object system.Windows.Forms.Button
    $ButtonStart.text                    = "Start"
    $ButtonStart.width                   = 60
    $ButtonStart.height                  = 30
    $ButtonStart.location                = New-Object System.Drawing.Point(670,62)
    $ButtonStart.Font                    = 'Microsoft Sans Serif,10'
    $MainFormControls += $ButtonStart

    $LabelNotifications                          = New-Object system.Windows.Forms.TextBox
    $LabelNotifications.Tag                      = ""
    $LabelNotifications.MultiLine                = $true
    # $TBNotifications.Scrollbars             = "Vertical" 
    $LabelNotifications.text                     = ""
    $LabelNotifications.AutoSize                 = $false
    $LabelNotifications.width                    = 280
    $LabelNotifications.height                   = 18
    $LabelNotifications.location                 = New-Object System.Drawing.Point(10,49)
    $LabelNotifications.Font                     = 'Microsoft Sans Serif,10'
    $LabelNotifications.BorderStyle              = 'None'
    $LabelNotifications.BackColor                = [System.Drawing.SystemColors]::Control
    $LabelNotifications.Visible                  = $True
    # $TBNotifications.TextAlign                = "Right"
    $MainFormControls += $LabelNotifications

    $LabelAddress                          = New-Object system.Windows.Forms.Label
    $LabelAddress.text                     = "Wallet Address"
    $LabelAddress.AutoSize                 = $false
    $LabelAddress.width                    = 100
    $LabelAddress.height                   = 20
    $LabelAddress.location                 = New-Object System.Drawing.Point(10,68)
    $LabelAddress.Font                     = 'Microsoft Sans Serif,10'
    $MainFormControls += $LabelAddress

    $TBAddress                          = New-Object system.Windows.Forms.TextBox
    $TBAddress.Tag                      = "Wallet"
    $TBAddress.MultiLine                = $False
    # $TBAddress.Scrollbars             = "Vertical" 
    $TBAddress.text                     = $Config.Wallet
    $TBAddress.AutoSize                 = $false
    $TBAddress.width                    = 280
    $TBAddress.height                   = 20
    $TBAddress.location                 = New-Object System.Drawing.Point(112,68)
    $TBAddress.Font                     = 'Microsoft Sans Serif,10'
    # $TBAddress.TextAlign                = "Right"
    $MainFormControls += $TBAddress

# Run Page Controls
    $RunPageControls = @()

    $LabelStatus                          = New-Object system.Windows.Forms.TextBox
    $LabelStatus.MultiLine                = $true
    $LabelStatus.Scrollbars               = "Vertical" 
    $LabelStatus.text                     = ""
    $LabelStatus.AutoSize                 = $true
    $LabelStatus.width                    = 712
    $LabelStatus.height                   = 50
    $LabelStatus.location                 = New-Object System.Drawing.Point(2,2)
    $LabelStatus.Font                     = 'Microsoft Sans Serif,10'
    $RunPageControls += $LabelStatus
 
    $LabelEarnings                          = New-Object system.Windows.Forms.Label
    $LabelEarnings.text                     = "Earnings Tracker (Past 7 days earnings / Per pool earnings two days)"
    $LabelEarnings.AutoSize                 = $false
    $LabelEarnings.width                    = 600
    $LabelEarnings.height                   = 20
    $LabelEarnings.location                 = New-Object System.Drawing.Point(2,54)
    $LabelEarnings.Font                     = 'Microsoft Sans Serif,10'
    $RunPageControls += $LabelEarnings

    If (Test-Path ".\logs\DailyEarnings.csv"){
        $Chart1 = Invoke-Expression -Command ".\Includes\Charting.ps1 -Chart 'Front7DaysEarnings' -Width 505 -Height 85 -Currency $($Config.Passwordcurrency)"
        $Chart1.top = 74
        $Chart1.left = 2
        $RunPageControls += $Chart1
    }
    If (Test-Path ".\logs\DailyEarnings.csv"){
        $Chart2 = Invoke-Expression -Command ".\Includes\Charting.ps1 -Chart 'DayPoolSplit' -Width 200 -Height 85 -Currency $($Config.Passwordcurrency)"
        $Chart2.top = 74
        $Chart2.left = 500
        $RunPageControls += $Chart2
    }

    $EarningsDGV                                            = New-Object system.Windows.Forms.DataGridView
    $EarningsDGV.width                                      = 712
    # $EarningsDGV.height                                     = 305
    # $EarningsDGV.height                                     = 170
    $EarningsDGV.height                                     = 85
    $EarningsDGV.location                                   = New-Object System.Drawing.Point(2,159)
    $EarningsDGV.DataBindings.DefaultDataSourceUpdateMode   = 0
    $EarningsDGV.AutoSizeColumnsMode                        = "Fill"
    $EarningsDGV.RowHeadersVisible                          = $False
    $RunPageControls += $EarningsDGV

    $LabelGitHub                    = New-Object System.Windows.Forms.LinkLabel
    # $LabelGitHub.Location           = New-Object System.Drawing.Size(415,39)
    # $LabelGitHub.Size               = New-Object System.Drawing.Size(160,18)
    $LabelGitHub.Location           = New-Object System.Drawing.Size(600,246)
    $LabelGitHub.Size               = New-Object System.Drawing.Size(160,20)
    $LabelGitHub.LinkColor          = "BLUE"
    $LabelGitHub.ActiveLinkColor    = "BLUE"
    $LabelGitHub.Text               = "Help? Join on Discord"
    $LabelGitHub.add_Click({[system.Diagnostics.Process]::start("https://discord.gg/2BCqPxe")})
    $RunPageControls += $LabelGitHub

    $LabelCopyright                 = New-Object System.Windows.Forms.LinkLabel
    # $LabelCopyright.Location        = New-Object System.Drawing.Size(415,61)
    # $LabelCopyright.Size            = New-Object System.Drawing.Size(200,20)
    $LabelCopyright.Location        = New-Object System.Drawing.Size(395,246)
    $LabelCopyright.Size            = New-Object System.Drawing.Size(200,20)
    $LabelCopyright.LinkColor       = "BLUE"
    $LabelCopyright.ActiveLinkColor = "BLUE"
    $LabelCopyright.Text            = "Copyright (c) 2018-$((Get-Date).year) MrPlus"
    $LabelCopyright.add_Click({[system.Diagnostics.Process]::start("https://github.com/MrPlusGH/NPlusMiner/blob/master/LICENSE")})
    $RunPageControls += $LabelCopyright

    $LabelWebUI                 = New-Object System.Windows.Forms.LinkLabel
    # $LabelWebUI.Location        = New-Object System.Drawing.Size(415,61)
    # $LabelWebUI.Size            = New-Object System.Drawing.Size(200,20)
    $LabelWebUI.Location        = New-Object System.Drawing.Size(250,246)
    $LabelWebUI.Size            = New-Object System.Drawing.Size(200,20)
    $LabelWebUI.LinkColor       = "BLUE"
    $LabelWebUI.ActiveLinkColor = "BLUE"
    $LabelWebUI.Text            = "Web interface"
    $LabelWebUI.add_Click({[system.Diagnostics.Process]::start("http://$($Config.Server_ClientUser):$($Config.Server_ClientPassword)@$($Config.Server_ClientIP):$($Config.Server_ClientPort)/Status")})
    $RunPageControls += $LabelWebUI

    $LabelRunningMiners                          = New-Object system.Windows.Forms.Label
    $LabelRunningMiners.text                     = "Running Miners"
    $LabelRunningMiners.AutoSize                 = $false
    $LabelRunningMiners.width                    = 200
    $LabelRunningMiners.height                   = 20
    $LabelRunningMiners.location                 = New-Object System.Drawing.Point(2,246)
    $LabelRunningMiners.Font                     = 'Microsoft Sans Serif,10'
    $RunPageControls += $LabelRunningMiners

    $RunningMinersDGV                                            = New-Object system.Windows.Forms.DataGridView
    $RunningMinersDGV.width                                      = 712
    # $EarningsDGV.height                                     = 305
    $RunningMinersDGV.height                                     = 95
    $RunningMinersDGV.location                                   = New-Object System.Drawing.Point(2,266)
    $RunningMinersDGV.DataBindings.DefaultDataSourceUpdateMode   = 0
    $RunningMinersDGV.AutoSizeColumnsMode                        = "Fill"
    $RunningMinersDGV.RowHeadersVisible                          = $False
    $RunPageControls += $RunningMinersDGV

    $RunPageControls | foreach {
        # If ($_.GetType() -ne "System.Windows.Forms.DataGridView") {
            Try{
                $DblBuff = ($_.GetType()).GetProperty("DoubleBuffered", ('Instance','NonPublic'))
                $DblBuff.SetValue($MainForm, $True, $null)
            } catch {}
        # }
    }

# Switching Page Controls
    $SwitchingPageControls = @()
    
    $CheckShowSwitchingCPU                       = New-Object system.Windows.Forms.CheckBox
    $CheckShowSwitchingCPU.Tag                       = "CPU"
    $CheckShowSwitchingCPU.text                  = "CPU"
    $CheckShowSwitchingCPU.AutoSize              = $false
    $CheckShowSwitchingCPU.width                 = 60
    $CheckShowSwitchingCPU.height                = 20
    $CheckShowSwitchingCPU.location              = New-Object System.Drawing.Point(2,2)
    $CheckShowSwitchingCPU.Font                  = 'Microsoft Sans Serif,10'
    $CheckShowSwitchingCPU.Checked               = ("CPU" -in $Config.Type)
    $SwitchingPageControls += $CheckShowSwitchingCPU
    
    $CheckShowSwitchingCPU | foreach {$_.Add_Click({CheckBoxSwitching_Click($This)})}

    $CheckShowSwitchingNVIDIA                       = New-Object system.Windows.Forms.CheckBox
    $CheckShowSwitchingNVIDIA.Tag                   = "NVIDIA"
    $CheckShowSwitchingNVIDIA.text                  = "NVIDIA"
    $CheckShowSwitchingNVIDIA.AutoSize              = $false
    $CheckShowSwitchingNVIDIA.width                 = 70
    $CheckShowSwitchingNVIDIA.height                = 20
    $CheckShowSwitchingNVIDIA.location              = New-Object System.Drawing.Point(62,2)
    $CheckShowSwitchingNVIDIA.Font                  = 'Microsoft Sans Serif,10'
    $CheckShowSwitchingNVIDIA.Checked               = ("NVIDIA" -in $Config.Type)
    $SwitchingPageControls += $CheckShowSwitchingNVIDIA
    
    $CheckShowSwitchingAMD = New-Object system.Windows.Forms.CheckBox
    $CheckShowSwitchingAMD.Tag = "AMD"
    $CheckShowSwitchingAMD.text = "AMD"
    $CheckShowSwitchingAMD.AutoSize = $false
    $CheckShowSwitchingAMD.width = 100
    $CheckShowSwitchingAMD.height = 20
    $CheckShowSwitchingAMD.location = New-Object System.Drawing.Point(137, 2)
    $CheckShowSwitchingAMD.Font = 'Microsoft Sans Serif,10'
    $CheckShowSwitchingAMD.Checked = ("AMD" -in $Config.Type)
    $SwitchingPageControls += $CheckShowSwitchingAMD
        
    $CheckShowSwitchingAMD | foreach {$_.Add_Click( {CheckBoxSwitching_Click($This)})}
    
    $CheckShowSwitchingNVIDIA | foreach {$_.Add_Click({CheckBoxSwitching_Click($This)})}
    
    Function CheckBoxSwitching_Click {
        $SwitchingDisplayTypes = @()
        $SwitchingPageControls | foreach {if ($_.Checked){$SwitchingDisplayTypes += $_.Tag}}
        # If (Test-Path ".\Logs\switching.log"){$log=Import-Csv ".\Logs\switching.log" | ? {$_.Type -in $SwitchingDisplayTypes} | Select -Last 13}
        # $SwitchingArray = [System.Collections.ArrayList]@($Log)
        # If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(Import-Csv ".\Logs\switching.log" | ? {$_.Type -in $SwitchingDisplayTypes} | Select -Last 13)}
        If (Test-Path ".\Logs\switching.log"){$SwitchingArray = [System.Collections.ArrayList]@(@((get-content ".\Logs\switching.log" -First 1) , (get-content ".\logs\switching.log" -last 50)) | ConvertFrom-Csv | ? {$_.Type -in $SwitchingDisplayTypes} | Select -Last 13)}
        $SwitchingDGV.DataSource        = $SwitchingArray
    }


    $SwitchingDGV                                           = New-Object system.Windows.Forms.DataGridView
    $SwitchingDGV.width                                     = 712
    $SwitchingDGV.height                                    = 333
    $SwitchingDGV.location                                  = New-Object System.Drawing.Point(2,22)
    $SwitchingDGV.DataBindings.DefaultDataSourceUpdateMode  = 0
    $SwitchingDGV.AutoSizeColumnsMode                       = "Fill"
    $SwitchingDGV.RowHeadersVisible                         = $False
    $SwitchingDGV.DataSource                                = $SwitchingArray
    $SwitchingPageControls += $SwitchingDGV

    # $SwitchingPageControls | foreach {
        # Try{
            # $DblBuff = ($_.GetType()).GetProperty("DoubleBuffered", ('Instance','NonPublic'))
            # $DblBuff.SetValue($MainForm, $Truen, $null)
        # } catch {}
    # }

    # Estimations Page Controls
    $EstimationsDGV                                             = New-Object system.Windows.Forms.DataGridView
    $EstimationsDGV.width                                       = 712
    $EstimationsDGV.height                                      = 350
    $EstimationsDGV.location                                    = New-Object System.Drawing.Point(2,2)
    $EstimationsDGV.DataBindings.DefaultDataSourceUpdateMode    = 0
    $EstimationsDGV.AutoSizeColumnsMode                         = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $EstimationsDGV.RowHeadersVisible                           = $False

    # $DblBuff = ($EstimationsDGV.GetType()).GetProperty("DoubleBuffered", ('Instance','NonPublic'))
    # $DblBuff.SetValue($MainForm, $Truen, $null)

# Server mode Page Controls
    $ServermodePageControls = @()
    
    $CheckBoxStandalone                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxStandalone.Tag                   = "Server_Standalone"
    $CheckBoxStandalone.text                  = "Standalone"
    $CheckBoxStandalone.AutoSize              = $false
    $CheckBoxStandalone.width                 = 200
    $CheckBoxStandalone.height                = 20
    $CheckBoxStandalone.location              = New-Object System.Drawing.Point(2,2)
    $CheckBoxStandalone.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxStandalone.Checked               = $Config.Server_Standalone
    $ServermodePageControls += $CheckBoxStandalone

    $CheckBoxBeAServer                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxBeAServer.Tag                   = "Server_On"
    $CheckBoxBeAServer.text                  = "Be a server"
    $CheckBoxBeAServer.AutoSize              = $false
    $CheckBoxBeAServer.width                 = 140
    $CheckBoxBeAServer.height                = 20
    $CheckBoxBeAServer.location              = New-Object System.Drawing.Point(2,24)
    $CheckBoxBeAServer.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxBeAServer.Checked               =   $Config.Server_On
    $ServermodePageControls += $CheckBoxBeAServer

    $LabelServerPort                          = New-Object system.Windows.Forms.Label
    $LabelServerPort.text                     = "Server Port"
    $LabelServerPort.AutoSize                 = $false
    $LabelServerPort.width                    = 120
    $LabelServerPort.height                   = 20
    $LabelServerPort.location                 = New-Object System.Drawing.Point(2,48)
    $LabelServerPort.Font                     = 'Microsoft Sans Serif,10'
    # $LabelServerPort.Enabled                  = $CheckBoxBeAServer.Checked
    $ServermodePageControls += $LabelServerPort

    $TBServerPort                          = New-Object system.Windows.Forms.TextBox
    $TBServerPort.Tag                      = "Server_Port"
    $TBServerPort.MultiLine                = $False
    # $TBServerPort.Scrollbars              = "Vertical" 
    $TBServerPort.text                     = $Config.Server_Port
    $TBServerPort.AutoSize                 = $false
    $TBServerPort.width                    = 50
    $TBServerPort.height                   = 20
    $TBServerPort.location                 = New-Object System.Drawing.Point(122,48)
    $TBServerPort.Font                     = 'Microsoft Sans Serif,10'
    # $TBServerPort.Enabled                  = $CheckBoxBeAServer.Checked
    $ServermodePageControls += $TBServerPort

    $LabelServerUser                          = New-Object system.Windows.Forms.Label
    $LabelServerUser.text                     = "Server User"
    $LabelServerUser.AutoSize                 = $false
    $LabelServerUser.width                    = 120
    $LabelServerUser.height                   = 20
    $LabelServerUser.location                 = New-Object System.Drawing.Point(2,72)
    $LabelServerUser.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $LabelServerUser

    $TBServerUser                          = New-Object system.Windows.Forms.TextBox
    $TBServerUser.Tag                      = "Server_User"
    $TBServerUser.MultiLine                = $False
    # $TBServerIP.Scrollbars              = "Vertical" 
    $TBServerUser.text                     = $Config.Server_User
    $TBServerUser.AutoSize                 = $false
    $TBServerUser.width                    = 150
    $TBServerUser.height                   = 20
    $TBServerUser.location                 = New-Object System.Drawing.Point(122,72)
    $TBServerUser.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $TBServerUser

    $LabelServerPassword                          = New-Object system.Windows.Forms.Label
    $LabelServerPassword.text                     = "Server Password"
    $LabelServerPassword.AutoSize                 = $false
    $LabelServerPassword.width                    = 120
    $LabelServerPassword.height                   = 20
    $LabelServerPassword.location                 = New-Object System.Drawing.Point(274,72)
    $LabelServerPassword.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $LabelServerPassword

    $TBServerPassword                          = New-Object system.Windows.Forms.TextBox
    $TBServerPassword.Tag                      = "Server_Password"
    $TBServerPassword.MultiLine                = $False
    # $TBServerPassword.Scrollbars              = "Vertical" 
    $TBServerPassword.text                     = if ($Config.Server_Password) {$Config.Server_Password} else {(New-Guid).guid}
    $TBServerPassword.AutoSize                 = $false
    $TBServerPassword.width                    = 150
    $TBServerPassword.height                   = 20
    $TBServerPassword.location                 = New-Object System.Drawing.Point(396,72)
    $TBServerPassword.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $TBServerPassword
    
    $CheckBoxServerClient                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxServerClient.Tag                   = "Server_Client"
    $CheckBoxServerClient.text                  = "Use a server"
    $CheckBoxServerClient.AutoSize              = $false
    $CheckBoxServerClient.width                 = 140
    $CheckBoxServerClient.height                = 20
    $CheckBoxServerClient.location              = New-Object System.Drawing.Point(2,94)
    $CheckBoxServerClient.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxServerClient.Checked               =   $Config.Server_Client
    $ServermodePageControls += $CheckBoxServerClient

    $LabelServerClientIP                          = New-Object system.Windows.Forms.Label
    $LabelServerClientIP.text                     = "Server IP"
    $LabelServerClientIP.AutoSize                 = $false
    $LabelServerClientIP.width                    = 120
    $LabelServerClientIP.height                   = 20
    $LabelServerClientIP.location                 = New-Object System.Drawing.Point(2,116)
    $LabelServerClientIP.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $LabelServerClientIP

    $TBServerClientIP                          = New-Object system.Windows.Forms.TextBox
    $TBServerClientIP.Tag                      = "Server_ClientIP"
    $TBServerClientIP.MultiLine                = $False
    # $TBServerClientIP.Scrollbars              = "Vertical" 
    $TBServerClientIP.text                     = $Config.Server_ClientIP
    $TBServerClientIP.AutoSize                 = $false
    $TBServerClientIP.width                    = 150
    $TBServerClientIP.height                   = 20
    $TBServerClientIP.location                 = New-Object System.Drawing.Point(122,116)
    $TBServerClientIP.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $TBServerClientIP

    $LabelServerClientPort                          = New-Object system.Windows.Forms.Label
    $LabelServerClientPort.text                     = "Port"
    $LabelServerClientPort.AutoSize                 = $false
    $LabelServerClientPort.width                    = 120
    $LabelServerClientPort.height                   = 20
    $LabelServerClientPort.location                 = New-Object System.Drawing.Point(274,116)
    $LabelServerClientPort.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $LabelServerClientPort

    $TBServerClientPort                          = New-Object system.Windows.Forms.TextBox
    $TBServerClientPort.Tag                      = "Server_ClientPort"
    $TBServerClientPort.MultiLine                = $False
    # $TBServerClientPort.Scrollbars              = "Vertical" 
    $TBServerClientPort.text                     = $Config.Server_ClientPort
    $TBServerClientPort.AutoSize                 = $false
    $TBServerClientPort.width                    = 50
    $TBServerClientPort.height                   = 20
    $TBServerClientPort.location                 = New-Object System.Drawing.Point(396,116)
    $TBServerClientPort.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $TBServerClientPort

    $LabelServerClientUser                          = New-Object system.Windows.Forms.Label
    $LabelServerClientUser.text                     = "Server User"
    $LabelServerClientUser.AutoSize                 = $false
    $LabelServerClientUser.width                    = 120
    $LabelServerClientUser.height                   = 20
    $LabelServerClientUser.location                 = New-Object System.Drawing.Point(2,138)
    $LabelServerClientUser.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $LabelServerClientUser

    $TBServerClientUser                          = New-Object system.Windows.Forms.TextBox
    $TBServerClientUser.Tag                      = "Server_ClientUser"
    $TBServerClientUser.MultiLine                = $False
    # $TBServerClientUser.Scrollbars              = "Vertical" 
    $TBServerClientUser.text                     = $Config.Server_ClientUser
    $TBServerClientUser.AutoSize                 = $false
    $TBServerClientUser.width                    = 150
    $TBServerClientUser.height                   = 20
    $TBServerClientUser.location                 = New-Object System.Drawing.Point(122,138)
    $TBServerClientUser.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $TBServerClientUser

    $LabelServerClientPassword                          = New-Object system.Windows.Forms.Label
    $LabelServerClientPassword.text                     = "Server Password"
    $LabelServerClientPassword.AutoSize                 = $false
    $LabelServerClientPassword.width                    = 120
    $LabelServerClientPassword.height                   = 20
    $LabelServerClientPassword.location                 = New-Object System.Drawing.Point(274,138)
    $LabelServerClientPassword.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $LabelServerClientPassword

    $TBServerClientPassword                          = New-Object system.Windows.Forms.TextBox
    $TBServerClientPassword.Tag                      = "Server_ClientPassword"
    $TBServerClientPassword.MultiLine                = $False
    # $TBServerClientPassword.Scrollbars              = "Vertical" 
    $TBServerClientPassword.text                     = $Config.Server_ClientPassword
    $TBServerClientPassword.AutoSize                 = $false
    $TBServerClientPassword.width                    = 150
    $TBServerClientPassword.height                   = 20
    $TBServerClientPassword.location                 = New-Object System.Drawing.Point(396,138)
    $TBServerClientPassword.Font                     = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $TBServerClientPassword

    $ButtonWriteServerConfig                         = New-Object system.Windows.Forms.Button
    $ButtonWriteServerConfig.text                    = "Save Config"
    $ButtonWriteServerConfig.width                   = 100
    $ButtonWriteServerConfig.height                  = 30
    $ButtonWriteServerConfig.location                = New-Object System.Drawing.Point(610,300)
    $ButtonWriteServerConfig.Font                    = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $ButtonWriteServerConfig

    $ButtonWriteServerConfig.Add_Click({PrepareWriteConfig})

    $ButtonCreateFWRules                         = New-Object system.Windows.Forms.Button
    $ButtonCreateFWRules.text                    = "Create Firewall rules"
    $ButtonCreateFWRules.width                   = 200
    $ButtonCreateFWRules.height                  = 30
    $ButtonCreateFWRules.location                = New-Object System.Drawing.Point(400,300)
    $ButtonCreateFWRules.Font                    = 'Microsoft Sans Serif,10'
    $ServermodePageControls += $ButtonCreateFWRules

    $ButtonCreateFWRules.Add_Click({
        . .\Includes\Server.ps1
        $Variables.IsAdminSession = $True
        Initialize-ServerRules $Config.Server_Port
        $Variables.IsAdminSession = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    })
    

# Config Page Controls
    $ConfigPageControls = @()

    $LabelWorkerName                          = New-Object system.Windows.Forms.Label
    $LabelWorkerName.text                     = "Worker Name"
    $LabelWorkerName.AutoSize                 = $false
    $LabelWorkerName.width                    = 120
    $LabelWorkerName.height                   = 20
    $LabelWorkerName.location                 = New-Object System.Drawing.Point(2,2)
    $LabelWorkerName.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelWorkerName

    $TBWorkerName                          = New-Object system.Windows.Forms.TextBox
    $TBWorkerName.Tag                      = "WorkerName"
    $TBWorkerName.MultiLine                = $False
    # $TBWorkerName.Scrollbars              = "Vertical" 
    $TBWorkerName.text                     = $Config.WorkerName
    $TBWorkerName.AutoSize                 = $false
    $TBWorkerName.width                    = 300
    $TBWorkerName.height                   = 20
    $TBWorkerName.location                 = New-Object System.Drawing.Point(122,2)
    $TBWorkerName.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBWorkerName

     
    $LabelUserName                          = New-Object system.Windows.Forms.Label
    $LabelUserName.text                     = "MPH UserName"
    $LabelUserName.AutoSize                 = $false
    $LabelUserName.width                    = 120
    $LabelUserName.height                   = 20
    $LabelUserName.location                 = New-Object System.Drawing.Point(2,24)
    $LabelUserName.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelUserName

    $TBUserName                          = New-Object system.Windows.Forms.TextBox
    $TBUserName.Tag                      = "UserName"
    $TBUserName.MultiLine                = $False
    # $TBUserName.Scrollbars                = "Vertical" 
    $TBUserName.text                     = $Config.UserName
    $TBUserName.AutoSize                 = $false
    $TBUserName.width                    = 300
    $TBUserName.height                   = 20
    $TBUserName.location                 = New-Object System.Drawing.Point(122,24)
    $TBUserName.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBUserName

    $LabelInterval                          = New-Object system.Windows.Forms.Label
    $LabelInterval.text                     = "Interval"
    $LabelInterval.AutoSize                 = $false
    $LabelInterval.width                    = 120
    $LabelInterval.height                   = 20
    $LabelInterval.location                 = New-Object System.Drawing.Point(2,46)
    $LabelInterval.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelInterval

    $TBInterval                          = New-Object system.Windows.Forms.TextBox
    $TBInterval.Tag                      = "Interval"
    $TBInterval.MultiLine                = $False
    # $TBWorkerName.Scrollbars              = "Vertical" 
    $TBInterval.text                     = $Config.Interval
    $TBInterval.AutoSize                 = $false
    $TBInterval.width                    = 300
    $TBInterval.height                   = 20
    $TBInterval.location                 = New-Object System.Drawing.Point(122,46)
    $TBInterval.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBInterval

    $LabelLocation                          = New-Object system.Windows.Forms.Label
    $LabelLocation.text                     = "Location"
    $LabelLocation.AutoSize                 = $false
    $LabelLocation.width                    = 120
    $LabelLocation.height                   = 20
    $LabelLocation.location                 = New-Object System.Drawing.Point(2,68)
    $LabelLocation.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelLocation

    $TBLocation                          = New-Object system.Windows.Forms.TextBox
    $TBLocation.Tag                      = "Location"
    $TBLocation.MultiLine                = $False
    # $TBLocation.Scrollbars                = "Vertical" 
    $TBLocation.text                     = $Config.Location
    $TBLocation.AutoSize                 = $false
    $TBLocation.width                    = 300
    $TBLocation.height                   = 20
    $TBLocation.location                 = New-Object System.Drawing.Point(122,68)
    $TBLocation.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBLocation

    $LabelGPUCount                          = New-Object system.Windows.Forms.Label
    $LabelGPUCount.text                     = "GPU Count"
    $LabelGPUCount.AutoSize                 = $false
    $LabelGPUCount.width                    = 120
    $LabelGPUCount.height                   = 20
    $LabelGPUCount.location                 = New-Object System.Drawing.Point(2,90)
    $LabelGPUCount.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelGPUCount

    $TBGPUCount                          = New-Object system.Windows.Forms.TextBox
    $TBGPUCount.Tag                      = "GPUCount"
    $TBGPUCount.MultiLine                = $False
    # $TBGPUCount.Scrollbars                = "Vertical" 
    $TBGPUCount.text                     = $Config.GPUCount
    $TBGPUCount.AutoSize                 = $false
    $TBGPUCount.width                    = 50
    $TBGPUCount.height                   = 20
    $TBGPUCount.location                 = New-Object System.Drawing.Point(122,90)
    $TBGPUCount.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBGPUCount

    $CheckBoxDisableGPU0                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxDisableGPU0.Tag                   = "DisableGPU0"
    $CheckBoxDisableGPU0.text                  = "Disable GPU0"
    $CheckBoxDisableGPU0.AutoSize              = $false
    $CheckBoxDisableGPU0.width                 = 140
    $CheckBoxDisableGPU0.height                = 20
    $CheckBoxDisableGPU0.location              = New-Object System.Drawing.Point(177,90)
    $CheckBoxDisableGPU0.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxDisableGPU0.Checked               =   $Config.DisableGPU0
    $ConfigPageControls += $CheckBoxDisableGPU0
    
    $ButtonDetectGPU                         = New-Object system.Windows.Forms.Button
    $ButtonDetectGPU.text                    = "Detect GPU"
    $ButtonDetectGPU.width                   = 100
    $ButtonDetectGPU.height                  = 20
    $ButtonDetectGPU.location                = New-Object System.Drawing.Point(320,90)
    $ButtonDetectGPU.Font                    = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $ButtonDetectGPU

    $ButtonDetectGPU.Add_Click({
        $DetectedGPU = @(DetectGPUCount)
        $Config | Add-Member -Force @{DetectedGPU = $DetectedGPU}
        $TBGPUCount.text = $DetectedGPU.Count
    })

    $LabelAlgos                          = New-Object system.Windows.Forms.Label
    $LabelAlgos.text                     = "Algorithm"
    $LabelAlgos.AutoSize                 = $false
    $LabelAlgos.width                    = 120
    $LabelAlgos.height                   = 20
    $LabelAlgos.location                 = New-Object System.Drawing.Point(2,112)
    $LabelAlgos.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelAlgos

    $TBAlgos                          = New-Object system.Windows.Forms.TextBox
    $TBAlgos.Tag                      = "Algorithm"
    $TBAlgos.MultiLine                = $False
    # $TBAlgos.Scrollbars               = "Vertical" 
    $TBAlgos.text                     = $Config.Algorithm -Join ","
    $TBAlgos.AutoSize                 = $false
    $TBAlgos.width                    = 300
    $TBAlgos.height                   = 20
    $TBAlgos.location                 = New-Object System.Drawing.Point(122,112)
    $TBAlgos.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBAlgos

    $LabelCurrency                          = New-Object system.Windows.Forms.Label
    $LabelCurrency.text                     = "Currency"
    $LabelCurrency.AutoSize                 = $false
    $LabelCurrency.width                    = 120
    $LabelCurrency.height                   = 20
    $LabelCurrency.location                 = New-Object System.Drawing.Point(2,134)
    $LabelCurrency.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelCurrency

    $TBCurrency                          = New-Object system.Windows.Forms.TextBox
    $TBCurrency.Tag                      = "Currency"
    $TBCurrency.MultiLine                = $False
    # $TBCurrency.Scrollbars                = "Vertical" 
    $TBCurrency.text                     = $Config.Currency
    $TBCurrency.AutoSize                 = $false
    $TBCurrency.width                    = 300
    $TBCurrency.height                   = 20
    $TBCurrency.location                 = New-Object System.Drawing.Point(122,134)
    $TBCurrency.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBCurrency

    $LabelPwdCurrency                          = New-Object system.Windows.Forms.Label
    $LabelPwdCurrency.text                     = "Payout Currency"
    $LabelPwdCurrency.AutoSize                 = $false
    $LabelPwdCurrency.width                    = 120
    $LabelPwdCurrency.height                   = 20
    $LabelPwdCurrency.location                 = New-Object System.Drawing.Point(2,156)
    $LabelPwdCurrency.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelPwdCurrency

    $TBPwdCurrency                          = New-Object system.Windows.Forms.TextBox
    $TBPwdCurrency.Tag                      = "Passwordcurrency"
    $TBPwdCurrency.MultiLine                = $False
    # $TBPwdCurrency.Scrollbars             = "Vertical" 
    $TBPwdCurrency.text                     = $Config.Passwordcurrency
    $TBPwdCurrency.AutoSize                 = $false
    $TBPwdCurrency.width                    = 300
    $TBPwdCurrency.height                   = 20
    $TBPwdCurrency.location                 = New-Object System.Drawing.Point(122,156)
    $TBPwdCurrency.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBPwdCurrency

    $LabelDonate                          = New-Object system.Windows.Forms.Label
    $LabelDonate.text                     = "Donate (min)"
    $LabelDonate.AutoSize                 = $false
    $LabelDonate.width                    = 120
    $LabelDonate.height                   = 20
    $LabelDonate.location                 = New-Object System.Drawing.Point(2,268)
    $LabelDonate.Font                     = 'Microsoft Sans Serif,10'
    $LabelDonate.Visible                  = $False
    $ConfigPageControls += $LabelDonate

    $TBDonate                          = New-Object system.Windows.Forms.TextBox
    $TBDonate.Tag                      = "Donate"
    $TBDonate.MultiLine                = $False
    # $TBDonate.Scrollbars              = "Vertical" 
    $TBDonate.text                     = $Config.Donate
    $TBDonate.AutoSize                 = $false
    $TBDonate.width                    = 300
    $TBDonate.height                   = 20
    $TBDonate.location                 = New-Object System.Drawing.Point(122,268)
    $TBDonate.Font                     = 'Microsoft Sans Serif,10'
    $TBDonate.Visible                  = $False
    $ConfigPageControls += $TBDonate

    $LabelProxy                          = New-Object system.Windows.Forms.Label
    $LabelProxy.text                     = "Proxy"
    $LabelProxy.AutoSize                 = $false
    $LabelProxy.width                    = 120
    $LabelProxy.height                   = 20
    $LabelProxy.location                 = New-Object System.Drawing.Point(2,178)
    $LabelProxy.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelProxy

    $TBProxy                          = New-Object system.Windows.Forms.TextBox
    $TBProxy.Tag                      = "Proxy"
    $TBProxy.MultiLine                = $False
    # $TBProxy.Scrollbars               = "Vertical" 
    $TBProxy.text                     = $Config.Proxy
    $TBProxy.AutoSize                 = $false
    $TBProxy.width                    = 300
    $TBProxy.height                   = 20
    $TBProxy.location                 = New-Object System.Drawing.Point(122,178)    
    $TBProxy.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBProxy

    $LabelActiveMinerGainPct                          = New-Object system.Windows.Forms.Label
    $LabelActiveMinerGainPct.text                     = "ActiveMinerGain%"
    $LabelActiveMinerGainPct.AutoSize                 = $false
    $LabelActiveMinerGainPct.width                    = 120
    $LabelActiveMinerGainPct.height                   = 20
    $LabelActiveMinerGainPct.location                 = New-Object System.Drawing.Point(2,202)
    $LabelActiveMinerGainPct.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelActiveMinerGainPct

    $TBActiveMinerGainPct                          = New-Object system.Windows.Forms.TextBox
    $TBActiveMinerGainPct.Tag                      = "ActiveMinerGainPct"
    $TBActiveMinerGainPct.MultiLine                = $False
    # $TBActiveMinerGainPct.Scrollbars              = "Vertical" 
    $TBActiveMinerGainPct.text                     = $Config.ActiveMinerGainPct
    $TBActiveMinerGainPct.AutoSize                 = $false
    $TBActiveMinerGainPct.width                    = 300
    $TBActiveMinerGainPct.height                   = 20
    $TBActiveMinerGainPct.location                 = New-Object System.Drawing.Point(122,202)
    $TBActiveMinerGainPct.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBActiveMinerGainPct

    $LabelMPHAPIKey                          = New-Object system.Windows.Forms.Label
    $LabelMPHAPIKey.text                     = "MPH API Key"
    $LabelMPHAPIKey.AutoSize                 = $false
    $LabelMPHAPIKey.width                    = 120
    $LabelMPHAPIKey.height                   = 20
    $LabelMPHAPIKey.location                 = New-Object System.Drawing.Point(2,224)
    $LabelMPHAPIKey.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelMPHAPIKey

    $TBMPHAPIKey                          = New-Object system.Windows.Forms.TextBox
    $TBMPHAPIKey.Tag                      = "APIKEY"
    $TBMPHAPIKey.MultiLine                = $False
    $TBMPHAPIKey.text                     = $Config.APIKEY
    $TBMPHAPIKey.AutoSize                 = $false
    $TBMPHAPIKey.width                    = 300
    $TBMPHAPIKey.height                   = 20
    $TBMPHAPIKey.location                 = New-Object System.Drawing.Point(122,224)
    $TBMPHAPIKey.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $TBMPHAPIKey

    $LabelMinersTypes                          = New-Object system.Windows.Forms.Label
    $LabelMinersTypes.text                     = "Miners Types"
    $LabelMinersTypes.AutoSize                 = $false
    $LabelMinersTypes.width                    = 120
    $LabelMinersTypes.height                   = 20
    $LabelMinersTypes.location                 = New-Object System.Drawing.Point(2,246)
    $LabelMinersTypes.Font                     = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelMinersTypes

    $CheckBoxMinerTypeCPU                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxMinerTypeCPU.Tag                   = "TypeCPU"
    $CheckBoxMinerTypeCPU.text                  = "CPU"
    $CheckBoxMinerTypeCPU.AutoSize              = $false
    $CheckBoxMinerTypeCPU.width                 = 60
    $CheckBoxMinerTypeCPU.height                = 20
    $CheckBoxMinerTypeCPU.location              = New-Object System.Drawing.Point(124,246)
    $CheckBoxMinerTypeCPU.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxMinerTypeCPU.Checked               = ($CheckBoxMinerTypeCPU.text -in $Config.Type)
    $ConfigPageControls += $CheckBoxMinerTypeCPU
    
    $CheckBoxMinerTypeCPU.Add_Click({
        If ($This.checked -and $This.Text -notin $Config.Type){
            [Array]$Config.Type += $This.Text
            # If ($Variables."$($This.Text)MinerAPITCPPort" -eq $Null){
            If ($Variables."$($This.Text)MinerAPITCPPort" -eq $Null -or ($Variables.ActiveMinerPrograms | ? {$_.Status -eq "Running" -and $_.Type -eq $This.Text}) -eq $null){
                # Find available TCP Ports
                $StartPort = 4068
                Update-Status("Finding available TCP Port for $($This.Text)")
                $Port = Get-FreeTcpPort($StartPort)
                $Variables."$($This.Text)MinerAPITCPPort" = $Port
                Update-Status("Miners API Port: $($Port)")
                $StartPort = $Port+1
            }
        }else{$Config.Type = @($Config.Type | ? {$_ -ne $This.Text})}
    })

    $CheckBoxMinerTypeNVIDIA                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxMinerTypeNVIDIA.Tag                   = "TypeNVIDIA"
    $CheckBoxMinerTypeNVIDIA.text                  = "NVIDIA"
    $CheckBoxMinerTypeNVIDIA.AutoSize              = $false
    $CheckBoxMinerTypeNVIDIA.width                 = 70
    $CheckBoxMinerTypeNVIDIA.height                = 20
    $CheckBoxMinerTypeNVIDIA.location              = New-Object System.Drawing.Point(186,246)
    $CheckBoxMinerTypeNVIDIA.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxMinerTypeNVIDIA.Checked               = ($CheckBoxMinerTypeNVIDIA.text -in $Config.Type)
    $ConfigPageControls += $CheckBoxMinerTypeNVIDIA

    $CheckBoxMinerTypeNVIDIA.Add_Click({
        If ($This.checked -and $This.Text -notin $Config.Type){
            [Array]$Config.Type += $This.Text
            If ($Variables."$($This.Text)MinerAPITCPPort" -eq $Null -or ($Variables.ActiveMinerPrograms | ? {$_.Status -eq "Running" -and $_.Type -eq $This.Text}) -eq $null){
                # Find available TCP Ports
                $StartPort = 4068
                Update-Status("Finding available TCP Port for $($This.Text)")
                $Port = Get-FreeTcpPort($StartPort)
                $Variables."$($This.Text)MinerAPITCPPort" = $Port
                Update-Status("Miners API Port: $($Port)")
                $StartPort = $Port+1
            }
        }else{$Config.Type = @($Config.Type | ? {$_ -ne $This.Text})}
    })

    $CheckBoxMinerTypeAMD = New-Object system.Windows.Forms.CheckBox
    $CheckBoxMinerTypeAMD.Tag = "TypeAMD"
    $CheckBoxMinerTypeAMD.text = "AMD"
    $CheckBoxMinerTypeAMD.AutoSize = $false
    $CheckBoxMinerTypeAMD.width = 60
    $CheckBoxMinerTypeAMD.height = 20
    $CheckBoxMinerTypeAMD.location = New-Object System.Drawing.Point(261, 246)
    $CheckBoxMinerTypeAMD.Font = 'Microsoft Sans Serif,10'
    $CheckBoxMinerTypeAMD.Checked = ($CheckBoxMinerTypeAMD.text -in $Config.Type)
    $ConfigPageControls += $CheckBoxMinerTypeAMD

    $CheckBoxMinerTypeAMD.Add_Click( {
            If ($This.checked -and $This.Text -notin $Config.Type) {
                [Array]$Config.Type += $This.Text
                If ($Variables."$($This.Text)MinerAPITCPPort" -eq $Null -or ($Variables.ActiveMinerPrograms | ? {$_.Status -eq "Running" -and $_.Type -eq $This.Text}) -eq $null) {
                    # Find available TCP Ports
                    $StartPort = 4068
                    Update-Status("Finding available TCP Port for $($This.Text)")
                    $Port = Get-FreeTcpPort($StartPort)
                    $Variables."$($This.Text)MinerAPITCPPort" = $Port
                    Update-Status("Miners API Port: $($Port)")
                    $StartPort = $Port + 1
                }
            }
            else {$Config.Type = @($Config.Type | ? {$_ -ne $This.Text})}
        })

    $CheckBoxAutostart                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxAutostart.Tag                   = "Autostart"
    $CheckBoxAutostart.text                  = "Auto Start"
    $CheckBoxAutostart.AutoSize              = $false
    $CheckBoxAutostart.width                 = 100
    $CheckBoxAutostart.height                = 20
    $CheckBoxAutostart.location              = New-Object System.Drawing.Point(560,2)
    $CheckBoxAutostart.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxAutostart.Checked               =   $Config.Autostart
    $ConfigPageControls += $CheckBoxAutostart

    $CheckBoxAutoStart.Add_Click( {
            # Disable CheckBoxStartPaused and mine when idle when Auto Start is unchecked
            if ($CheckBoxAutoStart.Checked) {
                $CheckBoxStartPaused.Enabled = $True
                $CheckBoxMineWhenIdle.Enabled = $True
                $TBIdleSec.Enabled = $True
            }
            else {
                $CheckBoxStartPaused.Checked = $False
                $CheckBoxStartPaused.Enabled = $False
                $CheckBoxMineWhenIdle.Checked = $False
                $CheckBoxMineWhenIdle.Enabled = $False
                $TBIdleSec.Enabled = $False
            }
        })

    $CheckBoxStartPaused = New-Object system.Windows.Forms.CheckBox
    $CheckBoxStartPaused.Tag = "StartPaused"
    $CheckBoxStartPaused.text = "Pause on Auto Start"
    $CheckBoxStartPaused.AutoSize = $false
    $CheckBoxStartPaused.width = 160
    $CheckBoxStartPaused.height = 20
    $CheckBoxStartPaused.location = New-Object System.Drawing.Point(560, 24)
    $CheckBoxStartPaused.Font = 'Microsoft Sans Serif,10'
    $CheckBoxStartPaused.Checked = $Config.StartPaused
    $CheckBoxStartPaused.Enabled = $CheckBoxAutoStart.Checked
    $CheckBoxStartPaused.Visible = $False
    $ConfigPageControls += $CheckBoxStartPaused

    $CheckBoxMineWhenIdle = New-Object system.Windows.Forms.CheckBox
    $CheckBoxMineWhenIdle.Tag = "MineWhenIdle"
    $CheckBoxMineWhenIdle.text = "Mine only when idle"
    $CheckBoxMineWhenIdle.AutoSize = $false
    $CheckBoxMineWhenIdle.width = 160
    $CheckBoxMineWhenIdle.height = 20
    $CheckBoxMineWhenIdle.location = New-Object System.Drawing.Point(560, 24)
    $CheckBoxMineWhenIdle.Font = 'Microsoft Sans Serif,10'
    $CheckBoxMineWhenIdle.Checked = $Config.MineWhenIdle
    $CheckBoxMineWhenIdle.Enabled = $CheckBoxAutoStart.Checked
    $ConfigPageControls += $CheckBoxMineWhenIdle

    $TBIdleSec = New-Object system.Windows.Forms.TextBox
    $TBIdleSec.Tag = "IdleSec"
    $TBIdleSec.MultiLine = $False
    $TBIdleSec.text = if ($Config.IdleSec -gt 1) {$Config.IdleSec} else {120}
    $TBIdleSec.AutoSize = $false
    $TBIdleSec.width = 50
    $TBIdleSec.height = 20
    $TBIdleSec.location = New-Object System.Drawing.Point(580, 46)
    $TBIdleSec.Font = 'Microsoft Sans Serif,10'
    $TBIdleSec.Enabled = $CheckBoxAutoStart.Checked
    $ConfigPageControls += $TBIdleSec

    $LabelIdleSec = New-Object system.Windows.Forms.Label
    $LabelIdleSec.text = "seconds"
    $LabelIdleSec.AutoSize = $false
    $LabelIdleSec.width = 60
    $LabelIdleSec.height = 20
    $LabelIdleSec.location = New-Object System.Drawing.Point(630, 46)
    $LabelIdleSec.Font = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelIdleSec

    
    $CheckBoxEarningTrackerLogs                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxEarningTrackerLogs.Tag                   = "EnableEarningsTrackerLogs"
    $CheckBoxEarningTrackerLogs.text                  = "Earnings Tracker Logs"
    $CheckBoxEarningTrackerLogs.AutoSize              = $false
    $CheckBoxEarningTrackerLogs.width                 = 160
    $CheckBoxEarningTrackerLogs.height                = 20
    $CheckBoxEarningTrackerLogs.location              = New-Object System.Drawing.Point(560,68)
    $CheckBoxEarningTrackerLogs.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxEarningTrackerLogs.Checked               =   $Config.EnableEarningsTrackerLogs
    $ConfigPageControls += $CheckBoxEarningTrackerLogs

    $CheckBoxAutoUpdate                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxAutoUpdate.Tag                   = "AutoUpdate"
    $CheckBoxAutoUpdate.text                  = "Auto Update"
    $CheckBoxAutoUpdate.AutoSize              = $false
    $CheckBoxAutoUpdate.width                 = 100
    $CheckBoxAutoUpdate.height                = 20
    $CheckBoxAutoUpdate.location              = New-Object System.Drawing.Point(560,156)
    $CheckBoxAutoUpdate.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxAutoUpdate.Checked               =   $Config.AutoUpdate
    $CheckBoxAutoUpdate.Visible               =   $False
    # $CheckBoxAutoUpdate.Enabled               =   $False
    $ConfigPageControls += $CheckBoxAutoUpdate

    $CheckBoxGUIMinimized                       = New-Object system.Windows.Forms.CheckBox
    $CheckBoxGUIMinimized.Tag                   = "StartGUIMinimized"
    $CheckBoxGUIMinimized.text                  = "Start UI minimized"
    $CheckBoxGUIMinimized.AutoSize              = $false
    $CheckBoxGUIMinimized.width                 = 160
    $CheckBoxGUIMinimized.height                = 20
    $CheckBoxGUIMinimized.location              = New-Object System.Drawing.Point(560,112)
    $CheckBoxGUIMinimized.Font                  = 'Microsoft Sans Serif,10'
    $CheckBoxGUIMinimized.Checked               =   $Config.StartGUIMinimized
    $ConfigPageControls += $CheckBoxGUIMinimized

    $CheckBoxShowOnlyTopCoins = New-Object system.Windows.Forms.CheckBox
    $CheckBoxShowOnlyTopCoins.Tag = "ShowOnlyTopCoins"
    $CheckBoxShowOnlyTopCoins.text = "Show Only TopCoins"
    $CheckBoxShowOnlyTopCoins.AutoSize = $false
    $CheckBoxShowOnlyTopCoins.width = 160
    $CheckBoxShowOnlyTopCoins.height = 20
    $CheckBoxShowOnlyTopCoins.location = New-Object System.Drawing.Point(560, 134)
    $CheckBoxShowOnlyTopCoins.Font = 'Microsoft Sans Serif,10'
    $CheckBoxShowOnlyTopCoins.Checked = $Config.ShowOnlyTopCoins
    $ConfigPageControls += $CheckBoxShowOnlyTopCoins

    $CheckBoxParty = New-Object system.Windows.Forms.CheckBox
    $CheckBoxParty.Tag = "PartyWhenAvailable"
    $CheckBoxParty.text = "Party when available"
    $CheckBoxParty.AutoSize = $false
    $CheckBoxParty.width = 160
    $CheckBoxParty.height = 20
    $CheckBoxParty.location = New-Object System.Drawing.Point(560, 156)
    $CheckBoxParty.Font = 'Microsoft Sans Serif,10'
    $CheckBoxParty.Checked = $Config.PartyWhenAvailable
    $ConfigPageControls += $CheckBoxParty

    $CheckBoxPenalizeSoloInPlus = New-Object system.Windows.Forms.CheckBox
    $CheckBoxPenalizeSoloInPlus.Tag = "PenalizeSoloInPlus"
    $CheckBoxPenalizeSoloInPlus.text = "Penalize solo (Plus)"
    $CheckBoxPenalizeSoloInPlus.AutoSize = $false
    $CheckBoxPenalizeSoloInPlus.width = 160
    $CheckBoxPenalizeSoloInPlus.height = 20
    $CheckBoxPenalizeSoloInPlus.location = New-Object System.Drawing.Point(560, 178)
    $CheckBoxPenalizeSoloInPlus.Font = 'Microsoft Sans Serif,10'
    $CheckBoxPenalizeSoloInPlus.Checked = $Config.PenalizeSoloInPlus
    $ConfigPageControls += $CheckBoxPenalizeSoloInPlus

    $CheckBoxPenalizeSoloInPlus.Add_Click( {
                Get-ChildItem -Recurse ".\BrainPlus\" | ? {$_.Name -eq "BrainConfig.json"} | foreach {
                    $BrainPlusConf = Get-Content $_.FullName | ConvertFrom-Json
                    $BrainPlusConf | Add-Member -Force @{SoloBlocksPenalty = $CheckBoxPenalizeSoloInPlus.Checked}
                    $BrainPlusConf | ConvertTo-Json | Out-File $_.FullName
                    rv BrainPlusConf
                }
    })

    $CheckBoxOrphanBlocksPenalty = New-Object system.Windows.Forms.CheckBox
    $CheckBoxOrphanBlocksPenalty.Tag = "OrphanBlocksPenalty"
    $CheckBoxOrphanBlocksPenalty.text = "Penalize Orphan (Plus)"
    $CheckBoxOrphanBlocksPenalty.AutoSize = $false
    $CheckBoxOrphanBlocksPenalty.width = 160
    $CheckBoxOrphanBlocksPenalty.height = 20
    $CheckBoxOrphanBlocksPenalty.location = New-Object System.Drawing.Point(560, 200)
    $CheckBoxOrphanBlocksPenalty.Font = 'Microsoft Sans Serif,10'
    $CheckBoxOrphanBlocksPenalty.Checked = $Config.OrphanBlocksPenalty
    $ConfigPageControls += $CheckBoxOrphanBlocksPenalty

    $CheckBoxOrphanBlocksPenalty.Add_Click( {
                Get-ChildItem -Recurse ".\BrainPlus\" | ? {$_.Name -eq "BrainConfig.json"} | foreach {
                    $BrainPlusConf = Get-Content $_.FullName | ConvertFrom-Json
                    $BrainPlusConf | Add-Member -Force @{OrphanBlocksPenalty = $CheckBoxOrphanBlocksPenalty.Checked}
                    $BrainPlusConf | ConvertTo-Json | Out-File $_.FullName
                    rv BrainPlusConf
                }
    })

    $CheckBoxLowPriorityForCPUMiners = New-Object system.Windows.Forms.CheckBox
    $CheckBoxLowPriorityForCPUMiners.Tag = "UseLowPriorityForCPUMiners"
    $CheckBoxLowPriorityForCPUMiners.text = "Low Pri CPU miners"
    $CheckBoxLowPriorityForCPUMiners.AutoSize = $false
    $CheckBoxLowPriorityForCPUMiners.width = 160
    $CheckBoxLowPriorityForCPUMiners.height = 20
    $CheckBoxLowPriorityForCPUMiners.location = New-Object System.Drawing.Point(560, 222)
    $CheckBoxLowPriorityForCPUMiners.Font = 'Microsoft Sans Serif,10'
    $CheckBoxLowPriorityForCPUMiners.Checked = $Config.UseLowPriorityForCPUMiners
    $ConfigPageControls += $CheckBoxLowPriorityForCPUMiners

    $CheckBoxLowPriorityForCPUMiners.Add_Click( {
                $Config.UseLowPriorityForCPUMiners = $CheckBoxOrphanBlocksPenalty.Checked
    })

    $LabelMaxTTFSec = New-Object system.Windows.Forms.Label
    $LabelMaxTTFSec.text = "Max TTF (Plus)"
    $LabelMaxTTFSec.AutoSize = $false
    $LabelMaxTTFSec.width = 100
    $LabelMaxTTFSec.height = 20
    $LabelMaxTTFSec.location = New-Object System.Drawing.Point(560, 249)
    $LabelMaxTTFSec.Font = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $LabelMaxTTFSec


	$TBMaxTTFSec = New-Object system.Windows.Forms.TextBox
    $TBMaxTTFSec.Tag = "MaxTTFSeconds"
    $TBMaxTTFSec.MultiLine = $False
    $TBMaxTTFSec.text = if ($Config.MaxTTFSeconds) {$Config.MaxTTFSeconds} else {-1}
    $TBMaxTTFSec.AutoSize = $false
    $TBMaxTTFSec.width = 50
    $TBMaxTTFSec.height = 20
    $TBMaxTTFSec.location = New-Object System.Drawing.Point(660, 244)
    $TBMaxTTFSec.Font = 'Microsoft Sans Serif,10'
    $TBMaxTTFSec.Enabled = $True
    $ConfigPageControls += $TBMaxTTFSec

    $CheckBoxConsole = New-Object system.Windows.Forms.CheckBox
    $CheckBoxConsole.Tag = "HideConsole"
    $CheckBoxConsole.text = "Hide Console"
    $CheckBoxConsole.AutoSize = $false
    $CheckBoxConsole.width = 160
    $CheckBoxConsole.height = 20
    $CheckBoxConsole.location = New-Object System.Drawing.Point(560, 90)
    $CheckBoxConsole.Font = 'Microsoft Sans Serif,10'
    $CheckBoxConsole.Checked = $Config.HideConsole
    $ConfigPageControls += $CheckBoxConsole

    $CheckBoxConsole.Add_Click( {
            If ($CheckBoxConsole.Checked) {
                $null = $ShowWindow::ShowWindowAsync($ConsoleHandle, 0)
                Update-Status("Console window hidden")
            }
            else {
                $null = $ShowWindow::ShowWindowAsync($ConsoleHandle, 8)
                Update-Status("Console window shown")
            }
        })
    
    $ButtonMinersCustomConfig                         = New-Object system.Windows.Forms.Button
    $ButtonMinersCustomConfig.text                    = "Miners Custom Config (Advanced)"
    $ButtonMinersCustomConfig.width                   = 250
    $ButtonMinersCustomConfig.height                  = 30
    $ButtonMinersCustomConfig.location                = New-Object System.Drawing.Point(358,300)
    $ButtonMinersCustomConfig.Font                    = 'Microsoft Sans Serif,10'
    # Disabling button as not needed with new algo selection method
    $ButtonMinersCustomConfig.Visible                 = $True
    $ConfigPageControls += $ButtonMinersCustomConfig
    
    $ButtonMinersCustomConfig.Add_Click({
        try {
            & ".\Includes\MinerCustomConfigEditor.ps1"
            } Catch {}
    })
    
    $ButtonWriteConfig                         = New-Object system.Windows.Forms.Button
    $ButtonWriteConfig.text                    = "Save Config"
    $ButtonWriteConfig.width                   = 100
    $ButtonWriteConfig.height                  = 30
    $ButtonWriteConfig.location                = New-Object System.Drawing.Point(610,300)
    $ButtonWriteConfig.Font                    = 'Microsoft Sans Serif,10'
    $ConfigPageControls += $ButtonWriteConfig

    $ButtonWriteConfig.Add_Click({PrepareWriteConfig})

    $LabelPoolsSelect                          = New-Object system.Windows.Forms.Label
    $LabelPoolsSelect.text                     = "Do not select multiple variants of the same pool"
    $LabelPoolsSelect.AutoSize                 = $false
    $LabelPoolsSelect.width                    = 130
    $LabelPoolsSelect.height                   = 50
    $LabelPoolsSelect.location                 = New-Object System.Drawing.Point(427,2)
    $LabelPoolsSelect.Font                     = 'Microsoft Sans Serif,10'
    $LabelPoolsSelect.TextAlign                = 'MiddleCenter'
    $LabelPoolsSelect.BorderStyle              = 'FixedSingle'
    $ConfigPageControls += $LabelPoolsSelect

    $CheckedListBoxPools                       = New-Object System.Windows.Forms.CheckedListBox
    $CheckedListBoxPools.Tag                   = "PoolName"
    $CheckedListBoxPools.height                = 240
    $CheckedListBoxPools.width                 = 130
    $CheckedListBoxPools.text                  = "Pools"
    $CheckedListBoxPools.location              = New-Object System.Drawing.Point(427,54)
    $CheckedListBoxPools.CheckOnClick          = $True
    $CheckedListBoxPools.BackColor                = [System.Drawing.SystemColors]::Control
    $CheckedListBoxPools.Items.Clear()
    $CheckedListBoxPools.Items.AddRange(((Get-ChildItem ".\Pools").BaseName | sort -Unique))
    $CheckedListBoxPools.add_SelectedIndexChanged({CheckedListBoxPools_Click($This)})
    $Config.PoolName | foreach {$CheckedListBoxPools.SetItemChecked($CheckedListBoxPools.Items.IndexOf($_),$True)}
    
    $ConfigPageControls += $CheckedListBoxPools
    
    # $ConfigPageControls | foreach {
        # Try{
            # $DblBuff = ($_.GetType()).GetProperty("DoubleBuffered", ('Instance','NonPublic'))
            # $DblBuff.SetValue($MainForm, $Truen, $null)
        # } catch {}
    # }

# Monitoring Page Controls
    $MonitoringPageControls = @()
    $MonitoringSettingsControls = @()

    $LabelMonitoringWorkers = New-Object system.Windows.Forms.Label
    $LabelMonitoringWorkers.text = "Worker Status"
    $LabelMonitoringWorkers.AutoSize = $false
    $LabelMonitoringWorkers.width = 710
    $LabelMonitoringWorkers.height = 20
    $LabelMonitoringWorkers.location = New-Object System.Drawing.Point(2, 4)
    $LabelMonitoringWorkers.Font = 'Microsoft Sans Serif,10'
    $MonitoringPageControls += $LabelMonitoringWorkers

    $WorkersDGV = New-Object system.Windows.Forms.DataGridView
    $WorkersDGV.width = 710
    $WorkersDGV.height = 244
    $WorkersDGV.location = New-Object System.Drawing.Point(2, 24)
    $WorkersDGV.DataBindings.DefaultDataSourceUpdateMode = 0
    $WorkersDGV.AutoSizeColumnsMode = "AllCells"
    $WorkersDGV.RowHeadersVisible = $False
    $MonitoringPageControls += $WorkersDGV

    $GroupMonitoringSettings = New-Object system.Windows.Forms.GroupBox
    $GroupMonitoringSettings.Height = 60
    $GroupMonitoringSettings.Width = 710
    $GroupMonitoringSettings.Text = "Monitoring Settings"
    $GroupMonitoringSettings.Location = New-Object System.Drawing.Point(1, 272)
    $MonitoringPageControls += $GroupMonitoringSettings

    $LabelMonitoringServer = New-Object system.Windows.Forms.Label
    $LabelMonitoringServer.text = "Server"
    $LabelMonitoringServer.AutoSize = $false
    $LabelMonitoringServer.width = 60
    $LabelMonitoringServer.height = 20
    $LabelMonitoringServer.location = New-Object System.Drawing.Point(2, 15)
    $LabelMonitoringServer.Font = 'Microsoft Sans Serif,10'
    $MonitoringSettingsControls += $LabelMonitoringServer

    $TBMonitoringServer = New-Object system.Windows.Forms.TextBox
    $TBMonitoringServer.Tag = "MonitoringServer"
    $TBMonitoringServer.MultiLine = $False
    $TBMonitoringServer.text = $Config.MonitoringServer
    $TBMonitoringServer.AutoSize = $false
    $TBMonitoringServer.width = 260
    $TBMonitoringServer.height = 20
    $TBMonitoringServer.location = New-Object System.Drawing.Point(62, 15)
    $TBMonitoringServer.Font = 'Microsoft Sans Serif,10'
    $MonitoringSettingsControls += $TBMonitoringServer

    $CheckBoxReportToServer = New-Object system.Windows.Forms.CheckBox
    $CheckBoxReportToServer.Tag = "ReportToServer"
    $CheckBoxReportToServer.text = "Report to server"
    $CheckBoxReportToServer.AutoSize = $false
    $CheckBoxReportToServer.width = 130
    $CheckBoxReportToServer.height = 20
    $CheckBoxReportToServer.location = New-Object System.Drawing.Point(324, 15)
    $CheckBoxReportToServer.Font = 'Microsoft Sans Serif,10'
    $CheckBoxReportToServer.Checked = $Config.ReportToServer
    $MonitoringSettingsControls += $CheckBoxReportToServer

    $CheckBoxShowWorkerStatus = New-Object system.Windows.Forms.CheckBox
    $CheckBoxShowWorkerStatus.Tag = "ShowWorkerStatus"
    $CheckBoxShowWorkerStatus.text = "Show other workers"
    $CheckBoxShowWorkerStatus.AutoSize = $false
    $CheckBoxShowWorkerStatus.width = 145
    $CheckBoxShowWorkerStatus.height = 20
    $CheckBoxShowWorkerStatus.location = New-Object System.Drawing.Point(456, 15)
    $CheckBoxShowWorkerStatus.Font = 'Microsoft Sans Serif,10'
    $CheckBoxShowWorkerStatus.Checked = $Config.ShowWorkerStatus
    $MonitoringSettingsControls += $CheckBoxShowWorkerStatus

    $LabelMonitoringUser = New-Object system.Windows.Forms.Label
    $LabelMonitoringUser.text = "User ID"
    $LabelMonitoringUser.AutoSize = $false
    $LabelMonitoringUser.width = 60
    $LabelMonitoringUser.height = 20
    $LabelMonitoringUser.location = New-Object System.Drawing.Point(2, 37)
    $LabelMonitoringUser.Font = 'Microsoft Sans Serif,10'
    $MonitoringSettingsControls += $LabelMonitoringUser

    $TBMonitoringUser = New-Object system.Windows.Forms.TextBox
    $TBMonitoringUser.Tag = "MonitoringUser"
    $TBMonitoringUser.MultiLine = $False
    $TBMonitoringUser.text = $Config.MonitoringUser
    $TBMonitoringUser.AutoSize = $false
    $TBMonitoringUser.width = 260
    $TBMonitoringUser.height = 20
    $TBMonitoringUser.location = New-Object System.Drawing.Point(62, 37)
    $TBMonitoringUser.Font = 'Microsoft Sans Serif,10'
    $MonitoringSettingsControls += $TBMonitoringUser

    $ButtonGenerateMonitoringUser = New-Object system.Windows.Forms.Button
    $ButtonGenerateMonitoringUser.text = "Generate New User ID"
    $ButtonGenerateMonitoringUser.width = 160
    $ButtonGenerateMonitoringUser.height = 20
    $ButtonGenerateMonitoringUser.location = New-Object System.Drawing.Point(324, 37)
    $ButtonGenerateMonitoringUser.Font = 'Microsoft Sans Serif,10'
    $ButtonGenerateMonitoringUser.Enabled = ($TBMonitoringUser.text -eq "")
    $MonitoringSettingsControls += $ButtonGenerateMonitoringUser

    $ButtonGenerateMonitoringUser.Add_Click( {$TBMonitoringUser.text = [GUID]::NewGuid()})
    # Only enable the generate button when user is blank.
    $TBMonitoringUser.Add_TextChanged( { $ButtonGenerateMonitoringUser.Enabled = ($TBMonitoringUser.text -eq "") })


    $ButtonMonitoringWriteConfig = New-Object system.Windows.Forms.Button
    $ButtonMonitoringWriteConfig.text = "Save Config"
    $ButtonMonitoringWriteConfig.width = 100
    $ButtonMonitoringWriteConfig.height = 30
    $ButtonMonitoringWriteConfig.location = New-Object System.Drawing.Point(600, 15)
    $ButtonMonitoringWriteConfig.Font = 'Microsoft Sans Serif,10'
    $MonitoringSettingsControls += $ButtonMonitoringWriteConfig
    $ButtonMonitoringWriteConfig.Add_Click( {PrepareWriteConfig})

    # ***

$MainForm | Add-Member -Name number -Value 0 -MemberType NoteProperty

$TimerUI = New-Object System.Windows.Forms.Timer
# $TimerUI.Add_Tick({TimerUI_Tick})

$TimerUI.Stop()

$ButtonPause.Add_Click( {
        If (!$Variables.Paused) {
            Update-Status("Stopping miners")
            $Variables.Paused = $True

            # Stop and start mining to immediately switch to paused state without waiting for current NPMCycle to finish
            $Variables.RestartCycle = $True

            $ButtonPause.Text = "Mine"
            Update-Status("Mining paused. BrainPlus and Earning tracker running.")
            $LabelBTCD.Text = "Mining Paused | $($Branding.ProductLable) $($Variables.CurrentVersion)"
            
            If ($Variables.DonationRunning) {
                $Variables.DonationRunning = $False 
                $ConfigLoad = Get-Content $Config.ConfigFile | ConvertFrom-json
                $ConfigLoad | % {$_.psobject.properties | sort Name | % {$Config | Add-Member -Force @{$_.Name = $_.Value}}}
                $Config | Add-Member -Force -MemberType ScriptProperty -Name "PoolsConfig" -Value {
                    If (Test-Path ".\Config\PoolsConfig.json"){
                        get-content ".\Config\PoolsConfig.json" | ConvertFrom-json
                    }else{
                        [PSCustomObject]@{default=[PSCustomObject]@{
                            Wallet = "bc1qh6c9544vpym6p5mrkukx3tek69ze2arqfvhwhl"
                            UserName = "mrplus"
                            WorkerName = "NPlusMinerNoCfg"
                            PoolPenalty = 1
                        }}
                    }
                }
                $Variables.DonateRandom = [PSCustomObject]@{}
            }
            
            # $TimerUI.Stop()
        }
        else {
            $Variables.Paused = $False
            $ButtonPause.Text = "Pause"
            $Variables.LastDonated = (Get-Date).AddHours(-12).AddHours(1)
            $TimerUI.Start()

            # Stop and start mining to immediately switch to unpaused state without waiting for current sleep to finish
            $Variables.RestartCycle = $True
        }
    })


$ButtonStart.Add_Click( {
        If ($Variables.Started) {
            $ButtonPause.Visible = $False
            Update-Status("Stopping cycle")
            $Variables.Started = $False
            Update-Status("Stopping jobs and miner")

            $Variables.EarningsTrackerJobs | % {$_ | Stop-Job -PassThru | Remove-Job}
            $Variables.EarningsTrackerJobs = @()
            $Variables.BrainJobs | % {$_ | Stop-Job -PassThru | Remove-Job}
            $Variables.BrainJobs = @()

            Stop-Mining

            # Stop idle tracking
            if ($IdleRunspace) {$IdleRunspace.Close()}
            if ($idlePowershell) {$idlePowershell.Dispose()}

            $LabelBTCD.Text = "Stopped | $($Branding.ProductLable) $($Variables.CurrentVersion)"
            Update-Status("Idle")
            $ButtonStart.Text = "Start"
            # $TimerUI.Interval = 1000

            If ($Variables.DonationRunning) {
                $Variables.DonationRunning = $False 
                $ConfigLoad = Get-Content $Config.ConfigFile | ConvertFrom-json
                $ConfigLoad | % {$_.psobject.properties | sort Name | % {$Config | Add-Member -Force @{$_.Name = $_.Value}}}
                $Config | Add-Member -Force -MemberType ScriptProperty -Name "PoolsConfig" -Value {
                    If (Test-Path ".\Config\PoolsConfig.json"){
                        get-content ".\Config\PoolsConfig.json" | ConvertFrom-json
                    }else{
                        [PSCustomObject]@{default=[PSCustomObject]@{
                            Wallet = "bc1qh6c9544vpym6p5mrkukx3tek69ze2arqfvhwhl"
                            UserName = "mrplus"
                            WorkerName = "NPlusMinerNoCfg"
                            PoolPenalty = 1
                        }}
                    }
                }
                $Variables.DonateRandom = [PSCustomObject]@{}
            }

            $TimerUI.Stop()
        }
        else {
            if (!(IsLoaded(".\Includes\Core.ps1"))) {. .\Includes\Core.ps1; RegisterLoaded(".\Includes\Core.ps1")}
            if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
            PrepareWriteConfig
            $ButtonStart.Text = "Stop"
            InitApplication
            $Variables.MainPath = (Split-Path $script:MyInvocation.MyCommand.Path)
            $Variables.LastDonated = (Get-Date).AddHours(-12).AddHours(1)

            Start-IdleTracking

            If ($Config.MineWhenIdle) {
                # Disable the pause button - pausing controlled by idle timer
                $Variables.Paused = $True
                $ButtonPause.Visible = $False
            }
            else {
                $ButtonPause.Visible = $True
            }
            $TimerUI.Start()

            Start-Mining
        
            $Variables.Started = $True
        }
    })


$ShowWindow = Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);' -Name Win32ShowWindowAsync -Namespace Win32Functions -PassThru
$ConsoleHandle = (Get-Process -Id $pid).MainWindowHandle

$MainForm.controls.AddRange($MainFormControls)
$RunPage.controls.AddRange(@($RunPageControls))
$SwitchingPage.controls.AddRange(@($SwitchingPageControls))
$EstimationsPage.Controls.AddRange(@($EstimationsDGV))
$ServerModePage.Controls.AddRange($ServermodePageControls)
$ConfigPage.controls.AddRange($ConfigPageControls)
$GroupMonitoringSettings.Controls.AddRange($MonitoringSettingsControls)
$MonitoringPage.controls.AddRange($MonitoringPageControls)

$MainForm.Add_Load({Form_Load})
# $TimerUI.Add_Tick({TimerUI_Tick})

[void]$MainForm.ShowDialog()


