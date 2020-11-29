if (!(IsLoaded(".\Includes\include.ps1"))) { . .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1") }

$Path = ".\Bin\CPU-RKZ\cpuminer.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/CPU-rkz/cpuminer-RKZ.zip"

$Commands = [PSCustomObject]@{
    # "yespower" = "" #Yespower
    # "yescrypt" = "" #Yescrypt
    "cpupower" = "" #Cpupower
    "power2b"  = "" #Power2b 
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $ThreadCount = $Variables.ProcessorCount - 2

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-a $AlgoNorm -q -t $($ThreadCount) -b $($Variables.CPUMinerAPITCPPort) -o $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "CPU"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day }
            API       = "ccminer"
            Port      = $Variables.CPUMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User      = $Pool.User
            Host      = $Pool.Host
            Coin      = $Pool.Coin
            ThreadCount      = $ThreadCount
        }
    }
}