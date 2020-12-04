if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-NBMiner\nbminer.exe"
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v34.4/NBMiner_34.4_Win.zip"
$Commands = [PSCustomObject]@{
    "ethash+eaglesong"          = "" #Ethash
}

if (!$Pools.Ethash -or !$Pools.eaglesong) {return}
 
$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$WinningCustomConfig = [PSCustomObject]@{}

$Commands.PSObject.Properties.Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.Ethash | foreach {
        $Pool_Ethash = $_
        $Pools.eaglesong | foreach {
            $Pool_eaglesong = $_

            invoke-Expression -command ( $MinerCustomConfigCode )
            If ($AbortCurrentPool) {Return}

            # $Arguments = "--dual_intensity 0 --watchdog 0 --pec 0 --nvml 0 --devices $($Config.SelGPUDSTM) --api $($Variables.NVIDIAMinerAPITCPPort) --algo eth+ckb --server $($Pool_Ethash.Host):$($Pool_Ethash.Port) --user $($Pool_Ethash.User) --dserver $($Pool_eaglesong.Host):$($Pool_eaglesong.Port) --duser $($Pool_eaglesong.User)"
            If (($Pool_Ethash.Host -like "*nicehash*" -or $Pool_Ethash.Host -like "*miningpoolhub*")) {
                $Arguments = " -a eaglesong_ethash --no-watchdog --no-nvml --temperature-limit 95 -di 24 -d $($Config.SelGPUCC) --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool_eaglesong.Host):$($Pool_eaglesong.Port) -u $($Pool_eaglesong.User):$($Pool_eaglesong.Pass) -do nicehash+tcp://$($Pool_Ethash.Host):$($Pool_Ethash.Port) -du $($Pool_Ethash.User):$($Pool_Ethash.Pass)"
            } else {
                $Arguments = " -a eaglesong_ethash --no-watchdog --no-nvml --temperature-limit 95 -di 24 -d $($Config.SelGPUCC) --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool_eaglesong.Host):$($Pool_eaglesong.Port) -u $($Pool_eaglesong.User):$($Pool_eaglesong.Pass) -do stratum+tcp://$($Pool_Ethash.Host):$($Pool_Ethash.Port) -du $($Pool_Ethash.User):$($Pool_Ethash.Pass)"
            }
            
            [PSCustomObject]@{
                Type      = "NVIDIA"
                Path      = $Path
                Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
                HashRates = [PSCustomObject]@{eaglesong =  "$($Stats.NBMinerDualEaglesong_eaglesong_HashRate.Day)";Ethash =  "$($Stats.NBMinerDualEaglesong_Ethash_HashRate.Day * .97)"} # substract 2% devfee
                API       = "NBMinerdualEaglesong"
                Port      = $Variables.NVIDIAMinerAPITCPPort
                Wrap      = $false
                URI       = $Uri    
                User = @($Pool_Ethash.User, $Pool_eaglesong.User)
                Host = @($Pool_Ethash.Host, $Pool_eaglesong.Host)
                Coin = @($Pool_Ethash.Coin, $Pool_eaglesong.Coin)
            }
        }
    }
}
