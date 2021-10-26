if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-trex\t-rex.exe"
# $Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/trex/t-rex-0.20.3-win.zip"
# $Uri = "https://github.com/trexminer/T-Rex/releases/download/0.21.6/t-rex-0.21.6-win.zip"
# $Uri = "https://github.com/trexminer/T-Rex/releases/download/0.22.1/t-rex-0.22.1-win.zip"
$Uri = "https://github.com/trexminer/T-Rex/releases/download/0.24.5/t-rex-0.24.5-win.zip"

$Commands = [PSCustomObject]@{
    # "kawpow"          = "" #kawpow 
    "mtp"           = "" #MTP
    "ethash"        = "" #etchash
    "etchash"       = "" #etchash
    "octopus"       = "" #octopus
    "firopow"       = "" #firopow
}


$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | ForEach-Object {
    $MinerAlgo = switch ($_){
        "Veil"    { "x16rt" }
        default    { $_ }
    }
    
    $fee = switch ($_){
        "octopus"   {0.02}
        default     {0.01}
    }

    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--no-watchdog --no-nvml --api-bind-http 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -a $($MinerAlgo) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password) --quiet -r 10 --cpu-priority 4 -w $($Pool.WorkerName)"
        
        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * (1-$fee)} # substract 1% devfee
            API       = "trex"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
