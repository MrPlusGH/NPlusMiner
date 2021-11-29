if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

try {
    $Headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}
    $Request = (Invoke-WebRequest "https://www.hashcryptos.com/api/status/" -UseBasicParsing -Headers $Headers).Content
    If ($Request) {$Request = $Request | ConvertFrom-Json }
}
catch { return }

if (-not $Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = "hashcryptos.com"
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

    switch ($Request.$_.name) {
        "blake2s"    {$stratum = "stratum3"}
        "c11"    {$stratum = "stratum4"}
        "equihash"    {$stratum = "stratum4"}
        "groestl"    {$stratum = "stratum3"}
        "kawpow"    {$stratum = "stratum4"}
        "keccak"    {$stratum = "stratum3"}
        "lyra2rev2"    {$stratum = "stratum3"}
        "lyra2rev3"    {$stratum = "stratum3"}
        "myrgro"    {$stratum = "stratum3"}
        "neoscrypt"    {$stratum = "stratum1"}
        "odocrypt"    {$stratum = "stratum2"}
        "phi2"    {$stratum = "stratum4"}
        "quark"    {$stratum = "stratum3"}
        "qubit"    {$stratum = "stratum3"}
        "scrypt"    {$stratum = "stratum2"}
        "skein"    {$stratum = "stratum3"}
        "verthash"    {$stratum = "stratum3"}
        "x11"    {$stratum = "stratum1"}
        "x11gost"    {$stratum = "stratum3"}
        "yescrypt"    {$stratum = "stratum4"}
        default {$stratum = "stratum4"}
    }

    $PoolHost = "$($stratum).$($HostSuffix)"
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
            WorkerName    = $WorkerName
            Location      = $Location
            SSL           = $false
        }
    }
}
