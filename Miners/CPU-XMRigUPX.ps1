
return

if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\CPU-XMRigUPX\xmrig.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/CPU-XMRigUPX/xmrig-upx-v0.2.0-win64.zip"

$Commands = [PSCustomObject]@{
    # "cryptonightr"        = " -a cryptonight/r --nicehash" #cryptonight/r
    # "cryptonight-monero"  = " -a cryptonight/r" #cryptonight/r
    # "randomxmonero"         = " -a rx/0 --nicehash" #RandomX
    # "randomx"               = " -a rx/0 --nicehash" #RandomX
    # "randomsfx"             = " -a rx/sfx --nicehash" #RandomX
    # "randomarq"             = " -a rx/arq --nicehash" #Randomarq
    # "cryptonightv7"         = " -a cn/1 --nicehash" #cryptonightv7
    # "cryptonight_gpu"       = " -a cn/gpu --nicehash" #cryptonightGPU
    # "cryptonight_xeq"       = " -a cn/gpu --nicehash" #cryptonightGPU
    # "cryptonight_heavy"     = " -a cn-heavy/0 --nicehash" #cryptonight_heavyx
    # "cryptonight_heavyx"    = " -a cn/double --nicehash" #cryptonight_heavyx
    # "cryptonight_saber"     = " -a cn-heavy/0 --nicehash" #cryptonightGPU
    # "cryptonight_fast"      = " -a cn/half --nicehash" #cryptonightFast
    # "cryptonight_haven"      = " -a cn-heavy/xhv --nicehash" #cryptonightFast
    "cryptonight_upx"      = " -a cryptonight-upx/2" #cryptonightFast
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

        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$_) --keepalive --api-port=$($Variables.CPUMinerAPITCPPort) --donate-level 1"

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
