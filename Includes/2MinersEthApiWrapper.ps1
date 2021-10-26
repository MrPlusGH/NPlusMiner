# if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

try {
    $Request = Invoke-ProxiedWebRequest "https://eth.2miners.com/api/stats" -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json
    $Pool_Blocks = Invoke-ProxiedWebRequest "https://eth.2miners.com/api/blocks" -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"} | ConvertFrom-Json}
catch { return }

if (-not $Request -or -not $Pool_Blocks) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$DivisorMultiplier = 1000000000

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

Try{
    # $Rates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -TimeoutSec 15 -UseBasicParsing | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
    $Rates = Invoke-ProxiedWebRequest "https://api.coinbase.com/v2/exchange-rates?currency=$($Config.Passwordcurrency)" -TimeoutSec 15 -UseBasicParsing | convertfrom-json | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
    $Config.Currency.Where( {$Rates.$_} ) | ForEach-Object {$Rates | Add-Member $_ ([Double]$Rates.$_) -Force}
    $Variables.Rates = $Rates
} catch {}

$Pool_Divisor = 1000000000

$timestamp    = [int]($Request.now / 1000)
$timestamp1h = $timestamp - 1*3600
$timestamp24h = $timestamp - 24*3600

$blocks24h = @($Pool_Blocks.immature | Where-Object {$_.timestamp -gt $timestamp24h}) + @($Pool_Blocks.matured | Where-Object {$_.timestamp -gt $timestamp24h}) | Select-Object
$blocks24h_measure = $blocks24h | Measure-Object timestamp -Minimum -Maximum
$avgTime24h        = if ($blocks24h_measure.Count -gt 1) {($blocks24h_measure.Maximum - $blocks24h_measure.Minimum) / ($blocks24h_measure.Count - 1)} else {$timestamp}
$reward24h         = $(if ($blocks24h) {($blocks24h | Where-Object reward | Measure-Object reward -Average).Average} else {0})/$Pool_Divisor
$btcPrice       = if ($Variables.Rates.ETH) {1/[double]$Variables.Rates.ETH} else {0}
$btcReward24h   = if ($Request.hashrate -gt 0) {$btcPrice * $reward24h * 24*3600 / $avgTime24h / $Request.hashrate} else {0}

If ($Pool_Blocks.candidates) {$Pool_Blocks.candidates | Foreach {
    # $_.reward = $(if ($blocks24h) {[int]($blocks24h | Where-Object reward | Measure-Object reward -Average).Average} else {0})
    $_.reward = 2000000000000000000
}}

$blocksLive = @($Pool_Blocks.candidates | Where-Object {$_.timestamp -gt $timestamp1h}) + @($Pool_Blocks.immature | Where-Object {$_.timestamp -gt $timestamp1h}) + @($Pool_Blocks.matured | Where-Object {$_.timestamp -gt $timestamp1h}) | sort timestamp -Descending | Select-Object -First 5
$blocksLive_measure = $blocksLive | Measure-Object timestamp -Minimum -Maximum
$avgTimeLive        = if ($blocksLive_measure.Count -gt 1) {($blocksLive_measure.Maximum - $blocksLive_measure.Minimum) / ($blocksLive_measure.Count - 1)} else {$timestamp}
# $avgTimeLive        = if ($blocksLive_measure.Count -gt 1) {($timestamp - $blocksLive_measure.Minimum) / ($blocksLive_measure.Count - 1)} else {($timestamp - $timestamp1h)}
$rewardLive         = $(if ($blocksLive) {($blocksLive | Where-Object reward | Measure-Object reward -Average).Average} else {0})/$Pool_Divisor
$btcPrice       = if ($Variables.Rates.ETH) {1/[double]$Variables.Rates.ETH} else {0}
$btcRewardLive   = if ($Request.hashrate -gt 0) {$btcPrice * $rewardLive * 24*3600 / $avgTimeLive / $Request.hashrate} else {0}

$Hashrate        = $Request.hashrate
$PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}

$fees = 1

# $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $PoolHost = "eth$($HostSuffix)"
    $PoolPort = 2020
    $PoolAlgorithm = "ethash"

    $Divisor = $DivisorMultiplier * 1 #[Double]$Request.$_.mbtc_mh_factor

    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName.Replace("ID=", "")} else {$PoolConf.WorkerName}
    
    if ($PoolConf.Wallet) {
        [PSCustomObject]@{
            Status = [PSCustomObject]@{
                $($PoolAlgorithm) = [PSCustomObject]@{
                    Name     = $PoolAlgorithm
                    Port          = $PoolPort
                    Coins            = 1
                    Fees            = 1
                    Hashrate        = $hashrate
                    Workers         = $Request.minersTotal
                    estimate_current    = $btcRewardLive
                    estimate_last24h    = $btcReward24h
                    actual_last24h      = $btcReward24h
                    mbtc_mh_factor      = 1
                }
            }
            Currencies = [PSCustomObject]@{
                ETH = [PSCustomObject]@{
                    algo                = "ethash"
                    port                = $PoolPort
                    Name                = "Ethereum"
                    Height              = $Request.nodes[0].height
                    difficulty          = $Request.nodes[0].difficulty
                    workers             = $Request.minersTotal
                    hashrate            = $hashrate
                    network_hashrate    = $Request.nodes[0].networkhashps
                    reward              = $reward24h
                    estimate            = $btcRewardLive
                    estimate_current    = $btcRewardLive
                    estimate_last24h    = $btcReward24h
                    actual_last24h      = $btcReward24h
                    mbtc_mh_factor      = 1
                    "24h_blocks"          = $blocks24h.Count
                    "24h_btc"             = $btcReward24h 
                    lastblock           = ""
                    timesincelast       = 0
                    noautotrade         = 0
                    minpay              = 0.005
                    symbol              = "ETH"
                }
            }
        }
        
    }
# }
