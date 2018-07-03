if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\NVIDIA-Alexis78Phi\ccminer.exe"
$Uri = "https://github.com/216k155/ccminer-phi-anxmod/releases/download/ccminer%2Fphi-1.0/ccminer-phi-1.0.zip"

$Commands = [PSCustomObject]@{
    #"phi" = " -d $($Config.SelGPUCC) --api-remote" #Phi
    #"bitcore" = " -d $($Config.SelGPUCC)" #Bitcore
    #"jha" = " -d $($Config.SelGPUCC) --api-remote" #Jha
    #"blake2s" = " -d $($Config.SelGPUCC)" #Blake2s
    #"blakecoin" = " -d $($Config.SelGPUCC)" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"cryptonight" = " -i 10 -d $($Config.SelGPUCC)" #Cryptonight
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = " -d $($Config.SelGPUCC) --api-remote" #Groestl
    #"hmq1725" = " -d $($Config.SelGPUCC) --api-remote" #hmq1725
    #"keccak" = "" #Keccak
    #"lbry" = " -d $($Config.SelGPUCC)" #Lbry
    #"lyra2v2" = "" #Lyra2RE2
    #"lyra2z" = " -d $($Config.SelGPUCC)" #Lyra2z
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = " -d $($Config.SelGPUCC)" #NeoScrypt
    #"nist5" = "" #Nist5
    #"pascal" = "" #Pascal
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sia" = "" #Sia
    #"sib" = "" #Sib
    #"skein" = "" #Skein
    #"skunk" = " -d $($Config.SelGPUCC)" #Skunk
    #"timetravel" = " -d $($Config.SelGPUCC) --api-remote" #Timetravel
    #"tribus" = " -d $($Config.SelGPUCC) --api-remote" #Tribus
    #"x11" = "" #X11
    #"veltor" = "" #Veltor
    #"x11evo" = " -d $($Config.SelGPUCC) --api-remote" #X11evo
    #"x17" = " -d $($Config.SelGPUCC)" #X17
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
