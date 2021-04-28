if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-NBMiner\nbminer.exe"
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v37.2/NBMiner_37.2_Win.zip"
$Commands = [PSCustomObject]@{
    # "eaglesong"       = " -a eaglesong" #eaglesong
    # "handshake"       = "-a hns" #handshake
    "kawpow"            = "-a kawpow" #kawpow
    "grincuckatoo32"    = "-a grin32" #Grincuckatoo32
    "beamv3"            = "-a beamv3" #Beamv3
    "octopus"            = "-a octopus" #octopus
    "etchash"            = "-a etchash" #etchash
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

        $Arguments = " --no-watchdog --temperature-limit 95 -d $($Config.SelGPUCC) --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User):$($Password)"
        
        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day * .98} # substract 2% devfee
            API       = "NBMiner"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri    
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
