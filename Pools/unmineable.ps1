if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

try {
	$Request = [PSCustomObject]@{
		ethash = [PSCustomObject]@{
				name = "ethash"
				port = 3333
				host = "ethash.unmineable.com"
				fees = 0.75
				mbtc_mh_factor = 1
				RequestBody = @{algo="ethash";coin="$($config.Passwordcurrency)";mh=100}
				estimate_current = (Invoke-RestMethod "https://api.unminable.com/v3/calculate/reward" -Body @{algo="ethash";coin="BTC";mh=1} -Method POST).per_day
			}
		etchash = [PSCustomObject]@{
				name = "etchash"
				port = 3333
				host = "etchash.unmineable.com"
				fees = 0.75
				mbtc_mh_factor = 1
				RequestBody = @{algo="ethash";coin="$($config.Passwordcurrency)";mh=100}
				estimate_current = (Invoke-RestMethod "https://api.unminable.com/v3/calculate/reward" -Body @{algo="etchash";coin="BTC";mh=1} -Method POST).per_day
			}
		kawpow = [PSCustomObject]@{
				name = "kawpow"
				port = 3333
				host = "kp.unmineable.com"
				fees = 0.75
				mbtc_mh_factor = 1
				RequestBody = @{algo="ethash";coin="$($config.Passwordcurrency)";mh=100}
				estimate_current = (Invoke-RestMethod "https://api.unminable.com/v3/calculate/reward" -Body @{algo="x16rv2";coin="BTC";mh=1} -Method POST).per_day
			}
		randomx = [PSCustomObject]@{
				name = "randomx"
				port = 3333
				host = "rx.unmineable.com"
				fees = 0.75
				mbtc_mh_factor = 1
				RequestBody = @{algo="ethash";coin="$($config.Passwordcurrency)";mh=100}
				estimate_current = (Invoke-RestMethod "https://api.unminable.com/v3/calculate/reward" -Body @{algo="randomx";coin="BTC";mh=100} -Method POST).per_day
			}
		}
	}
catch { return }
if (-not $Request) {return}

$Referrals = [PSCustomObject]@{
	BTC = "2qfx-36p9"
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
# $PriceField = "actual_last24h"
$PriceField = "estimate_current"
$DivisorMultiplier = 1000000
 
$Location = "EU"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	#Exclude offline statums

    $PoolHost = $Request.$_.host
    $PoolPort = $Request.$_.port
    $PoolAlgorithm = Get-Algorithm $Request.$_.name

    $Divisor = $DivisorMultiplier * [Double]$Request.$_.mbtc_mh_factor

    if ((Get-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Request.$_.$PriceField / $Divisor * (1 - ($Request.$_.fees / 100)))}
    else {$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Request.$_.$PriceField / $Divisor * (1 - ($Request.$_.fees / 100)))}

    $PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName} else {"ID=$($PoolConf.WorkerName)"}
    $WorkerName = $WorkerName.Replace("ID=", "")
    
    if ($PoolConf.Wallet) {
        [PSCustomObject]@{
            Algorithm     = $PoolAlgorithm
            Info          = ""
            Price         = $Stat.Live*$PoolConf.PricePenaltyFactor
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHost
            Port          = $PoolPort
            User          = "$($PwdCurr):$($PoolConf.Wallet).$($WorkerName)#$($Referrals.BTC)"
            Pass          = "$($WorkerName)"
            WorkerName    = $WorkerName
            Location      = $Location
            SSL           = $false
        }
    }
}
