If (-not (IsLoaded(".\Includes\include.ps1"))) { . .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1") }

$Path = ".\Bin\AMD-SRBMiner\SRBMiner-MULTI.exe"
# $Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.7.1/SRBMiner-Multi-0-7-1-win64.zip"
# $Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.7.3/SRBMiner-Multi-0-7-3-win64.zip"
# $Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.7.9/SRBMiner-Multi-0-7-9-win64.zip"
$Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.8.5/SRBMiner-Multi-0-8-5-win64.zip"

$Commands = [PSCustomObject]@{ 
    "phi5" = "" #phi5
    "heavyhash" = "" #heavyhash
    "ethash" = "" #ethash
    "etchash" = "" #etchash
    "firopow" = "" #firopow
    "kawpow" = "" #kawpow
    "cryptonight_gpu" = "" #cryptonight_gpu
    "ubqhash" = "" #ubqhash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
    switch ($_) { 
        default { $ThreadCount = $Variables.ProcessorCount - 2 }
    }

    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}
        
        #Zpool fixed it on 20211205
        #Curve diff doesn't play well on ZPool
        # If ($Pool.Host -like "*zpool*" -and $AlgoNorm -eq "curvehash") {Return}

        $Arguments = "--algorithm $($AlgoNorm) --pool stratum+tcp://$($Pool.Host):$($Pool.Port) --cpu-threads $($ThreadCount) --nicehash true --send-stales true --api-enable --api-port $($Variables.AMDMinerAPITCPPort) --disable-cpu --wallet $($Pool.User) --password $($Password)"

        [PSCustomObject]@{
            Type = "AMD"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .9915 } # substract 0.85% devfee
            API = "SRB"
            Port = $Variables.AMDMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
            ThreadCount      = $ThreadCount
        }
    }
}

