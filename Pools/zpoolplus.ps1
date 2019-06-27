if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

Try {
    $Request = get-content ((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\zpoolplus\zpoolplus.json") | ConvertFrom-Json
}
catch { return }

if (-not $Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = ".mine.zpool.ca"
$PriceField = "Plus_Price"
# $PriceField = "actual_last24h"
# $PriceField = "estimate_current"
$DivisorMultiplier = 1000000
 
$Location = "US"

# Placed here for Perf (Disk reads)
	$ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo = $_
    $PoolHost = "$($_)$($HostSuffix)"
    $PoolPort = $Request.$_.port
    $PoolAlgorithm = Get-Algorithm $Request.$Algo.name
    
    $Divisor = $DivisorMultiplier * [Double]$Request.$Algo.mbtc_mh_factor

	$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Request.$Algo.$PriceField / $Divisor * (1 - ($Request.$Algo.fees / 100)))

	$PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName} else {"ID=$($PoolConf.WorkerName)"}
    
    $PoolPassword = If ( ! $Config.PartyWhenAvailable ) {"$($WorkerName),c=$($PwdCurr)"} else { "$($WorkerName),c=$($PwdCurr),m=party.NPlusMiner" }
    $PoolPassword = If ( $Request.$Algo.MC ) { "$($PoolPassword),zap=$($Request.$Algo.MC)" } else { $PoolPassword }

	$Locations = "eu", "na", "sea", "jp"
	$Locations | ForEach-Object {
		$Pool_Location = $_
		
		switch ($Pool_Location) {
			"eu"    {$Location = "EU"}
			"na"    {$Location = "US"}
			"sea"   {$Location = "JP"}
			"jp"   {$Location = "JP"}
			default {$Location = "US"}
		}
		$PoolHost = "$($Algo).$($Pool_Location)$($HostSuffix)"
        
        if ($PoolConf.Wallet) {
        [PSCustomObject]@{
            Algorithm     = $PoolAlgorithm
            Info          = $Request.$Algo.MC
            Price         = $Stat.Live*$PoolConf.PricePenaltyFactor #*$SoloPenalty
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHost
            Port          = $PoolPort
            User          = $PoolConf.Wallet
		    Pass          = $PoolPassword
            Location      = $Location
            SSL           = $false
            Coin          = $Request.$Algo.MC
        }
        }
    }
}
