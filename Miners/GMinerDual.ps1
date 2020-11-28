Return

if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-GminerDual\miner.exe"
$Uri = "https://github.com/develsoftware/GMinerRelease/releases/download/2.29/gminer_2_29_windows64.zip"
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
                $Arguments = "--proto stratum --dual_intensity 0 --watchdog 0 --pec 0 --nvml 0 --devices $($Config.SelGPUDSTM) --api $($Variables.NVIDIAMinerAPITCPPort) --algo eth+ckb --server $($Pool_Ethash.Host):$($Pool_Ethash.Port) --user $($Pool_Ethash.User) --dserver $($Pool_eaglesong.Host):$($Pool_eaglesong.Port) --duser $($Pool_eaglesong.User)"
            } else {
                $Arguments = "--dual_intensity 0 --watchdog 0 --pec 0 --nvml 0 --devices $($Config.SelGPUDSTM) --api $($Variables.NVIDIAMinerAPITCPPort) --algo eth+ckb --server $($Pool_Ethash.Host):$($Pool_Ethash.Port) --user $($Pool_Ethash.User) --dserver $($Pool_eaglesong.Host):$($Pool_eaglesong.Port) --duser $($Pool_eaglesong.User)"
            }
            
            [PSCustomObject]@{
                Type      = "NVIDIA"
                Path      = $Path
                Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
                HashRates = [PSCustomObject]@{Ethash =  "$($Stats.gminerdual_Ethash_HashRate.Day * .97)";eaglesong =  "$($Stats.gminerdual_eaglesong_HashRate.Day)"} # substract 2% devfee
                API       = "gminerdual"
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
