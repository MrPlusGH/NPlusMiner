if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
$Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.25.1/CryptoDredge_0.25.1_cuda_10.2_windows.zip"

$Commands = [PSCustomObject]@{
    "allium"            = " --intensity 8 -a allium" #Allium (fastest)
    "argon2d250"        = " --intensity 8 -a argon2d250" #argon2d250
    "argon2d4096"       = " --intensity 8 -a argon2d4096" #argon2d4096
    "argon2ddyn"        = " --intensity 6 -a argon2d-dyn" #Argon2d-dyn
    "hmq1725"           = " --intensity 8 -a hmq1725" #Hmq1725 (fastest thanks for the fix)
    "lux"               = " --intensity 8 -a phi2" #Lux
    "lyra2v3"           = " --intensity 8 -a lyra2v3" #Lyra2v3 (fastest)
    "lyra2vc0ban"       = " --intensity 8 -a lyra2vc0ban" #Lyra2vc0banHash (fastest)
    "lyra2zz "          = " --intensity 8 -a lyra2zz" #Lyra2zz (Testing)
    # "mtp"               = " --intensity 8 -a mtp" #Mtp (not Asic :)
    "neoscrypt"         = " --intensity 6 -a neoscrypt" #NeoScrypt (fastest)
    "phi2"              = " --intensity 8 -a phi2" #Phi2 (fastest)
    "phi2-lux"              = " --intensity 8 -a phi2" #Phi2 (fastest)
    "pipe"              = " --intensity 8 -a pipe" #Pipe (fastest)
    "skunk"             = " --intensity 8 -a skunk" #Skunk (fastest)
    # "c11"               = " --intensity 8 -a c11" #C11 (trex faster)
    # "dedal"             = " --intensity 8 -a dedal" #Dedal (trex faster second place)
    # "grincuckaroo29"    = " --intensity 8 -a cuckaroo29"
    # "phi"               = " --intensity 8 -a phi" #Phi (fastest)
    # "veil"             = " --intensity 8 -a x16rt" #X16rt (testing)
    # "x16rt"             = " --intensity 8 -a x16rt" #X16rt (testing)
    # "x21s"              = " --intensity 8 -a x21s" #X21s (fastest)
    #"argon2d-uis"    = " --intensity 8 -a argon2d4096" #argon2d4096
    #"bcd"               = " --intensity 8 -a bcd" #Bcd (trex faster)
    #"bitcore"           = " --intensity 8 -a bitcore" #Bitcore (trex faster)
    #"cnv8"              = " --intensity 8 -a cnv8" #CryptoNightv8 (fastest)
    #"cryptonightheavy"  = " --intensity 8 -a cryptonightheavy" # CryptoNightHeavy(fastest)
    #"cryptonightmonero" = " --intensity 8 -a cnv8" # Cryptonightmonero (fastest)
    "cryptonight_gpu" = " --intensity 8 -a cngpu" # CryptonightGPU
    "cryptonight_xeq" = " --intensity 8 -a cngpu" # CryptonightGPU (XEQ Zergpool)
    "cryptonight_saber" = " --intensity 8 -a cnsaber" # CryptonightSaber
    "cryptonight_conceal" = " --intensity 8 -a cnconceal" # Cryptonight_Conceal
    "cryptonight_upx" = " --intensity 8 -a cnupx2" # Cryptonight_Conceal
    "chukwa" = " --intensity 8 -a chukwa" # Cryptonight_Conceal
    #"tribus"            = " --intensity 8 -a tribus" #Tribus (not profitable)
    #"x16r"              = " --intensity 8 -a x16r" #x16r (trex fastest)
    #"x16s"              = " --intensity 8 -a x16s" #X16s (trex faster)
    #"x17"               = " --intensity 8 -a x17" #X17 (trex faster)
    #"x22i"              = " --intensity 8 -a x22i" # X22i (trex faster)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)
    # If ($AlgoNorm -eq "mtp" -and $Pool.Host -like "*nicehash*") {return}
    switch ($_) {
        "mtp" {$Fee = 0.02}
        default {$Fee = 0.01}
    }

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--timeout 60 --api-type ccminer-tcp --no-color --cpu-priority 4 --no-crashreport --no-watchdog -r -1 -R 1 -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            # Arguments = " --api-type ccminer-tcp --no-color --cpu-priority 4 --no-crashreport --no-watchdog -r -1 -R 1 -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$Algo)""--timeout 60 --api-type ccminer-tcp --no-color --cpu-priority 4 --no-crashreport --no-watchdog -r -1 -R 1 -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$Algo)"
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * (1 - $Fee)} # substract 1% devfee
            API       = "ccminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
