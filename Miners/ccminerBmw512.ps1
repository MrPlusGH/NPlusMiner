if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-Ccminerbmw512\ccminer.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/ccminerBmw512/ccminer.exe"
 
$Commands = [PSCustomObject]@{
    "bmw512" = " -a bmw512 -d $($Config.SelGPUCC)" #Lyra2rev3 
    # "lyra2v3" = " -a lyra2v3 -d $($Config.SelGPUCC)" #Lyra2v3 -i 24 max
    # "lyra2z330" = ",d=0.004 -a lyra2z330 -d $($Config.SelGPUCC) -t 1 --no-cpu-verify" #Lyra2z330
    # "neoscrypt" = " -a neoscrypt -d $($Config.SelGPUCC)" #NeoScrypt
    # "yescrypt" = " -a yescrypt -d $($Config.SelGPUCC)" #Yescrypt
    # "yescryptR16" = " -a yescryptr16 -d $($Config.SelGPUCC)" #YescryptR16
    # "yescryptR16v2" = " -a yescryptr16v2 -d $($Config.SelGPUCC)" #YescryptR16v2
    # "yescryptR24" = " -a yescryptr24 -d $($Config.SelGPUCC)" #YescryptR24 
    # "yescryptR8" = " -a yescryptr8 -d $($Config.SelGPUCC)" #YescryptR8
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    #"blakecoin" = " -d $($Config.SelGPUCC)" #Blakecoin
    #"c11" = " -d $($Config.SelGPUCC)" #C11
    #"cryptonight" = "" #Cryptonight
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = " -r 0 -d $($Config.SelGPUCC)" #Groestl(fastest)
    #"hmq1725" = "" #hmq1725
    #"keccak" = " -d $($Config.SelGPUCC)" #Keccak
    #"lbry" = "" #Lbry
    #"lyra2z" = "" #Lyra2z
    #"myr-gr" = " -d $($Config.SelGPUCC)" #MyriadGroestl
    #"nist5" = " -d $($Config.SelGPUCC)" #Nist5
    #"pascal" = "" #Pascal
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sia" = "" #Sia
    #"sib" = "" #Sib
    #"skein" = " -i 28 -d $($Config.SelGPUCC)" #Skein
    #"timetravel" = "" #Timetravel
    #"vanilla" = "" #BlakeVanilla
    #"veltor" = "" #Veltor
    #"x11" = "" #X11
    #"x11evo" = "" #X11evo
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--cpu-priority 5 -b $($Variables.NVIDIAMinerAPITCPPort) -N 1 -R 1 -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type = "NVIDIA"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day}
            API = "ccminer"
            Port = $Variables.NVIDIAMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
