if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\CPU-JayDDee\cpuminer-aes-sse42.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/CpuminerJayddeeSse2/cpuminer-opt-3.10.0-windows.zip"

$Commands = [PSCustomObject]@{
    # "allium" = "" #Allium
    "argon2d-crds" = "" #argon2d-crds
    #"argon2d-dyn" = " -a argon2d500" #argon2d-dyn
    "argon2d4096" = "" #argon2d4096 
    #"bitcore" = "" #Bitcore
    #"blake2s" = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"vanilla" = "" #BlakeVanilla
    #"c11" = "" #C11
    # "cryptonight" = "" #CryptoNight
    #"cryptonightv7" = "" #cryptonightv7
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = "" #Groestl
    # "hmq1725" = "" #HMQ1725
    #"hodl" = "" #Hodl
    #"jha" = "" #JHA
    #"keccak" = "" #Keccak
    #"lbry" = "" #Lbry
    #"lyra2v2" = "" #Lyra2RE2
    "lyra2z330" = "" #lyra2z330
    "lyra2z" = "" #Lyra2z
    # "m7m" = "" #m7m
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"nist5" = "" #Nist5
    #"pascal" = "" #Pascal
    #"sib" = "" #Sib
    #"skein" = "" #Skein
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"veltor" = "" #Veltor
    #"x11evo" = "" #X11evo
    #"x17" = "" #X17
    # "x16r" = "" #X16r
    # "yescrypt" = "" #Yescrypt
    "yescryptr8" = "" #YescryptR8
    "yescryptr16" = "" #YescryptR16
    # "yescryptr32" = "" #YescryptR32
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {

    switch ($_) {
        "hodl" {$ThreadCount = $Variables.ProcessorCount}
        default {$ThreadCount = $Variables.ProcessorCount - 2}
    }

	$Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--cpu-affinity AAAA -q -t $($ThreadCount) -b $($Variables.CPUMinerAPITCPPort) -a $AlgoNorm -o $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week}
            API = "Ccminer"
            Port = $Variables.CPUMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
