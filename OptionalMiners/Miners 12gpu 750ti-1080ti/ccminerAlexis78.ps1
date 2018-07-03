if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\NVIDIA-Alexis78\ccminer.exe"
$Uri = "https://github.com/nemosminer/ccminerAlexis78/releases/download/3%2F3%2F2018/ccminer-Alexis78.zip"

$Commands = [PSCustomObject]@{
    #"hsr" = " -d $($Config.SelGPUCC) --api-remote" #Hsr
    #"bitcore" = "" #Bitcore
    #"blake2s" = " -d $($Config.SelGPUCC) --api-remote" #Blake2s
    #"blakecoin" = " -d $($Config.SelGPUCC) --api-remote" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"cryptonight" = "" #Cryptonight
    #"veltor" = " -i 23 -d $($Config.SelGPUCC) --api-remote" #Veltor
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = "" #Groestl
    #"hmq1725" = "" #hmq1725
    #"keccak" = " -m 2 -i 29 -d $($Config.SelGPUCC)" #Keccak
    #"lbry" = " -d $($Config.SelGPUCC) --api-remote" #Lbry
    #"lyra2v2" = " -d $($Config.SelGPUCC) --api-remote" #Lyra2RE2
    #"lyra2z" = "" #Lyra2z
    #"myr-gr" = " -d $($Config.SelGPUCC) --api-remote" #MyriadGroestl
    #"neoscrypt" = " -i 15 -d $($Config.SelGPUCC)" #NeoScrypt
    #"nist5" = " -d $($Config.SelGPUCC) --api-remote" #Nist5
    #"pascal" = "" #Pascal
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sia" = "" #Sia
    #"sib" = " -i 21 -d $($Config.SelGPUCC) --api-remote" #Sib
    #"skein" = " -d $($Config.SelGPUCC) --api-remote" #Skein
    #"timetravel" = "" #Timetravel
    #"c11" = " -i 21 -d $($Config.SelGPUCC) --api-remote" #C11
    #"x11evo" = "" #X11evo
    #"x11gost" = " -i 21 -d $($Config.SelGPUCC) --api-remote" #X11gost
    #"x17" = " -i 20 -d $($Config.SelGPUCC) --api-remote" #X17
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
        Port = $Variables.NVIDIAMinerAPITCPPort #4068
        Wrap = $false
        URI = $Uri
		User = $Pools.(Get-Algorithm($_)).User
    }
}
