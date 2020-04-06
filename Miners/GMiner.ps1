if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-Gminer\miner.exe"
$Uri = "https://github.com/develsoftware/GMinerRelease/releases/download/2.06/gminer_2_06_windows64.zip"
$Commands = [PSCustomObject]@{
    "cuckoocycle"    = " --algo aeternity --pers auto" #Aeternity 
    "eaglesong"       = " --algo eaglesong" #eaglesong
    # "ethash"          = " --algo ethash" #Ethash
    "equihash96"   = " --algo 96_5 --pers auto" #Equihash96 (fastest)
    "grincuckaroo29"  = " --algo cuckaroo29 --pers auto" #Grincuckaroo29 (fastest)
    "grincuckarood29"  = " --algo grin29 --pers auto" #Grincuckaroo29 (fastest)
    # "beam"         = " --devices $($Config.SelGPUDSTM) --algo 150_5 --pers Beam-PoW" #Equihash150 (fastest)
    # "beamv2"       = " --devices $($Config.SelGPUDSTM) -a beamhashII" #Equihash150 (NiceHash)
    # "equihash-btg" = " --devices $($Config.SelGPUDSTM) --algo 144_5 --pers BgoldPoW" # Equihash-btg (fastest)
    # "equihash125"    = " --devices $($Config.SelGPUDSTM) --algo 125_4 --pers auto" #Equihash125
    # "equihash144"      = " --devices $($Config.SelGPUDSTM) --algo 144_5 --pers auto" #Equihash144 (fastest)
    # "equihash192"  = " --devices $($Config.SelGPUDSTM) --algo 192_7 --pers auto" #Equihash192 (fastest)
    # "grincuckatoo31"  = " --devices $($Config.SelGPUDSTM) --algo grin31 --pers auto" #Cuckatoo31 requires 7.4GB VRam, will work on 8GB cards under Linux and Windows 7, will not work under Windows 10
    # "zhash"        = " --devices $($Config.SelGPUDSTM) --algo 144_5 --pers auto" #Zhash (fastest)
    "cuckaroom"       = " --algo grin29" #Cuckaroom 
    "grincuckatoo32"   = " --algo grin32 --pers auto" #Grincuckatoo32
    "kawpow"           = " --algo kawpow --pers auto" #KAWPOW [RVN fork]
    # "handshake"           = " --algo Handshake --pers auto" #Handshake 
}
 
$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$WinningCustomConfig = [PSCustomObject]@{}

$Commands.PSObject.Properties.Name | ForEach-Object {
	$Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_

        If ($Algo -eq "ethash" -and ($Pool.Host -like "*nicehash*" -or $Pool.Host -like "*miningpoolhub*")) {
            $Commands.$Algo += " --proto stratum"
        } else {

        }

        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = " --devices $($Config.SelGPUDSTM) -t 95 --watchdog 0 --api $($Variables.NVIDIAMinerAPITCPPort) --server $($Pool.Host) --port $($Pool.Port) --user $($Pool.User) --pass $($Password)"
        
        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day * .98} # substract 2% devfee
            API       = "gminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri    
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
