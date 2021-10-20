if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

try {
    $Request = Invoke-ProxiedWebRequest "https://eth.2miners.com/api/stats" -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json
    $Pool_Blocks = Invoke-ProxiedWebRequest "https://eth.2miners.com/api/blocks" -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json}
catch { return }

if (-not $Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = ".2miners.com"
# $PriceField = "actual_last24h"
$PriceField = "estimate_current"
$DivisorMultiplier = 1000000000
 
$Location = "US"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$timestamp    = [int]($Pool_Request.now / 1000)
$timestamp24h = $timestamp - 24*3600

$blocks = @($Pool_Blocks.candidates | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.immature | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) + @($Pool_Blocks.matured | Where-Object {$_.timestamp -gt $timestamp24h} | Select-Object timestamp,reward,difficulty) | Select-Object

$Pool_Divisor = 1000000000

$PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}

$blocks_measure = $blocks | Measure-Object timestamp -Minimum -Maximum
$avgTime        = if ($blocks_measure.Count -gt 1) {($blocks_measure.Maximum - $blocks_measure.Minimum) / ($blocks_measure.Count - 1)} else {$timestamp}
$reward         = $(if ($blocks) {($blocks | Where-Object reward | Measure-Object reward -Average).Average} else {0})/$Pool_Divisor
$btcPrice       = if ($Variables.Rates.ETH) {1/[double]$Variables.Rates.ETH} else {0}
$btcRewardLive   = if ($Request.hashrate -gt 0) {$btcPrice * $reward * 86400 / $avgTime / $Request.hashrate} else {0}
$Hashrate        = $Request.hashrate

$fees = 1

# $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $PoolHost = "eth$($HostSuffix)"
    $PoolPort = 2020
    $PoolAlgorithm = Get-Algorithm "ETH"

    $Divisor = $DivisorMultiplier * 1 #[Double]$Request.$_.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$btcRewardLive / $Divisor * (1 - ($fees / 100)))}
    else {$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$btcRewardLive / $Divisor * (1 - ($fees / 100)))}

    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName.Replace("ID=", "")} else {$PoolConf.WorkerName}
    
    if ($PoolConf.Wallet) {
        @([PSCustomObject]@{
            Algorithm     = $PoolAlgorithm
            Info          = "ETH"
            Price         = $Stat.Live*$PoolConf.PricePenaltyFactor
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHost
            Port          = $PoolPort
            User          = "$($PoolConf.Wallet).$($WorkerName)"
            Pass          = "$($WorkerName),c=$($PwdCurr)"
            Location      = $Location
            SSL           = $false
        })
    }
# }
