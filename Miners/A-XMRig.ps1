if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\AMD-XMRig\xmrig.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/CPU-XMRig/xmrig-6.12.0-msvc-cuda10_2-win64.zip"

$Commands = [PSCustomObject]@{
    # "cryptonightr"        = " -a cryptonight/r --nicehash" #cryptonight/r
    # "cryptonight-monero"  = " -a cryptonight/r" #cryptonight/r
    "randomxmonero"         = " -a rx/0" #RandomX
    "randomx"               = " -a rx/0" #RandomX
    "randomsfx"             = " -a rx/sfx" #RandomX
    "cryptonightv7"         = " -a cn/1" #cryptonightv7
    # "cryptonight_gpu"       = " -a cn/gpu" #cryptonightGPU
    "cryptonight_heavy"     = " -a cn-heavy/0" #cryptonight_heavyx
    "cryptonight_heavyx"    = " -a cn/double" #cryptonight_heavyx
    "cryptonight_saber"     = " -a cn-heavy/0" #cryptonightGPU
    "cryptonight_upx"      = " -a cn/upx2" #cryptonightFast
}
 
$Port = $Variables.AMDMinerAPITCPPort #2222
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | % { 
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        
        If ($_.Coin -eq "TUBE") {$Commands.$Algo = " -a cn-heavy/tube --nicehash"}
        If ($Pool.Host -like "*nicehash*") {$Commands.$Algo += " --nicehash"}

        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = " -a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$_) --keepalive --http-port=$($Variables.AMDMinerAPITCPPort) --donate-level 1 --no-cpu --opencl --opencl-devices=$($Config.SelGPUCC)"

        [PSCustomObject]@{
            Type = "AMD"
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
        }
    }
}
