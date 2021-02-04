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
File:           BrainPlus.ps1
version:        5.4.1
version date:   20190809
#>

$Path = $args[0]
set-location ($Path)
# Set Process priority
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

function Get-Trendline  
{ 
param ($data) 
$n = $data.count 
If ($n -le 1) {return 0}
$sumX=0 
$sumX2=0 
$sumXY=0 
$sumY=0 
for ($i=1; $i -le $n; $i++) { 
  $sumX+=$i 
  $sumX2+=([Math]::Pow($i,2)) 
  $sumXY+=($i)*($data[$i-1]) 
  $sumY+=$data[$i-1] 
} 
$b = [math]::Round(($sumXY - $sumX*$sumY/$n)/($sumX2 - $sumX*$sumX/$n), 15)
$a = [math]::Round($sumY / $n - $b * ($sumX / $n),15)
return @($a,$b) 
}

function Get-Median
{
    param(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
    [Double[]]
    $Number
    )
    begin {
        $numberSeries += @()
    }
    process {
        $numberSeries += $number
    }
    end {
       $sortedNumbers = @($numberSeries | Sort-Object)
       if ($numberSeries.Count % 2) {
            $sortedNumbers[($sortedNumbers.Count / 2) - 1]
        } else {
            ($sortedNumbers[($sortedNumbers.Count / 2)] + $sortedNumbers[($sortedNumbers.Count / 2) - 1]) / 2
        }
    }
} 



function Get-DataTable    {
    param(
        [PSCustomObject]$srcObject,
        [System.Data.DataTable]$dt,
        [System.Data.DataRow]$row = $null
    )

    foreach( $property in $srcObject.PSObject.Properties ) {

        if( $property.Value -is [PSCustomObject] ) {
                    $row = (Get-DataTable -srcObject $property.Value -dt $dt -row $row).Row
        }
        else {
            # if( $row -eq $null ) {
                if( $dt.Columns.IndexOf($property.Name) -lt 0 ) {
                    Try {
                        If ($srcObject.($property.Name).GetType() -in @([System.Int16],[System.Int32],[System.Int64])) {
                            [void]$dt.Columns.Add($property.Name, [System.Double] )
                        } elseif ($srcObject.($property.Name).GetType() -in @([DateTime])) {
                            [void]$dt.Columns.Add($property.Name, [DateTime] )
                        } else {
                            [void]$dt.Columns.Add($property.Name, $srcObject.($property.Name).GetType() )
                        }
                    } Catch {
                        [void]$dt.Columns.Add($property.Name, [string]::Empty.GetType() )
                    }
                }
            # }
            # else {
                    $row.Item($property.Name) = $property.value
                    
            # }

        }
    }

    return @{ 'Row' = $row }
}



$AlgoObject = @()
$MathObject = @()
$MathObjectFormated = @()
$TestDisplay = @()
$PrevTrend = 0

# Remove progress info from job.childjobs.Progress to avoid memory leak
$ProgressPreference="SilentlyContinue"

# Fix TLS Version erroring
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"

    $dtBlocks = New-Object System.Data.DataTable
    $dtAlgos = New-Object System.Data.DataTable

if (Test-Path "$($Path)\Blocks.xml"){
    $dtBlocks.ReadXml("$($Path)\Blocks.xml") | out-null
    $dtBlocks.Rows.Count 
}
if (Test-Path "$($Path)\Algos.xml"){
    $dtAlgos.ReadXml("$($Path)\Algos.xml") | out-null
    $dtAlgos.Rows.Count 
}

$pid | out-file ".\pid.txt"
$RoundZero = ($dtAlgos.Rows.Count -lt 1)

. ..\..\Includes\include.ps1
$Config = Load-Config "..\..\Config\Config.json"
    If ($Config.Server_Client) {
        $ServerClientPasswd = ConvertTo-SecureString $Config.Server_ClientPassword -AsPlainText -Force
        $ServerClientCreds = New-Object System.Management.Automation.PSCredential ($Config.Server_ClientUser, $ServerClientPasswd)
        $Variables = [hashtable]::Synchronized(@{})
        $Variables | Add-Member -Force @{ServerClientCreds = $ServerClientCreds}
        $Variables | Add-Member -Force @{ServerRunning = Try{ ((Invoke-WebRequest "http://$($Config.Server_ClientIP):$($Config.Server_ClientPort)/ping" -Credential $Variables.ServerClientCreds -TimeoutSec 3 -UseBasicParsing).content -eq "Server Alive")} Catch {$False} }
    }
While ($true) {

# Set culture.
    # [System.Threading.Thread]::CurrentThread.CurrentUICulture.NumberFormat.NumberDecimalSeparator = "."
    # [System.Threading.Thread]::CurrentThread.CurrentCulture.NumberFormat.NumberDecimalSeparator = "."
    [System.Threading.Thread]::CurrentThread.CurrentUICulture.NumberFormat = [System.Globalization.CultureInfo]::GetCultureInfo('en-US').NumberFormat
    [System.Threading.Thread]::CurrentThread.CurrentCulture.NumberFormat = [System.Globalization.CultureInfo]::GetCultureInfo('en-US').NumberFormat
    [System.Threading.Thread]::CurrentThread.CurrentUICulture.DateTimeFormat = [System.Globalization.CultureInfo]::GetCultureInfo('en-US').DateTimeFormat
    [System.Threading.Thread]::CurrentThread.CurrentCulture.DateTimeFormat = [System.Globalization.CultureInfo]::GetCultureInfo('en-US').DateTimeFormat

#Get-Config{
    If (Test-Path ".\BrainConfig.json") {
        $BrainConfig = Get-Content ".\BrainConfig.json" | ConvertFrom-Json
    } else {return}


$CurDate = Get-Date
$RetryInterval = 0

try{
    $API = .\APIWrapper.ps1
    $AlgoData = $API.Status
    $CoinsData = $API.Currencies
    If ($BrainConfig.SoloBlocksPenaltyMode -eq "Sample" -or $BrainConfig.OrphanBlocksPenalty) {
        # Need to update in case of type change (Orphans)
        $API.Blocks | ? {$_.category -ne "new"} | foreach {
            if (!$_.symbol) {$_ | Add-Member -Force @{symbol = $_.Coin}}
            if (!$_.type) {$_ | Add-Member -Force @{type = "Shared"}}
            Try{
            ($dtBlocks.Select("symbol = '$($_.symbol)' and time = '$($_.time)' and height = '$($_.height)'")).delete()
            }Catch{}
            Try {
                $row = $dtBlocks.NewRow()
                $row = (Get-DataTable -srcObject $_ -dt $dtBlocks -row $row).Row
                [void]$dtBlocks.Rows.Add( $row )
            } Catch {}
        }
        $dtBlocks.PrimaryKey = @($dtBlocks.Columns["symbol"],$dtBlocks.Columns["time"],$dtBlocks.Columns["height"])
        $dtBlocks.TableName = "Blocks"
        ($dtBlocks.Rows | sort date | group symbol | ? {$_.count -gt $BrainConfig.SoloBlocksPenaltyOnLastNBlocks} | foreach {$dtBlocks.Select("symbol = '$($_.Name)'") | sort time | select -first ($_.count - $BrainConfig.SoloBlocksPenaltyOnLastNBlocks)}).delete()
    }
    $APICallFails = 0
} catch {
    $APICallFails++
    $RetryInterval = $BrainConfig.Interval * [math]::max(0,$APICallFails - $BrainConfig.AllowedAPIFailureCount)
}

If (!$RoundZero -and $dtAlgos.Select("date >= '$($CurDate.AddMinutes(-($BrainConfig.MinSampleTSMinutes)))'")) {
    $MinSampleTSMinutesPassed = $True
}

If ( $AlgoData -and $CoinsData ) {
$LoopTime = (Measure-Command {    
    Foreach ($Coin in ($CoinsData | gm -MemberType NoteProperty).Name) {
            # Some pools present some Coins with no correspoding Algo in Status API
            If (!($AlgoData.($CoinsData.$Coin.Algo))) { continue }
            $CoinsData.($Coin).estimate = $CoinsData.($Coin).estimate / $BrainConfig.CoinEstimateDivisor
            # $BasePrice = If ($AlgoData.($CoinsData.$Coin.Algo).actual_last24h) {[Decimal]$AlgoData.($CoinsData.$Coin.Algo).actual_last24h / $BrainConfig.Actual24hrDivisor} else {$CoinsData.($Coin).estimate -as [Decimal]}
            
            #Dealt with ZergPool to get Per Coin Actual24hr and Estimate24hr in Currencies API
            #If not available, fall back to hybrid coin/algo level data
            $BasePrice = If ($CoinsData.($Coin).actual_last24h) {
                [Decimal]$CoinsData.($Coin).actual_last24h / $BrainConfig.Actual24hrDivisor
            } elseif ($CoinsData.($Coin).estimate_last24)  {
                $CoinsData.($Coin).estimate -as [Decimal]
            } else {
                [Decimal]$AlgoData.($CoinsData.$Coin.Algo).actual_last24h / $BrainConfig.Actual24hrDivisor
            }
            $CoinsData.($Coin).estimate = [math]::max(0, [decimal]($CoinsData.($Coin).estimate * ( 1 - ($BrainConfig.PerAPIFailPercentPenalty * [math]::max(0,$APICallFails - $BrainConfig.AllowedAPIFailureCount) /100))))
            If (! $CoinsData.$_.Symbol) {
                $CoinsData.($Coin) | Add-Member -Force @{symbol           = $Coin}
            }
            $CoinsData.($Coin) | Add-Member -Force @{ Date                = $CurDate }
            $CoinsData.($Coin) | Add-Member -Force @{ fees                = [Decimal]$AlgoData.($CoinsData.$Coin.Algo).fees }
            $CoinsData.($Coin) | Add-Member -Force @{ mbtc_mh_factor      = $AlgoData.($CoinsData.$Coin.Algo).mbtc_mh_factor }
            # $CoinsData.($Coin) | Add-Member -Force @{ CoinName            = $CoinsData.($Coin).Name }
            # $CoinsData.($Coin) | Add-Member -Force @{ Name                = $Coin }
            # $CoinsData.($Coin) | Add-Member -Force @{ estimate            = $CoinsData.($Coin).estimate -as [Decimal] }
            $CoinsData.($Coin) | Add-Member -Force @{ actual_last24h      = $BasePrice }
            $CoinsData.($Coin) | Add-Member -Force @{ estimate_current    = $CoinsData.($Coin).estimate }
            # $CoinsData.($Coin) | Add-Member -Force @{ estimate_last24h    = [Decimal]$AlgoData.($CoinsData.$Coin.Algo).estimate_last24h }
            $CoinsData.($Coin) | Add-Member -Force @{ estimate_last24h    = If ($CoinsData.($Coin).estimate_last24) {[Decimal]$CoinsData.($Coin).estimate_last24 } else {[Decimal]$AlgoData.($CoinsData.$Coin.Algo).estimate_last24h}}
            $CoinsData.($Coin) | Add-Member -Force @{ Last24Drift         = $CoinsData.($Coin).estimate - $BasePrice }
            $CoinsData.($Coin) | Add-Member -Force @{ Last24DriftSign     = If ($CoinsData.($Coin).Last24Drift -ge 0) {"Up"} else {"Down"} }
            # $CoinsData.($Coin) | Add-Member -Force @{ Last24DriftPercent  = if ($BasePrice -gt 0) {($CoinsData.($Coin).estimate - $BasePrice) / $BasePrice} else {0} }
            # $CoinsData.($Coin) | Add-Member -Force @{ FirstDate           = ($AlgoObject[0]).Date }
            # $CoinsData.($Coin) | Add-Member -Force @{ TimeSpan            = If($AlgoObject.Date -ne $null) {(New-TimeSpan -Start ($AlgoObject[0]).Date -End $CurDate).TotalMinutes} }
            If(!$RoundZero) {$MinDate = $dtAlgos.Compute("min([date])","")}
            $CoinsData.($Coin) | Add-Member -Force @{ FirstDate           = If(!$RoundZero) {$MinDate} else {$CurDate} }
            $CoinsData.($Coin) | Add-Member -Force @{ TimeSpan            = If(!$RoundZero) {(New-TimeSpan -Start ($MinDate) -End $CurDate).TotalMinutes} }
            # $CoinsData.($Coin) | Add-Member -Force @{ AlgoObject          = $AlgoData.($CoinsData.($Coin).Algo) }
            $CoinsData.($Coin) | Add-Member -Force @{ NoAutotrade         = [Math]::Max(0,$CoinsData.($Coin).noautotrade) }
            # $CoinsData.($Coin) | Add-Member -Force @{ SharedHashPercent   = If ($CoinsData.($Coin).hashrate) { ($CoinsData.($Coin).hashrate_shared / $CoinsData.($Coin).hashrate) } else  {1} }
            $CoinsData.($Coin) | Add-Member -Force @{ SoloHashPercent     = If ($CoinsData.($Coin).hashrate) { ($CoinsData.($Coin).hashrate_solo / $CoinsData.($Coin).hashrate) } else {0} }
            
            # $CoinBlocksType = $Blocks | ? {$_.symbol -eq $Coin -and $_.category -ne "new"} | select @{name="mode";Expression={$_.type -replace "party.*", "party"}} | group symbol,mode -NoElement | select name,@{name="blocks";Expression={$_.count}}
            # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks           = ($CoinBlocksType.Blocks | measure -Sum).Sum }
            # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks_solo      = (($CoinBlocksType | ? {$_.name -ne "shared"}).Blocks | measure -Sum).Sum }
            # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks_shared    = (($CoinBlocksType | ? {$_.name -eq "shared"}).Blocks | measure -Sum).Sum }

                # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks           = $CoinBlocksType.($Coin).Blocks }
                # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks_solo      = $CoinBlocksType.($Coin).Party + $CoinBlocksType.($Coin).Solo }
                # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks_shared    = $CoinBlocksType.($Coin).Shared }
                # $CoinsData.($Coin) | Add-Member -Force @{ TS_blocks_orphan    = $CoinBlocksType.($Coin).Orphan }
            # $TrendSpanSizets = New-TimeSpan -Minutes $BrainConfig.TrendSpanSizeMinutes
            $SampleSizets = New-TimeSpan -Minutes $BrainConfig.SampleSizeMinutes
            # $SampleSizeHalfts = New-TimeSpan -Minutes ($BrainConfig.SampleSizeMinutes/2)
            
            # The date filter in the query below kills perfs (from 11 secs to 55 secs) !
            # have to investigate more effective way to filter.
            # removing for now as we're limitting dataset to the sample anyway
            # $Sample = "symbol = '$($Coin)' and date >= '$($CurDate - $SampleSizets)'"
            $Sample = "symbol = '$($Coin)'"
            # $SampleHalf = "symbol = '$($Coin)' and date >= '$($CurDate - $SampleSizeHalfts)'" 

            If ($dtAlgos.Rows.Count -eq 0) {
                # Add to Table
                Try {
                    $row = $dtAlgos.NewRow()
                    $row = (Get-DataTable -srcObject $CoinsData.($Coin) -dt $dtAlgos -row $row).Row
                    [void]$dtAlgos.Rows.Add( $row )
                } Catch {}
                $dtAlgos.TableName = "Algos"
            }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleUpCount                 = $Sample.Up.count }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleDownCount               = $Sample.Down.count }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleCount                   = $Sample.count }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleMed                     = Get-Median $Sample.Last24Drift }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleAvg                     = ($Sample.Last24DriftPercent  | measure -Average).Average }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateMedian          = If ($dtAlgos.Select($Sample)) {Get-Median ($dtAlgos.Select($Sample).estimate_current) }}
            $EstCurrentArray = If(!$RoundZero) {$dtAlgos.Select($Sample).estimate_current}
           If ($EstCurrentArray -ne $null) {
                $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateMedian          = If(!$RoundZero) {Get-Median ($EstCurrentArray) }}
                $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateAverage         = If(!$RoundZero) {($EstCurrentArray | measure -Average).Average }}
                "No data, adding new: $($coin)"
            } else {
                $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateMedian          = $CoinsData.($Coin).estimate_current }
                $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateAverage         = $CoinsData.($Coin).estimate_current}
            }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateAverage         = If(!$RoundZero) {$dtAlgos.Compute("avg([estimate_current])",$Sample) }}
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleEstimateAverage         = If(!$RoundZero) {($EstCurrentArray | measure -Average).Average }}
            If(!$RoundZero) {rv EstCurrentArray}
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfUpCount             = $SampleHalf.Up.count }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfDownCount           = $SampleHalf.Down.count }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfCount               = $SampleHalf.count }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfMed                 = $SampleHalf.Last24Drift }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfAvg                    = ($SampleHalf.Last24DriftPercent  | measure -Average).Average }
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfEstimateMedian      = If ($dtAlgos.Select($SampleHalf)) {Get-Median ($dtAlgos.Select($SampleHalf).estimate_current) }}
            # $CoinsData.($Coin) | Add-Member -Force @{ SampleHalfEstimateAverage     = $dtAlgos.Compute("avg([estimate_current])",$SampleHalf) }
            
            $Up = $dtAlgos.Select($Sample + " and Last24DriftSign = 'Up'").count
            $Down = $dtAlgos.Select($Sample + " and Last24DriftSign = 'Down'").count
            
            If ($dtAlgos.Select($Sample)) {
            $CoinsData.($Coin) | Add-Member -Force @{ Penalty1 =
                # (($BrainConfig.Model1SampleHalfPower * ((($SampleHalf.Up - $SampleHalf.Down) / [math]::max(1,$SampleHalf.count)) * [math]::abs((Get-Median $SampleHalf.Last24Drift)))) + ((($Sample.Up - $Sample.Down) / [math]::max(1,$Sample.count)) * [math]::abs((Get-Median $Sample.Last24Drift))) / ($BrainConfig.Model1SampleHalfPower+1))
                ((($Up - $Down) / [math]::max(1,$dtAlgos.Select($Sample).Count)) * [math]::abs((Get-Median ($dtAlgos.Select($Sample).Last24Drift))))
            }
            }
            
            $CoinsData.($Coin) | Add-Member -Force @{ Penalty2 = 
                If ([Decimal]$CoinsData.($Coin).estimate_last24h -gt 0) {
                    # (([Decimal]$CoinObject.AlgoObject.actual_last24h) / [Decimal]$CoinObject.AlgoObject.estimate_last24h)
                    (([Decimal]$CoinsData.($Coin).actual_last24h) / [Decimal]$CoinsData.($Coin).estimate_last24h)
                } else {
                    1
                }
            }
            
            $CoinsData.($Coin) | Add-Member -Force @{ Penalty = 
                $Penalty1 * $Penalty2
            }

            $BlockSample = "symbol = '$($Coin)'"
            if ($dtBlocks.Count -gt 1) {
                $All = $dtBlocks.Select($BlockSample).count
                $Orphan = $dtBlocks.Select($BlockSample + " and category = 'orphan'").count
                $Shared = $dtBlocks.Select($BlockSample + " and type = 'shared'").count
                $Solo = $dtBlocks.Select($BlockSample + " and type = 'solo'").count
                $Party = $dtBlocks.Select($BlockSample + " and type like 'party*'").count
            }
            
            $CoinsData.($Coin) | Add-Member -Force @{ SoloBlocksPenalty = 
                Switch ($BrainConfig.SoloBlocksPenaltyMode) {
                    "Sample" {
                        # If ($CoinObject.'TS_blocks' -gt 0 -and $CoinObject.'TS_blocks_solo' -gt 0 -and $CoinObject.'hashrate' -gt 0 -and $CoinObject.'hashrate_solo' -gt 0 ) {
                        #Remove "-and $CoinObject.'hashrate_solo' -gt 0" as it means penalty would be 1 if no solo hashrate
                        
                        If ($All -gt 0 -and $Party + $Solo -gt 0 -and $CoinsData.($Coin).hashrate -gt 0 ) {
                            # $SoloBlocksPenalty = ( [decimal]($CoinObject.'TS_blocks_shared' / $CoinObject.'TS_blocks') + [decimal]($CoinObject.'hashrate_shared' / $CoinObject.'hashrate') ) / 2
                            [math]::min( 1 , [decimal](( [decimal]($Shared /$All) * [decimal](($CoinsData.($Coin).hashrate_shared / $CoinsData.($Coin).hashrate) ) *2 )))
                        } else {
                            1
                        }
                    }
                    "24hr" {
                        # If ($CoinObject.'24h_blocks' -gt 0 -and $CoinObject.'24h_blocks_solo' -gt 0 -and $CoinObject.'hashrate' -gt 0 -and $CoinObject.'hashrate_solo' -gt 0 ) {
                        #Remove "-and $CoinObject.'hashrate_solo' -gt 0" as it means penalty would be 1 if no solo hashrate
                        If ($CoinsData.($Coin).'24h_blocks' -gt 0 -and $CoinsData.($Coin).'24h_blocks_solo' -gt 0 -and $CoinsData.($Coin).'hashrate' -gt 0 ) {
                            # $SoloBlocksPenalty = ( [decimal]($CoinObject.'24h_blocks_shared' / $CoinObject.'24h_blocks') + [decimal]($CoinObject.'hashrate_shared' / $CoinObject.'hashrate') ) / 2
                            [math]::min( 1 , [decimal](( [decimal]($CoinsData.($Coin).'24h_blocks_shared' / $CoinsData.($Coin).'24h_blocks') * [decimal]($CoinsData.($Coin).'hashrate_shared' / $CoinsData.($Coin).'hashrate') ) *2 ))
                        } else {
                            1
                        }
                    }
                    default {
                            1
                    }
                }
            }

            $CoinsData.($Coin) | Add-Member -Force @{ OrphanBlocksPenalty = 
                If ($All -gt 0 -and $Orphan -gt 0) {
                    # $SoloBlocksPenalty = ( [decimal]($CoinObject.'TS_blocks_shared' / $CoinObject.'TS_blocks') + [decimal]($CoinObject.'hashrate_shared' / $CoinObject.'hashrate') ) / 2
                    [math]::min( 1 , [decimal](( [decimal](($All - $Orphan) / $All))))
                } else {
                    1
                }
            }

            $CoinsData.($Coin) | Add-Member -Force @{ Price1 = 
                If ($BrainConfig.Penalty2onModel1 -and $CoinsData.($Coin).Penalty2) {
                    (($CoinsData.($Coin).Penalty1 ) + $CoinsData.($Coin).actual_last24h) * $CoinsData.($Coin).Penalty2
                } else {
                    (($CoinsData.($Coin).Penalty1) + $CoinsData.($Coin).actual_last24h)
                }
            }

            $CoinsData.($Coin) | Add-Member -Force @{ Price2 = 
                Switch ($BrainConfig.Model2RefPrice) {
                    "Average" {
                        $CoinsData.($Coin).Penalty2 *(( (($BrainConfig.Model2SampleHalfPower * $CoinsData.($Coin).SampleHalfEstimateAverage )) + ( $CoinsData.($Coin).SampleEstimateAverage ))  / ($BrainConfig.Model2SampleHalfPower+1) )
                    }
                    "Median" {
                        $CoinsData.($Coin).Penalty2 *(( (($BrainConfig.Model2SampleHalfPower * $CoinsData.($Coin).SampleHalfEstimateMedian )) + ( $CoinsData.($Coin).SampleEstimateMedian ))  / ($BrainConfig.Model2SampleHalfPower+1) )
                    }
                    "Current" {
                        $CoinsData.($Coin).Penalty2 * $CoinsData.($Coin).estimate_current
                    }
                    default {
                        $CoinsData.($Coin).Penalty2 * $CoinsData.($Coin).estimate_current
                    }
                }
            }


            $CoinsData.($Coin) | Add-Member -Force @{ Price = 
                    [math]::max( 0, [decimal](($CoinsData.($Coin).Price1 * $BrainConfig.Model1Power + $CoinsData.($Coin).Price2 * $BrainConfig.Model2Power) / ($BrainConfig.Model1Power + $BrainConfig.Model2Power)) )
            }

            If ($BrainConfig.SoloBlocksPenalty) {
                $CoinsData.($Coin) | Add-Member -Force @{ Price =
                    [math]::max( 0, [decimal]($CoinsData.($Coin).SoloBlocksPenalty * $CoinsData.($Coin).Price))
                }
            }

            If ($BrainConfig.OrphanBlocksPenalty) {
                $CoinsData.($Coin) | Add-Member -Force @{ Price =
                    [math]::max( 0, [decimal]($CoinsData.($Coin).OrphanBlocksPenalty * $CoinsData.($Coin).Price))
                }
            }
            
            $CoinsData.($Coin) | Add-Member -Force @{Plus_Price = $CoinsData.($Coin).Price} 
            
            # Add to Table
            # Try {
                $row = $dtAlgos.NewRow()
                $row = (Get-DataTable -srcObject $CoinsData.($Coin) -dt $dtAlgos -row $row).Row
                [void]$dtAlgos.Rows.Add( $row )
            # } Catch {}
            $dtAlgos.TableName = "Algos"
            
    }
    
            rv Sample
            # rv SampleHalf
            rv CoinsData

    
            Foreach ($AlgoName in ($AlgoData | gm -MemberType NoteProperty).Name) {
                $TopCoin = $dtAlgos.Select("algo = '$($AlgoName)' and NoAutotrade = 0 and SoloHashPercent < '$($BrainConfig.MaxSoloPercent/100)'") | ? { $_.date -eq $CurDate } | Sort Plus_Price -Descending | select -First 1
                If ($TopCoin) {
                    $AlgoData.($AlgoName) | Add-Member -Force @{Plus_Price = $TopCoin.Plus_Price}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{MC = $TopCoin.Symbol}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{SoloBlocksPenalty = $TopCoin.SoloBlocksPenalty}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{OrphanBlocksPenalty = $TopCoin.OrphanBlocksPenalty}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{hashrate = $TopCoin.hashrate}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{hashrate_shared = $TopCoin.hashrate_shared}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{hashrate_solo = $TopCoin.hashrate_solo}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{workers = $TopCoin.workers}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{workers_shared = $TopCoin.workers_shared}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{workers_solo = $TopCoin.workers_solo}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{actual_last24h_COIN = $TopCoin.actual_last24h * $BrainConfig.Actual24hrDivisor}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{estimate_last24_COIN = $TopCoin.estimate_last24h * $BrainConfig.Actual24hrDivisor}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{Date = $CurDate}

                    $AlgoData.($AlgoName)  | Add-Member -Force @{Penalty = $TopCoin.Penalty}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{Penalty1 = $TopCoin.Penalty1}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{Penalty2 = $TopCoin.Penalty2}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{Price1 = $TopCoin.Price1}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{Price2 = $TopCoin.Price2}
                    
                    # $AlgoData.($AlgoName)  | Add-Member -Force @{MedDrift = (Get-Median $Sample.Last24Drift)}



                } else {
                    $AlgoData.PSObject.Properties.Remove($AlgoName)
                }
            }
    Try{
        $dtAlgos.Select("date <= '$($CurDate.AddMinutes(-($BrainConfig.SampleSizeMinutes+2)))'").delete()
    } catch {}


if ($BrainConfig.EnableLog) {$MathObject | Export-Csv -NoTypeInformation -Append $BrainConfig.LogDataPath}
# ($AlgoData | ConvertTo-Json).replace("NaN",0) | Set-Content ".\zergpoolplus.json"

$dvAlgosResult = New-Object System.Data.DataView($dtAlgos)
$dvAlgosResult.Sort = "[date]"
$dvAlgosResult.Filter = "date > '$($CurDate.AddSeconds(-($BrainConfig.Interval*3)))' and date = MAX([date]) and NoAutotrade = 0 and SoloHashPercent < '$($BrainConfig.MaxSoloPercent/100)'"
$dvAlgosResult.ToTable().WriteXml("$($Path)\$($BrainConfig.TransferFile)",[System.Data.XmlWriteMode]::WriteSchema)

}).TotalSeconds

}        

#Give some ouput for debug
"$(($dtAlgos.Rows.date | sort -Unique).count) -- $($dtAlgos.Compute('min([date])','')) -- $($dtAlgos.Compute('max([date])','')) -- $($CurDate) -- $(($dtAlgos.Rows[$dtAlgos.Rows.Count - 1]).TimeSpan) -- $(($dtBlocks.rows | group symbol | sort count | select -Last 1).count) -- $($LoopTime)"


If ((get-date).minute % 5 -eq 0){
    $dtBlocks.WriteXml("$($Path)\Blocks.xml",[System.Data.XmlWriteMode]::WriteSchema)
    $dtAlgos.WriteXml("$($Path)\Algos.xml",[System.Data.XmlWriteMode]::WriteSchema)
}

If ((get-date).minute % 30 -eq 0){

}


rv TopCoin

$RoundZero = $False
$MathObject = @()
Sleep ($BrainConfig.Interval+$RetryInterval-(Get-Date).Second)
}


