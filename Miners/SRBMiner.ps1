If (-not (IsLoaded(".\Includes\include.ps1"))) { . .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1") }

$Path = ".\Bin\cpu-SRBMiner\SRBMiner-MULTI.exe"
$Uri = "https://github.com/doktor83/SRBMiner-Multi/releases/download/0.7.1/SRBMiner-Multi-0-7-1-win64.zip"

$Commands = [PSCustomObject]@{ 
    # "randomx"            = " --randomx-use-1gb-pages" #randomx 
    # "randomxmonero"      = " --randomx-use-1gb-pages" #randomx 
    # "randomarq"          = " --randomx-use-1gb-pages" #randomarq  
    # "randomsfx"          = " --randomx-use-1gb-pages" #randomsfx  
    # "eaglesong"          = "" #eaglesong  
    "yescrypt"           = "" #yescrypt    
    "curvehash"           = "" #yescrypt    
    # "yescryptR16"        = "" #yescryptR16  
    # "yescryptR32"        = "" #yescryptR32   
    "yespower"           = "" #yespower 
    "yespowerSUGAR"           = "" #yespowerSUGAR
    # "yespowerr16"        = "" #yespowerr16 
    # "cryptonight-monero" = " --randomx-use-1gb-pages" #randomx
    "phi5" = "" #phi5
    # "verthash" = "" #verthash
    "rx2" = "" #verthash
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
        
        #Curve diff doesn't play well on ZPool
        If ($Pool.Host -like "*zpool*" -and $AlgoNorm -eq "curvehash") {Return}

        $Arguments = "--algorithm $($AlgoNorm) --pool stratum+tcp://$($Pool.Host):$($Pool.Port) --cpu-threads $($ThreadCount) --nicehash true --send-stales true --api-enable --api-port $($Variables.CPUMinerAPITCPPort) --disable-gpu --wallet $($Pool.User) --password $($Password)"

        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .9915 } # substract 0.85% devfee
            API = "SRB"
            Port = $Variables.CPUMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
            ThreadCount      = $ThreadCount
        }
    }
}

