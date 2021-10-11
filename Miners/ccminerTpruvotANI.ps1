if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-TpruvotANI\ccminer.exe"
$Uri = "https://github.com/caraphinneth/ccminer/releases/download/2.3.1-clean/ccminer-win64.zip"

$Commands = [PSCustomObject]@{
    "Anime" = "" #scryptn11
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--cpu-priority 5 -b $($Variables.NVIDIAMinerAPITCPPort) -N 1 -R 1 -a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day}
            API       = "ccminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User      = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
