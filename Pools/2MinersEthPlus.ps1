if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

Try {
    $dtAlgos = New-Object System.Data.DataTable
    if (Test-Path ((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\2minersEthPlus\2minersEthPlus.xml")) {
        $dtAlgos.ReadXml((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\2minersEthPlus\2minersEthPlus.xml") | out-null
    }
}
catch { return }

if (-not $dtAlgos) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = ".2miners.com"
# $PriceField = "actual_last24h"
$PriceField = "Plus_Price"
$DivisorMultiplier = 1000000000
 
$Location = "US"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$dtAlgos | foreach {
    $Pool = $_
    $PoolHost = "$($Pool.algo)$($HostSuffix)"
    $PoolPort = $Pool.port
    $PoolAlgorithm = Get-Algorithm $Pool.algo
    
    $Divisor = $DivisorMultiplier * [Double]$Pool.mbtc_mh_factor
    $PoolPrice = If($Pool.$PriceField -ge 0){$Pool.$PriceField} else {0}

    $Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$PoolPrice / $Divisor * (1 - ($Pool.fees / 100)))

    $PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName.Replace("ID=", "")} else {$PoolConf.WorkerName}
    
    # $PoolPassword = If ( ! $Config.PartyWhenAvailable ) {"$($WorkerName),c=$($PwdCurr)"} else { "$($WorkerName),c=$($PwdCurr),m=party.NPlusMiner" }
    # $PoolPassword = If ( $Pool.symbol) { "$($PoolPassword),mc=$($Pool.symbol)" } else { $PoolPassword }
    $PoolPassword = "x"

    $Locations = "eu", "na", "asia"
    # $Locations | ForEach-Object {
        $Pool_Location = $_
        
        switch ($Pool_Location) {
            "eu"    {$Location = "EU"}
            "na"    {$Location = "US"}
            "asia"   {$Location = "JP"}
            default {$Location = "US"}
        }
        $PoolHost = "$($Pool.symbol)$($HostSuffix)"
    
        if ($PoolConf.Wallet) {
            [PSCustomObject]@{
                Algorithm     = $PoolAlgorithm
                Info          = $Pool.symbol
                Price         = $Stat.Live*$PoolConf.PricePenaltyFactor #*$SoloPenalty
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $PoolHost
                Port          = $PoolPort
                User          = "$($PoolConf.Wallet).$($WorkerName)"
                Pass          = $PoolPassword
                WorkerName    = $WorkerName
                Location      = $Location
                SSL           = $false
                Coin          = $Pool.symbol
                SoloBlocksPenalty          = $Pool.SoloBlocksPenalty
                Pool_ttf      = $Pool.Pool_ttf
                Real_ttf      = $Pool.Real_ttf
            }
        }
    # }
}
