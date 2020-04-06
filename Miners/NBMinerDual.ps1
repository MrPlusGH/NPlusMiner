if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-NBMiner\nbminer.exe"
$Uri = "https://github.com/NebuTech/NBMiner/releases/download/v26.2/NBMiner_26.2_Win.zip"
$Commands = [PSCustomObject]@{
    "ethash+eaglesong"          = "" #Ethash
}

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

            $Arguments = " -a eaglesong_ethash --no-watchdog --no-nvml --temperature-limit 95 -di 24 -d $($Config.SelGPUCC) --api 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool_eaglesong.Host):$($Pool_eaglesong.Port) -u $($Pool_eaglesong.User):$($Password) -do nicehash+tcp://$($Pool_Ethash.Host):$($Pool_Ethash.Port) -du $($Pool_Ethash.User):$($Password)"
            
            [PSCustomObject]@{
                Type      = "NVIDIA"
                Path      = $Path
                Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
                HashRates = [PSCustomObject]@{Ethash =  "$($Stats.nbminerdual_Ethash_HashRate.Day * .97)";eaglesong =  "$($Stats.nbminerdual_eaglesong_HashRate.Day)"} # substract 2% devfee
                API       = "NBMinerdual"
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
