if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

Try {
    $dtAlgos = New-Object System.Data.DataTable
    if (Test-Path ((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\nlpoolplus\nlpoolplus.xml")) {
        $dtAlgos.ReadXml((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\nlpoolplus\nlpoolplus.xml") | out-null
    }
}
catch { return }

if (-not $dtAlgos) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = "mine.nlpool.nl"
$PriceField = "Plus_Price"
# $PriceField = "actual_last24h"
# $PriceField = "estimate_current"
 
$Location = "US"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$dtAlgos | foreach {
    $Pool = $_
    $PoolHost = $HostSuffix
    $PoolPort = $Pool.port
    $PoolAlgorithm = Get-Algorithm $Pool.algo

      $Divisor = 1000000 * [Double]$Pool.mbtc_mh_factor

    switch ($PoolAlgorithm) {
        # "equihash125" { $Divisor *= 2 } #temp fix
        # "equihash144" { $Divisor *= 2 } #temp fix
        # "equihash192" { $Divisor *= 2 } #temp fix
        "verushash"   { $Divisor *= 2 } #temp fix
    }

    $Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Pool.$PriceField / $Divisor * (1 - ($Pool.fees / 100)))

    $PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName} else {"ID=$($PoolConf.WorkerName)"}

    if ($PoolConf.Wallet) {
        [PSCustomObject]@{
            Algorithm     = $PoolAlgorithm
            Info          = "Auto($($Pool.symbol))"
            Price         = $Stat.Live*$PoolConf.PricePenaltyFactor
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHost
            Port          = $PoolPort
            User          = $PoolConf.Wallet
            Pass          = "$($WorkerName),c=$($PwdCurr)"
            WorkerName    = $WorkerName
            Location      = $Location
            SSL           = $false
            Coin          = "Auto-($($Pool.symbol))"
			Pool_ttf      = $Pool.Pool_ttf
			Real_ttf      = $Pool.Real_ttf
        }
    }
}
