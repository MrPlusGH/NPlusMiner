if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-ccminerVerus\ccminer.exe"
# $Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/ccminerVerus/ccminer2.14.GPU.19.12.19.zip"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/ccminerVerus/ccminer_GPU_3_8_1.zip"

$Commands = [PSCustomObject]@{
    "verus" = "" #Verushash
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-b $($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -a $($Algo) -i 12.5 -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day}
            API       = "ccminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort #4068
            Wrap      = $false
            URI       = $Uri
            User      = $Pool.User
            Host      = $Pool.Host
            Coin      = $Pool.Coin
        }
    }
}
