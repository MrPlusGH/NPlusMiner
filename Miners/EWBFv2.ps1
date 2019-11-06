if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-EWBF0.6\\miner.exe"
$Uri = "https://nemosminer.com/data/optional/EWBFEquihashminerv0.6.7z"
$Commands = [PSCustomObject]@{
    # "equihash144"  = " --cuda_devices $($Config.SelGPUDSTM) --algo 144_5 --pers auto" #Equihash144(fastest)
    # "zhash"        = " --cuda_devices $($Config.SelGPUDSTM) --algo 144_5 --pers auto" #Zhash
    # "equihash192"  = " --cuda_devices $($Config.SelGPUDSTM) --algo 192_7 --pers ZERO_PoW" #Equihash192(fastest)
    # "equihash-btg" = " --cuda_devices $($Config.SelGPUDSTM) --algo 144_5 --pers BgoldPoW" # Equihash-btg(fastest)
    # "equihash96"   = " --cuda_devices $($Config.SelGPUDSTM) --algo 96_5 --pers auto" #Equihash96(fastest)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
	$Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--templimit 95 --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) --server $($Pool.Host) --port $($Pool.Port) --eexit 1 --user $($Pool.User) --pass $($Password) --fee 0 --intensity 64"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day}
            API       = "ewbf"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User      = $Pool.User
            Host      = $Pool.Host
            Coin      = $Pool.Coin
        }
    }
}
