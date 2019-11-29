if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-zealotenemy\z-enemy.exe"
$Uri = "https://github.com/z-enemy/z-enemy/releases/download/ver-2.3/z-enemy-2.3-win-cuda10.0.zip"

$Commands = [PSCustomObject]@{
    "aeriumx" = " -i 23" #AeriumX(fastest)
    "hex" = " -i 24" #Hex (fastest)
    "xevan"   = " -i 22" #Xevan (fastest)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-b $($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -R 1 -q -a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day * .99} # substract 1% devfee
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
