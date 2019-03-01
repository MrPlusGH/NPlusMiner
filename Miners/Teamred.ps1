if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\AMD-Teamred\teamredminer.exe"
$Uri = "https://github.com/Cryptominer937/Miners/raw/master/teamredminer-v0.3.10-win.zip"

$Commands = [PSCustomObject]@{
    "cryptonightv8" = " -a cnv8"
	"lyra2rev3" = " -a lyra2rev3"
	"lyra2z" = " -a lyra2z"
	"phi2" = " -a phi2"
    }
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

	$Algo = Get-Algorithm($_)
        [PSCustomObject]@{
        Type      = "AMD"
        Path      = $Path
        Arguments = "--api_listen=$($Variables.AMDMinerAPITCPPort) -o stratum+tcp://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Day * .97} #-Devfee
        API       = "Xgminer"
        Port      = $Variables.AMDMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }

}


