if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-miniZ\miniZ.exe"
$Uri = "https://nemosminer.com/data/optional/miniZ_v1.3n5_cuda10_win-x64.7z"
$Commands = [PSCustomObject]@{
    "equihash144"  = " --algo 144,5 --pers auto" #Equihash144 (fastest)
    "zhash"        = " --algo 144,5 --pers auto" #Zhash (fastest)
    "equihash192"  = " --algo 192,7 --pers auto" #Equihash192 (fastest)
    "equihash-btg" = " --algo 144,5 --pers BgoldPoW " # Equihash-btg MPH (fastest)
    "equihash96"   = " --algo 96,5  --pers auto" #Equihash96 (ewbf faster)
    "beam"         = " --algo 150,5 --pers auto" #Beam
}
$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
$Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type      = "NVIDIA"
        Path      = $Path
        Arguments = "--templimit 95 --intensity 100 --latency --nocolor --tempunits C -cd $($Config.SelGPUDSTM) --telemetry $($Variables.NVIDIAMinerAPITCPPort) --url $($Pools.($Algo).User)@$($Pools.($Algo).Host):$($Pools.($Algo).Port) --pass $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week * .98} # substract 2% devfee
        API       = "miniZ"
        Port      = $Variables.NVIDIAMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri    
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
}
