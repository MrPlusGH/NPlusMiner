if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-miniZ\miniZ.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/miniZ/miniZ_v1.6v2_cuda10_win-x64.zip"
$Commands = [PSCustomObject]@{
    # "beamv2"       = " --par=beam --pers auto " #Beamv2
    # "beamv3"       = " --par=150,5,3 --pers=Beam-PoW --ocX" #Beamv3 - Only rejects on NH so far. Retest after fork on 06/28
    # "equihashbtg" = " --algo 144,5 --pers BgoldPoW " # Equihash-btg MPH (fastest)
    # "equihashzcl" = " --par=192,7 --pers ZcashPoW" # Equihash-ZCL MPH
    "equihash125"  = " --par=125,4 --ocX " #Equihash125
    "equihash144"  = " --algo 144,5 --pers auto --ocX " #Equihash144 (fastest)
    "equihash192"  = " --algo 192,7 --pers auto --ocX " #Equihash192 (fastest)
    "zhash"        = " --algo 144,5 --pers auto " #Zhash (fastest)
    # "beam"         = " --algo 150,5 --pers auto" #Beam
    # "equihash96"   = " --algo 96,5  --pers auto --oc1 " #Equihash96 (ewbf faster)
}


$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$WinningCustomConfig = [PSCustomObject]@{}
$Commands.PSObject.Properties.Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--templimit 95 --intensity 100 --latency --tempunits C -cd $($Config.SelGPUDSTM) --telemetry $($Variables.NVIDIAMinerAPITCPPort) --url $($Pool.User)@$($Pool.Host):$($Pool.Port) --pass $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .98} # substract 2% devfee
            API       = "miniZ"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri    
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }    
}
