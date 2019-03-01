if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\AMD-Jceminer\jce_cn_gpu_miner64.exe"
$Uri = "https://github.com/jceminer/cn_gpu_miner/raw/master/jce_cn_gpu_miner.033b18.zip"

$Commands = [PSCustomObject]@{
    "cryptonight/1" = " --variation 3"
	#"cryptonightv7" = " --variation 3" #Nicehash Crytonight7
	"cryptonight/2" = " --variation 15"
	#"cryptonightv8" = " --variation 15" #Nicehash Crytonight8
	"cryptonight/xfh" = " --variation 18"
	"cryptonight/mkt" = " --variation 9"
	"cryptonight/fast" = " --variation 11"
	"cryptonight/fast2" = " --variation 21"
	"cryptonight/rto" = " --variation 10"
	"cryptonight/waltz" = " --variation 22"
	"cryptonight/xao" = " --variation 8"
	"cryptonight/xtl" = " --variation 7"
	"cryptonight-lite/0" = " --variation 2"
	"cryptonight-lite/1" = " --variation 4"
	"cryptonight-lite/ipbc" = " --variation 6"
	"cryptonight-lite/dark" = " --variation 17"
	"cryptonight-lite/red" = " --variation 14"
	"cryptonight-lite/turtle" = " --variation 20"
	"cryptonight-lite/upx" = " --variation 19"
	"cryptonight-heavy" = " --variation 5"
	#"cryptonightheavy" = " --variation 5" #Nicehash Cryptonight Heavy
	"cryptonight-heavy/tube" = " --variation 13"
	"cryptonight-heavy/xhv" = " --variation 12"
    }
#N=1 Original Cryptonight
#N=2 Original Cryptolight
#N=3 Cryptonight V7 fork of April-2018
#N=4 Cryptolight V7 fork of April-2018
#N=5 Cryptonight-Heavy
#N=6 Cryptolight-IPBC
#N=7 Cryptonight-XTL
#N=8 Cryptonight-Alloy
#N=9 Cryptonight-MKT/B2N
#N=10 Cryptonight-ArtoCash
#N=11 Cryptonight-Fast (Masari)
#N=12 Cryptonight-Haven
#N=13 Cryptonight-Bittube v2
#N=14 Cryptolight-Red
#N=15 Cryptonight V8 fork of Oct-2018
#N=16 Pool-managed Autoswitch
#N=17 Cryptolight-Dark
#N=18 Cryptonight-Swap
#N=19 Cryptolight-Uplexa
#N=20 Cryptolight-Turtle v2
#N=21 Cryptonight-Stellite v8
#N=22 Waltz/Graft
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

	$Algo = Get-Algorithm($_)
        [PSCustomObject]@{
        Type      = "AMD"
        Path      = $Path
        Arguments = "--no-cpu --auto --doublecheck --mport $($Variables.AMDMinerAPITCPPort) -o stratum+tcp://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) --nicehash --stakjson --any -p $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Day}
        API       = "XMrig"
        Port      = $Variables.AMDMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }

}


