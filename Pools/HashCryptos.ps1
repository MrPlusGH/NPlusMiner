if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

try {
    $Headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}
    $Request = ((Invoke-WebRequest "https://www.hashcryptos.com/api/status/" -UseBasicParsing -Headers $Headers).Content | ConvertFrom-Json) 
}
catch { return }

if (-not $Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = "stratum4.hashcryptos.com"
# $PriceField = "actual_last24h"
$PriceField = "estimate_current"
$DivisorMultiplier = 1000000
 
$Location = "EU"

# Placed here for Perf (Disk reads)
    $ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	#Exclude offline statums
	If ([decimal]$Request.$_.estimate_current -le 0.00000001) {Return}

    $PoolHost = "$($HostSuffix)"
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
            User          = "$($PoolConf.Wallet).$($WorkerName)"
            Pass          = "n=$($WorkerName)"
            Location      = $Location
            SSL           = $false
        }
    }
}
