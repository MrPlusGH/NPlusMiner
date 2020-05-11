if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

Try {
    $dtAlgos = New-Object System.Data.DataTable
    if (Test-Path ((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\prohashingPlus\prohashingPlus.xml")) {
        $dtAlgos.ReadXml((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\prohashingPlus\prohashingPlus.xml") | out-null
    }
}
catch { return }

if (-not $dtAlgos) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = "prohashing.com"
$PriceField = "Plus_Price"
# $PriceField = "actual_last24h"
# $PriceField = "estimate_current"
$DivisorMultiplier = 1

# + 2.9% supplementary fee for conversion
# Makes 2 + 2.9 = 4.9%
# There is 0.00015 BTC fee on withdraw as well (Estimation 0.00015/0.0025 = 6%) Using 0.0025 as most pools do use this Payout threshold
# Makes 2 + 2.9 + 6 = 10.9% !!!
# $Request.$_.fees = $Request.$_.fees + 2.9 + 6
# Taking 1.5 here considerinf withdraw at 0.01BTC
 
$Location = "US"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$dtAlgos | foreach {
    $PoolHost = "$($HostSuffix)"
    $PoolPort = $_.port
    $PoolAlgorithm = Get-Algorithm $_.algo
    
    $Divisor = $DivisorMultiplier * [Double]$_.mbtc_mh_factor

    $Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$_.$PriceField / $Divisor * (1 - (($_.fees))))

    $PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName} else {"ID=$($PoolConf.WorkerName)"}
    
    $PoolPassword = If ( ! $Config.PartyWhenAvailable ) {"$($WorkerName),c=$($PwdCurr)"} else { "$($WorkerName),c=$($PwdCurr),m=party.NPlusMiner" }
    $PoolPassword = If ( $_.symbol) { "$($PoolPassword),mc=$($_.symbol)" } else { $PoolPassword }
    
    if ($PoolConf.Wallet) {
        [PSCustomObject]@{
            Algorithm     = $PoolAlgorithm
            Info          = $_.symbol
            Price         = $Stat.Live*$PoolConf.PricePenaltyFactor #*$SoloPenalty
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHost
            Port          = $PoolPort
            User          = "$($PoolConf.UserName)"
            Pass          = "a=$($PoolAlgorithm),n=$($PoolConf.WorkerName.replace('ID=',''))"
            Location      = $Location
            SSL           = $false
            Coin          = "Auto ($($_.symbol))"
            SoloBlocksPenalty          = $_.SoloBlocksPenalty
        }
    }
}
