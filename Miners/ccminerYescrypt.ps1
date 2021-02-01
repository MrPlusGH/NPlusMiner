if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-Ccmineryescrypt9\ccminer.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/ccminerYescrypt/ccminerKlausTyescryptv9.7z"

$Commands = [PSCustomObject]@{
    "yescrypt" = " -d $($Config.SelGPUCC)" #Yescrypt
    "yescryptR16" = " -i 13.25 -d $($Config.SelGPUCC)" #YescryptR16
    "yescryptR16v2" = " -d $($Config.SelGPUCC)" #YescryptR16v2
    # "yescryptR24" = " -d $($Config.SelGPUCC)" #YescryptR24 
    "yescryptR8" = " -d $($Config.SelGPUCC)" #YescryptR8
    "yescryptR32" = " -i 12.49 -d $($Config.SelGPUCC)" #YescryptR32
}
    switch ($_) {
        "yescryptR32" {$Fee = 0.14} # account for 14% stale shares
              default {$Fee = 0.05} # account for 5% stale shares
    }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--cpu-priority 5 -b $($Variables.NVIDIAMinerAPITCPPort) -N 1 -R 1 --no-cpu-verify -a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type = "NVIDIA"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * (1 - $Fee)}
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
