if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\lolMiner6.0\lolMiner.exe"
$Uri = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/0.6/lolMiner_v06_Win64.zip"

$Commands = [PSCustomObject]@{
    #"equihash96" = " --coin MNX" #Equihash 96,5
	"equihash192" = " --coin AUTO192_7" #Equihash 192,7 Auto Not working on Zerg
    #"equihash144" = " --coin AUTO144_5" #Equihash 144,5
    #"beam" = " --coin BEAM" #Equihash 150,5
    }
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

	$Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type      = "NVIDIA"
        Path      = $Path
        Arguments =  "--user $($Pools.($Algo).User) --pool $($Pools.($Algo).Host) --port $($Pools.($Algo).Port) --devices NVIDIA --apiport 8080 --tls 0 --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 --pass $($Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Day}
        API       = "LOL"
        Port      = $Variables.NVIDIAMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }

    [PSCustomObject]@{
        Type      = "AMD"
        Path      = $Path
        Arguments =  "--user $($Pools.($Algo).User) --pool $($Pools.($Algo).Host) --port $($Pools.($Algo).Port) --devices AMD --apiport 8080 --tls 0 --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 --pass $($Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Day}
        API       = "LOL"
        Port      = $Variables.AMDMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }

}


