if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-NBMiner\nbminer.exe"
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v29.0/NBMiner_29.0_Win.zip"
$Commands = [PSCustomObject]@{
    "ethash+handshake"          = "" #Ethash
}

if (!$Pools.Ethash -or !$Pools.handshake) {return}
 
$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$WinningCustomConfig = [PSCustomObject]@{}

$Commands.PSObject.Properties.Name | ForEach-Object {
	$Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.Ethash | foreach {
        $Pool_Ethash = $_
        $Pools.handshake | foreach {
            $Pool_eaglesong = $_

            invoke-Expression -command ( $MinerCustomConfigCode )
            If ($AbortCurrentPool) {Return}

            # $Arguments = "--dual_intensity 0 --watchdog 0 --pec 0 --nvml 0 --devices $($Config.SelGPUDSTM) --api $($Variables.NVIDIAMinerAPITCPPort) --algo eth+ckb --server $($Pool_Ethash.Host):$($Pool_Ethash.Port) --user $($Pool_Ethash.User) --dserver $($Pool_eaglesong.Host):$($Pool_eaglesong.Port) --duser $($Pool_eaglesong.User)"
            If (($Pool_Ethash.Host -like "*nicehash*" -or $Pool_Ethash.Host -like "*miningpoolhub*")) {
                $Arguments = " -a hns_ethash --no-watchdog --no-nvml --temperature-limit 95 -di 4 -d $($Config.SelGPUCC) --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool_eaglesong.Host):$($Pool_eaglesong.Port) -u $($Pool_eaglesong.User):$($Pool_eaglesong.Pass) -do nicehash+tcp://$($Pool_Ethash.Host):$($Pool_Ethash.Port) -du $($Pool_Ethash.User):$($Pool_Ethash.Pass)"
            } else {
                $Arguments = " -a hns_ethash --no-watchdog --no-nvml --temperature-limit 95 -di 4 -d $($Config.SelGPUCC) --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool_eaglesong.Host):$($Pool_eaglesong.Port) -u $($Pool_eaglesong.User):$($Pool_eaglesong.Pass) -do stratum+tcp://$($Pool_Ethash.Host):$($Pool_Ethash.Port) -du $($Pool_Ethash.User):$($Pool_Ethash.Pass)"
            }
            
            [PSCustomObject]@{
                Type      = "NVIDIA"
                Path      = $Path
                Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
                HashRates = [PSCustomObject]@{handshake =  "$($Stats.NBMinerDualHandshake_handshake_HashRate.Day)";Ethash =  "$($Stats.NBMinerDualHandshake_Ethash_HashRate.Day * .97)"} # substract 2% devfee
                API       = "NBMinerdualHandshake"
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
