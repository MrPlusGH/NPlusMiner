<#
This file is part of NPlusMiner
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
File:           BrainPlus.ps1
version:        5.0.0
version date:   20190620
#>


set-location ($args[0])
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

$AlgoObject = @()
$MathObject = @()
$MathObjectFormated = @()
$TestDisplay = @()
$PrevTrend = 0

# Remove progress info from job.childjobs.Progress to avoid memory leak
$ProgressPreference="SilentlyContinue"

# Fix TLS Version erroring
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"


While ($true) {
#Get-Config{
    If (Test-Path ".\BrainConfig.json") {
        $Config = Get-Content ".\BrainConfig.json" | ConvertFrom-Json
    } else {return}
$CurDate = Get-Date
$RetryInterval = 0
try{
    # $AlgoData = Invoke-WebRequest $Config.PoolStatusUri -TimeoutSec 15 -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} | ConvertFrom-Json
    $AlgoData = Invoke-WebRequest $Config.PoolStatusUri -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} | ConvertFrom-Json
    $CoinsData = Invoke-WebRequest $Config.PoolCurrenciesUri -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json 
    $APICallFails = 0
} catch {
    $APICallFails++
    $RetryInterval = $Config.Interval * [math]::max(0,$APICallFails - $Config.AllowedAPIFailureCount)
}

# If ($CoinsData) {
    # $Coins = $Null
    # $CoinsData | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
        # If (! $CoinsData.$_.Symbol) {
            # $CoinsData.$_ | Add-Member -Force @{symbol = $_}
        # }
        # $Coins += @{$_ = $CoinsData.$_}
    # }
# }
$CoinsDataArray = @()

If ( $AlgoData -and $CoinsData ) {
    Foreach ($Coin in ($CoinsData | gm -MemberType NoteProperty).Name) {
            # $BasePrice = If ($CoinsData.($Coin)."24h_btc") {$CoinsData.($Coin)."24h_btc" / 1000} else {$CoinsData.($Coin).estimate -as [Decimal]}
            $BasePrice = If ($AlgoData.($CoinsData.$Coin.Algo).actual_last24h) {[Decimal]$AlgoData.($CoinsData.$Coin.Algo).actual_last24h} else {$CoinsData.($Coin).estimate -as [Decimal]}
            $CoinsData.($Coin).estimate = [math]::max(0, [decimal]($CoinsData.($Coin).estimate * ( 1 - ($Config.PerAPIFailPercentPenalty * [math]::max(0,$APICallFails - $Config.AllowedAPIFailureCount) /100))))
            If (! $CoinsData.$_.Symbol) {
                $CoinsData.($Coin) | Add-Member -Force @{symbol           = $Coin}
            }
            $CoinsData.($Coin) | Add-Member -Force @{ Date                = $CurDate }
            $CoinsData.($Coin) | Add-Member -Force @{ CoinName            = $CoinsData.($Coin).Name }
            $CoinsData.($Coin) | Add-Member -Force @{ Name                = $Coin }
            $CoinsData.($Coin) | Add-Member -Force @{ estimate            = $CoinsData.($Coin).estimate -as [Decimal] }
            $CoinsData.($Coin) | Add-Member -Force @{ actual_last24h      = $BasePrice }
            $CoinsData.($Coin) | Add-Member -Force @{ estimate_current    = $CoinsData.($Coin).estimate }
            $CoinsData.($Coin) | Add-Member -Force @{ Last24Drift         = $CoinsData.($Coin).estimate - $BasePrice }
            $CoinsData.($Coin) | Add-Member -Force @{ Last24DriftSign     = If (($CoinsData.($Coin).estimate - $BasePrice) -ge 0) {"Up"} else {"Down"} }
            $CoinsData.($Coin) | Add-Member -Force @{ Last24DriftPercent  = if ($BasePrice -gt 0) {($CoinsData.($Coin).estimate - $BasePrice) / $BasePrice} else {0} }
            $CoinsData.($Coin) | Add-Member -Force @{ FirstDate           = ($AlgoObject[0]).Date }
            $CoinsData.($Coin) | Add-Member -Force @{ TimeSpan            = If($AlgoObject.Date -ne $null) {(New-TimeSpan -Start ($AlgoObject[0]).Date -End $CurDate).TotalMinutes} }
            $CoinsData.($Coin) | Add-Member -Force @{ AlgoObject          = $AlgoData.($CoinsData.($Coin).Algo) }
            $CoinsData.($Coin) | Add-Member -Force @{ NoAutotrade         = $CoinsData.($Coin).noautotrade }
            $CoinsData.($Coin) | Add-Member -Force @{ SharedHashPercent   = If ($CoinsData.($Coin).hashrate) { ($CoinsData.($Coin).hashrate_shared / $CoinsData.($Coin).hashrate) } else  {1} }
            $CoinsData.($Coin) | Add-Member -Force @{ SoloHashPercent     = If ($CoinsData.($Coin).hashrate) { ($CoinsData.($Coin).hashrate_solo / $CoinsData.($Coin).hashrate) } else {0} }
            
            $CoinsDataArray += $CoinsData.($Coin)
            $AlgoObject += $CoinsData.($Coin)
    }
# "First Loop" | Out-Host
    # Created here for performance optimization, minimize # of lookups
    $FirstAlgoObject = $AlgoObject[0] # | ? {$_.date -eq ($AlgoObject.Date | measure -Minimum).Minimum}
    $CurAlgoObject = $AlgoObject | ? {$_.date -eq $CurDate}
    $TrendSpanSizets = New-TimeSpan -Minutes $Config.TrendSpanSizeMinutes
    $SampleSizets = New-TimeSpan -Minutes $Config.SampleSizeMinutes
    $SampleSizeHalfts = New-TimeSpan -Minutes ($Config.SampleSizeMinutes/2)
    $GroupAvgSampleSize = $AlgoObject | ? {$_.Date -ge ($CurDate - $SampleSizets)} | group Name,Last24DriftSign | select Name,Count,@{Name="Avg";Expression={($_.group.Last24DriftPercent | measure -Average).Average}},@{Name="Median";Expression={Get-Median $_.group.Last24DriftPercent}}
    $GroupMedSampleSize = $AlgoObject | ? {$_.Date -ge ($CurDate - $SampleSizets)} | group Name | select Name,Count,@{Name="Avg";Expression={($_.group.Last24DriftPercent | measure -Average).Average}},@{Name="Median";Expression={Get-Median $_.group.Last24DriftPercent}}
    $GroupAvgSampleSizeHalf = $AlgoObject | ? {$_.Date -ge ($CurDate - $SampleSizeHalfts)} | group Name,Last24DriftSign | select Name,Count,@{Name="Avg";Expression={($_.group.Last24DriftPercent | measure -Average).Average}},@{Name="Median";Expression={Get-Median $_.group.Last24DriftPercent}}
    $GroupMedSampleSizeHalf = $AlgoObject | ? {$_.Date -ge ($CurDate - $SampleSizeHalfts)} | group Name | select Name,Count,@{Name="Avg";Expression={($_.group.Last24DriftPercent | measure -Average).Average}},@{Name="Median";Expression={Get-Median $_.group.Last24DriftPercent}}
    $GroupMedSampleSizeHalfNoPercent = $AlgoObject | ? {$_.Date -ge ($CurDate - $SampleSizeHalfts)} | group Name | select Name,Count,@{Name="Avg";Expression={($_.group.Last24DriftPercent | measure -Average).Average}},@{Name="Median";Expression={Get-Median $_.group.Last24Drift}},@{Name="EstimateMedian";Expression={Get-Median $_.group.estimate_current}},@{Name="EstimateAverage";Expression={($_.group.estimate_current | measure -Average).Average}}
    $GroupMedSampleSizeNoPercent = $AlgoObject | ? {$_.Date -ge ($CurDate - $SampleSizets)} | group Name | select Name,Count,@{Name="Avg";Expression={($_.group.Last24DriftPercent | measure -Average).Average}},@{Name="Median";Expression={Get-Median $_.group.Last24Drift}},@{Name="EstimateMedian";Expression={Get-Median $_.group.estimate_current}},@{Name="EstimateAverage";Expression={($_.group.estimate_current | measure -Average).Average}}
# "Groups created" | Out-Host
# (Measure-Command{

    ForEach ($CoinObject in $CoinsDataArray) {
        $PenaltySampleSize = ((($GroupAvgSampleSize | ? {$_.Name -eq $CoinObject.Name+", Up"}).Count - ($GroupAvgSampleSize | ? {$_.Name -eq $CoinObject.Name+", Down"}).Count) / (($GroupMedSampleSize | ? {$_.Name -eq $CoinObject.Name}).Count)) * [math]::abs(($GroupMedSampleSize | ? {$_.Name -eq $CoinObject.Name}).Median)
        $PenaltySampleSizeHalf = ((($GroupAvgSampleSizeHalf | ? {$_.Name -eq $CoinObject.Name+", Up"}).Count - ($GroupAvgSampleSizeHalf | ? {$_.Name -eq $CoinObject.Name+", Down"}).Count) / (($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).Count)) * [math]::abs(($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).Median)
        $PenaltySampleSizeNoPercent = ((($GroupAvgSampleSize | ? {$_.Name -eq $CoinObject.Name+", Up"}).Count - ($GroupAvgSampleSize | ? {$_.Name -eq $CoinObject.Name+", Down"}).Count) / (($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).Count)) * [math]::abs(($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).Median)
        $Penalty1 = ($PenaltySampleSizeHalf*$Config.Model1SampleHalfPower + $PenaltySampleSizeNoPercent) / ($Config.Model1SampleHalfPower+1)
        $Penalty2 =
            If ($CoinObject.AlgoObject.estimate_last24h) {
                (($CoinObject.AlgoObject.actual_last24h /1000) / $CoinObject.AlgoObject.estimate_last24h)
            } else {
                1
            }
        $Penalty = $Penalty1 * $Penalty2
        $LiveTrend = ((Get-Trendline $CoinObject.estimate_current)[1])
        # $Price = (($Penalty) + ($CurAlgoObject | ? {$_.Name -eq $Name}).actual_last24h) 
        # $Price = [math]::max( 0, [decimal](((($Penalty1) + $CoinObject.actual_last24h) + (($Penalty2) * ($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateMedian))/2) )
        If ($Config.Penalty2onModel1 -and $Penalty2) {
            $Price1 = (($Penalty1 ) + $CoinObject.actual_last24h) * $Penalty2
        } else {
            $Price1 = (($Penalty1) + $CoinObject.actual_last24h)
        }
        
        Switch ($config.Model2RefPrice) {
            "Average" {
                $Price2 = $Penalty2 *(( (($Config.Model2SampleHalfPower * ($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateAverage )) + ( ($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateAverage ))  / ($Config.Model2SampleHalfPower+1) )
            }
            "Median" {
                $Price2 = $Penalty2 *(( (($Config.Model2SampleHalfPower * ($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateMedian )) + ( ($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateMedian ))  / ($Config.Model2SampleHalfPower+1) )
            }
            "Current" {
                $Price2 = $Penalty2 * $CoinObject.estimate_current
            }
            default {
                $Price2 = $Penalty2 * $CoinObject.estimate_current
            }
        }
        # $Price2 = $Penalty2 *(( (($Config.Model2SampleHalfPower * ($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateMedian )) + ( ($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateMedian ))  / ($Config.Model2SampleHalfPower+1) )
        # $Price2 = $Penalty2 *(( (($Config.Model2SampleHalfPower * ($GroupMedSampleSizeHalfNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateAverage )) + ( ($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateAverage ))  / ($Config.Model2SampleHalfPower+1) )
        # $Price2 = $Penalty2 * $CoinObject.estimate_current
        # $Price1 = (($Penalty1) + $Price2)
        # $Price2 = $Penalty2 * $Price1
        $Price = [math]::max( 0, [decimal](($Price1 * $Config.Model1Power + $Price2 * $Config.Model2Power) / ($Config.Model1Power + $Config.Model2Power)) )
        If ( $Config.UseFullTrust ) {
            If ( $Penalty -gt 0 ){
                $Price = [Math]::max([decimal]$Price, [decimal]$CoinObject.estimate_current)
            } else {
                $Price = [Math]::min([decimal]$Price, [decimal]$CoinObject.estimate_current)
            }
        }

        $MathObject += [PSCustomObject]@{
            Name                = $CoinObject.Name
            DriftAvg            = ($CoinObject.Last24DriftPercent | measure -Average).Average
            TimeSpan            = $CoinObject.TimeSpan
            UpDriftAvg          = ($GroupAvgSampleSize | ? {$_.Name -eq $CoinObject.Name+", Up"}).Avg
            DownDriftAvg        = ($GroupAvgSampleSize | ? {$_.Name -eq $CoinObject.Name+", Down"}).Avg
            Penalty             = $Penalty1
            PlusPrice           = $Price
            PlusPrice1          = $Price1
            PlusPrice2          = $Price2
            CurrentLive         = $CoinObject.estimate_current
            Current24hr         = $CoinObject.actual_last24h
            CurrentLiveMed      = ($GroupMedSampleSizeNoPercent | ? {$_.Name -eq $CoinObject.Name}).EstimateMedian
            Date                = $CurDate
            LiveTrend           = $LiveTrend
            APICallFails        = $APICallFails
            EstimationTrust     = $Penalty2
        }
    
        If ($CoinsData.($CoinObject.Name)) { $CoinsData.($CoinObject.Name) | Add-Member -Force @{Plus_Price = $Price} }
        
        
    
    }
# }).TotalSeconds | out-host
    
# "Coins Loop end" | out-host    
# $CoinsDataArray | ? {(!$_.NoAutotrade) -and $_.SoloHashPercent -lt ($Config.MaxSoloPercent/100)} | group Algo | foreach {$_.Group | sort Plus_Price -Descending | select -First 1} | ft * -Auto
            
            $CoinsDataArray = $CoinsDataArray | ? {(!$_.NoAutotrade) -and $_.SoloHashPercent -lt ($Config.MaxSoloPercent/100)} | group Algo | foreach {$_.Group | sort Plus_Price -Descending | select -First 1}
            
            Foreach ($AlgoName in ($AlgoData | gm -MemberType NoteProperty).Name) {
                $TopCoin = $CoinsDataArray | ? { $_.algo -eq $AlgoName }
                If ($TopCoin) {
                    $AlgoData.($AlgoName) | Add-Member -Force @{Plus_Price = $TopCoin.Plus_Price}
                    $AlgoData.($AlgoName)  | Add-Member -Force @{MC = $TopCoin.Symbol}
                } else {
                    $AlgoData.PSObject.Properties.Remove($AlgoName)
                }
            }



if ($Config.EnableLog) {$MathObject | Export-Csv -NoTypeInformation -Append $Config.LogDataPath}
($AlgoData | ConvertTo-Json).replace("NaN",0) | Set-Content $Config.TransferFile

}        

# Limit to only sample size + 10 minutes min history
$AlgoObject = $AlgoObject | ? {$_.Date -ge $CurDate.AddMinutes(-($Config.SampleSizeMinutes+10))}
(($GroupMedSampleSize | ? {$_.Name -eq $CoinObject.Name}).Count)

rv CoinsDataArray
rv GroupAvgSampleSize
rv GroupMedSampleSize
rv GroupAvgSampleSizeHalf
rv GroupMedSampleSizeHalf
rv GroupMedSampleSizeHalfNoPercent
rv GroupMedSampleSizeNoPercent
rv TopCoin


$MathObject = @()
Sleep ($Config.Interval+$RetryInterval-(Get-Date).Second)
}


