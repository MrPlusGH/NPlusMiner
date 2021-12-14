if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

try {
    $Request = Invoke-ProxiedWebRequest "http://api.zergpool.com:8080/api/status" -UseBasicParsing -Headers @{"Cache-Control" = "no-cache"}
    If ($Request) {$Request = $Request | ConvertFrom-Json }
}
catch { return }

if (-not $Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = ".mine.zergpool.com"
# $PriceField = "actual_last24h"
$PriceField = "estimate_current"
$DivisorMultiplier = 1000000
 
$Location = "US"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $PoolHost = "$($_)$($HostSuffix)"
    $PoolPort = $Request.$_.port
    $PoolAlgorithm = Get-Algorithm $Request.$_.name

    $Divisor = $DivisorMultiplier * [Double]$Request.$_.mbtc_mh_factor

	$Request.$_.fees = $Request.$_.fees - 0.2
    if ((Get-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Request.$_.$PriceField / $Divisor * (1 - ($Request.$_.fees / 100)))}
    else {$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Request.$_.$PriceField / $Divisor * (1 - ($Request.$_.fees / 100)))}

    $PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName} else {"ID=$($PoolConf.WorkerName)"}

    $PoolPassword = "$($WorkerName),c=$($PwdCurr)"
	$PoolPassword += Switch ($PoolConf.Wallet) {
		"bc1qh6c9544vpym6p5mrkukx3tek69ze2arqfvhwhl"	{",refcode=1dbf33605c9d9a9492fab24d2d86ad42"}
		default									{",refcode=e40a19abd56e9b713067f3c996e7ae5e"}
	}
    
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
            User          = $PoolConf.Wallet
            Pass          = $PoolPassword
            WorkerName    = $WorkerName
            Location      = $Location
            SSL           = $false
        }
    }
}
