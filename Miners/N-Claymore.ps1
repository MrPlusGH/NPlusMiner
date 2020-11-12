if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-Claymore\EthDcrMiner64.exe"
$Uri = "https://github.com/Claymore-Dual/Claymore-Dual-Miner/releases/download/15.0/Claymore.s.dual.ethereum.v15.0.-.widows.zip"

return
$Commands = [PSCustomObject]@{
    # "ethash" = "" #Ethash -strap 1 -strap 2 -strap 3 -strap 4 -strap 5 -strap 6
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        If ($Algo -eq "ethash" -and $Pool -like "*zergpool*") { return }
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-di $($($Config.SelGPUCC).Replace(',','')) -wd 0 -esm 3 -allpools 1 -allcoins 1 -platform 2 -mode 1 -mport -$($Variables.NVIDIAMinerAPITCPPort) -epool $($Pool.Host):$($Pool.Port) -ewal $($Pool.User) -epsw $($Password)$($Commands.$_)"

        [PSCustomObject]@{
            Type = "NVIDIA"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day}
            API = "ethminer"
            Port = $Variables.NVIDIAMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
