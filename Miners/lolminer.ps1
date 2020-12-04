if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-AMD-lolMiner\lolMiner.exe"
$Uri = "https://github.com/Lolliedieb/lolMiner-releases/releases/download/1.16/lolMiner_v1.16a_Win64.zip"

$Commands = [PSCustomObject]@{
    # "equihash96" = " --coin MNX" #Equihash 96,5
    #"Equihash21x9" = "--coin AION" #Equihash 210,9
    # "equihash144" = " --coin AUTO144_5" #Equihash 144,5
    # "GrinCuckatoo32" = " --coin GRIN-C32" #Equihash 144,5
    # "beam" = " --coin BEAM" #Equihash 150,5
    }
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$WinningCustomConfig = [PSCustomObject]@{}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--user $($Pool.User) --pool $($Pool.Host) --port $($Pool.Port) --devices $($Config.SelGPUCC) --apiport $($Variables.NVIDIAMinerAPITCPPort) --tls 0 --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 --pass $($Password)"
        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments =  Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week * 0.99} # 1% dev fee
            API       = "LOL"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri    
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
        
        $Arguments = "--user $($Pool.User) --pool $($Pool.Host) --port $($Pool.Port) --devices $($Config.SelGPUCC) --apiport $($Variables.AMDMinerAPITCPPort) --tls 0 --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 --pass $($Password)"
        [PSCustomObject]@{
            Type      = "AMD"
            Path      = $Path
            Arguments =  Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week * 0.99} # 1% dev fee
            API       = "LOL"
            Port      = $Variables.AMDMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri    
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}


