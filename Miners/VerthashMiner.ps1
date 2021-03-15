if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-VertHash\VerthashMiner.exe"
$Uri = "https://github.com/CryptoGraphics/VerthashMiner/releases/download/0.7.2/VerthashMiner-0.7.2-CUDA11-windows.zip"

$DatPath = ".\Bin\NVIDIA-VertHash\Verthash.dat"
If (-not (Test-Path $DatPath) -and (Test-Path $Path)) {
    $Variables.StatusText = "Downloading verthash.dat... 1.2Gb !"
    Invoke-WebRequest -OutFile $DatPath -Uri "https://vtc.suprnova.cc/verthash.dat"
}

$Commands = [PSCustomObject]@{
    "verthash"            = " --verthash-data ""$($DatPath)""" #verthash
}
 
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)
    # If ($AlgoNorm -eq "mtp" -and $Pool.Host -like "*nicehash*") {return}
    switch ($_) {
        "mtp" {$Fee = 0.02}
        default {$Fee = 0.00}
    }

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-o stratum+tcp://$($Pool.Host):$($Pool.Port) -a $AlgoNorm -u $($Pool.User) -p $($Password) -D $($Config.SelGPUCC)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            # Arguments = " --api-type ccminer-tcp --no-color --cpu-priority 4 --no-crashreport --no-watchdog -r -1 -R 1 -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$Algo)""--timeout 60 --api-type ccminer-tcp --no-color --cpu-priority 4 --no-crashreport --no-watchdog -r -1 -R 1 -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Pool.Pass)$($Commands.$Algo)"
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * (1 - $Fee)} # substract 1% devfee
            API       = "wrapper"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $true
            URI       = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
