# Note that CustomMinersConfig will not work with this one

if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}
 
$Path = ".\Bin\NVIDIA-Bminer\bminer.exe"
$Uri = "https://github.com/Minerx117/miner-binaries/releases/download/16.0.1/bminer-v16.0.1.zip"

Return

$Commands = [PSCustomObject]@{
    # "Grincuckaroo29" = " -uri cuckaroo29://" #Grin(testing)
    "ethash" = " -uri ethstratum://" #Ethash (fastest)
    # "aeternity" = " -uri aeternity://" #aeternity(testing)
    # "beam" = " -uri beam://" #beam(testing)
    #"equihash" = " -uri stratum://" #Equihash(Asic)
    #"equihash144" = " -pers auto -uri equihash1445://" #Equihash144(gminer faster)
    #"equihashBTG" = " -uri zhash://" #EquihashBTG(miniZ faster)
    #"zhash" = " -pers auto -uri equihash1445://" #Zhash(gminer faster)
    # "cuckaroom" = " -uri cuckaroo29m://" #cuckaroo29m
}
$Port = $Variables.NVIDIAMinerAPITCPPort
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | ForEach-Object {
    $Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Pass = If ($Password -like "*,*") {$Password.ToString().replace(',','%2C')} else {$Password}
        $Arguments = "$($Commands.$Algo)$($Pool.User):$($Pass)@$($Pool.Host):$($Pool.Port) -max-temperature 94 -nofee -devices $($Config.SelGPUCC) -api 127.0.0.1:$Port"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = $Arguments.Trim() #Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week}
            API       = "bminer"
            Port      = $Port
            Wrap      = $false
            URI       = $Uri    
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
