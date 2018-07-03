if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\NVIDIA-TPruvotcuda9\ccminer.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.5-tpruvot/ccminer-x86-2.2.5-cuda9.7z"

$Commands = [PSCustomObject]@{
    "polytimos" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Polytimos
    "hsr" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Hsr
    "phi" = " -N 1 -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Phi
    "bitcore" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Bitcore
    "jha" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Jha
    "blake2s" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Blake2s
    #"blakecoin" = " -d $($Config.SelGPUCC)" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"cryptonight" = " -i 10 -d $($Config.SelGPUCC)" #Cryptonight
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Groestl
    "hmq1725" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #hmq1725
    "keccakc" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Keccakc
    "lbry" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Lbry
    "lyra2v2" = " -N 1 -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Lyra2RE2
    #"lyra2z" = "  -d $($Config.SelGPUCC) --api-remote --api-allow=0/0 --submit-stale" #Lyra2z
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = " -d $($Config.SelGPUCC)" #NeoScrypt
    "nist5" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Nist5
    #"pascal" = "" #Pascal
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
     "sha256t" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Sha256t
   #"sia" = "" #Sia
    "sib" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Sib
    #"skein" = "" #Skein
    #"skunk" = " -d $($Config.SelGPUCC)" #Skunk
    "timetravel" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Timetravel
    #"tribus" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #Tribus
    #"c11" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #C11
    #"veltor" = "" #Veltor
    "x11evo" = " -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #X11evo
    "x17" = " -N 1 -d $($Config.SelGPUCC) --api-remote --api-allow=0/0" #X17
    #"yescrypt" = "" #Yescrypt
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-b $($Variables.NVIDIAMinerAPITCPPort) -a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Hour}
        API = "Ccminer"
        Port = $Variables.NVIDIAMinerAPITCPPort
        Wrap = $false
        URI = $Uri
		User = $Pools.(Get-Algorithm($_)).User
    }
}
