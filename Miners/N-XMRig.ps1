if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-XMRig\xmrig.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/CPU-XMRig/xmrig-5.1.0-msvc-cuda10_1-win64.zip"

$Commands = [PSCustomObject]@{
    # "cryptonightr"        = " -a cryptonight/r --nicehash" #cryptonight/r
    # "cryptonight-monero"  = " -a cryptonight/r" #cryptonight/r
    "randomxmonero"         = " -a rx/0 --nicehash" #RandomX
    "cryptonightv7"         = " -a cn/rto --nicehash" #cryptonightv7
}
 
$Port = $Variables.NVIDIAMinerAPITCPPort #2222
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | % { 
    $Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_

        If ($Pool.Host -like "*nicehash*") {
            $Commands."cryptonightv7" = " -a cn/rto --nicehash"
        } else {
            $Commands."cryptonightv7" = " -a cn/1 --nicehash"
        }

        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$_) --keepalive --http-port=$($Variables.NVIDIAMinerAPITCPPort) --donate-level 1 --no-cpu --cuda --cuda-loader=xmrig-cuda.dll --cuda-devices=$($Config.SelGPUCC) --no-nvml"

        [PSCustomObject]@{
            Type = "NVIDIA"
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
