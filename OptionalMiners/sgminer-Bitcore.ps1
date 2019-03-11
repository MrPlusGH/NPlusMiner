if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\AMD-Bitcore\sgminer-x64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.6.1.9-sgminerbitcore/sgminer-bitcore-5.6.1.9.zip"

$Commands = [PSCustomObject]@{
    "timetravel10" = " --kernel timetravel10 -I 19"
    "bitcore" = " --kernel timetravel10 -I 19"
    }
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

	$Algo = Get-Algorithm($_)
        [PSCustomObject]@{
        Type      = "AMD"
        Path      = $Path
        Arguments = "--api-port $($Variables.AMDMinerAPITCPPort) --text-only --api-listen -o stratum+tcp://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Day} #-Devfee
        API       = "Xgminer"
        Port      = $Variables.AMDMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }

}


