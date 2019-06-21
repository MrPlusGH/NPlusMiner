if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-Gminer\miner.exe"
$Uri = "https://github.com/develsoftware/GMinerRelease/releases/download/1.46/gminer_1_46_windows64.zip"

$Commands = [PSCustomObject]@{
    "equihash144"  = " --devices $($Config.SelGPUDSTM) --algo 144_5 --pers auto" #Equihash144 (fastest)
    "zhash"        = " --devices $($Config.SelGPUDSTM) --algo 144_5 --pers auto" #Zhash (fastest)
    "equihash192"  = " --devices $($Config.SelGPUDSTM) --algo 192_7 --pers auto" #Equihash192 (fastest)
    "equihash-btg" = " --devices $($Config.SelGPUDSTM) --algo 144_5 --pers BgoldPoW" # Equihash-btg (fastest)
    "equihash96"   = " --devices $($Config.SelGPUDSTM) --algo 96_5 --pers auto" #Equihash96 (fastest)
    "beam"         = " --devices $($Config.SelGPUDSTM) --algo 150_5 --pers Beam-PoW" #Equihash150 (fastest)
    "grincuckaroo29"  = " --devices $($Config.SelGPUDSTM) --algo grin29 --pers auto" #Grincuckaroo29 (fastest)
    "cuckoocycle" = " --devices $($Config.SelGPUDSTM) --algo aeternity --pers auto" #Aeternity
    #"cuckatoo31"  = " --devices $($Config.SelGPUDSTM) --algo grin31 --pers auto" #Cuckatoo31 requires 7.4GB VRam, will work on 8GB cards under Linux and Windows 7, will not work under Windows 10
}
$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type      = "NVIDIA"
        Path      = $Path
        Arguments = "-t 95 --watchdog 0 --api $($Variables.NVIDIAMinerAPITCPPort) --server $($Pools.($Algo).Host) --port $($Pools.($Algo).Port) --user $($Pools.($Algo).User) --pass $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Day * .98} # substract 2% devfee
        API       = "gminer"
        Port      = $Variables.NVIDIAMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
}
