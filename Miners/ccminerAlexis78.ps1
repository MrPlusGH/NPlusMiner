if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-Alexis78\ccminer.exe"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/Alexis78-v1.5/ccminerAlexis78v1.5.7z"

$Commands = [PSCustomObject]@{
    "keccak" = " -N 1 -m 2 -i 29 -d $($Config.SelGPUCC)" #Keccak
    "keccakc" = " -N 1 -i 29 -d $($Config.SelGPUCC)" #Keccakc
    "poly" = " -N 1 -d $($Config.SelGPUCC)" #polytimos
    "skein2" = " -i 29 -N 1 -d $($Config.SelGPUCC)" #Skein
    "x11evo" = ",m=solo,d=0.04 -N 1 -i 21 -d $($Config.SelGPUCC) " #X11evo
    #"bitcore" = "" #Bitcore
    #"blake2s" = " -r 0 -d $($Config.SelGPUCC)" #Blake2s
    #"c11" = " -N 1 -i 21 -d $($Config.SelGPUCC)" #C11
    #"cryptonight" = "" #Cryptonight
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = "" #Groestl
    #"hmq1725" = "" #hmq1725
    #"hsr" = " -N 1 -d $($Config.SelGPUCC)" #Hsr(testing)
    #"lbry" = " -d $($Config.SelGPUCC)" #Lbry
    #"lyra2v2" = " -d $($Config.SelGPUCC) -N 1" #Lyra2RE2
    #"lyra2z" = "" #Lyra2z
    #"myr-gr" = " -d $($Config.SelGPUCC) -N 1" #MyriadGroestl
    #"neoscrypt" = " -i 15 -d $($Config.SelGPUCC)" #NeoScrypt
    #"nist5" = " -r 0 -d $($Config.SelGPUCC)" #Nist5
    #"pascal" = "" #Pascal
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sia" = "" #Sia
    #"sib" = " -i 21 -d $($Config.SelGPUCC)" #Sib
    #"skein" = " -i 28 -N 1 -d $($Config.SelGPUCC)" #Skein
    #"timetravel" = "" #Timetravel
    #"vanilla" = "" #BlakeVanilla
    #"veltor" = " -i 23 -d $($Config.SelGPUCC)" #Veltor(fastest)
    #"x11gost" = " -i 21 -d $($Config.SelGPUCC) --api-remote" #X11gost
    #"x13" = " -d $($Config.SelGPUCC) -i 20 -N 1" #X13
    #"x17" = " -N 1 -i 20 -d $($Config.SelGPUCC)" #X17
    #"yescrypt" = "" #Yescrypt
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
	$Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-b $($Variables.NVIDIAMinerAPITCPPort) -R 1 -a $_ -o stratum+tcp://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week}
        API = "ccminer"
        Port = $Variables.NVIDIAMinerAPITCPPort #4068
        Wrap = $false
        URI = $Uri
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
}
