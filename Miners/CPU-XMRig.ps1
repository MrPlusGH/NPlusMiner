if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\CPU-XMRig\xmrig.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/CPU-XMRig/xmrig-6.12.0-msvc-cuda10_2-win64.zip"

$Commands = [PSCustomObject]@{
    # "cryptonightr"        = " -a cryptonight/r --nicehash" #cryptonight/r
    # "cryptonight-monero"    = " -a rx/0" #RandomX
    # "randomxmonero"         = " -a rx/0" #RandomX
    "randomx"               = " -a rx/0" #RandomX
    "randomsfx"             = " -a rx/sfx" #randomsfx
    "randomarq"             = " -a rx/arq" #Randomarq
    "cryptonightv7"         = " -a cn/1" #cryptonightv7
    # "cryptonight_gpu"       = " -a cn/gpu" #cryptonightGPU
    "cryptonight_xeq"       = " -a cn/gpu" #cryptonight_xeq
    "cryptonight_heavy"     = " -a cn-heavy/0" #cryptonight_heavy
    "cryptonight_heavyx"    = " -a cn/double" #cryptonight_heavyx
    "cryptonight_saber"     = " -a cn-heavy/0" #cryptonight_saber
    "cryptonight_fast"      = " -a cn/half" #cryptonightFast
    "cryptonight_haven"     = " -a cn-heavy/xhv" #cryptonight_haven
    "randomWOW"             = " -a rx/wow" #randomWOW
    "cryptonight_upx"      = " -a cn/upx2" #cryptonightFast
}
 
# $ThreadCount = $ThreadCount = $Variables.ProcessorCount - 2

$Port = $Variables.CPUMinerAPITCPPort #2222
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | % { 
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_

        If ($_.Coin -eq "TUBE") {$Commands.$Algo = " -a cn-heavy/tube"}
        If ($Pool.Host -like "*nicehash*") {$Commands.$Algo += " --nicehash"}

        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$_) --keepalive --http-port=$($Variables.CPUMinerAPITCPPort) --donate-level 1"

        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .99} # substract 1% devfee
            API = "XMRig"
            Port = $Port
            Wrap = $false
            URI = $Uri    
            User      = $Pool.User
            Host      = $Pool.Host
            Coin      = $Pool.Coin
            # ThreadCount      = $ThreadCount
        }
    }
}
