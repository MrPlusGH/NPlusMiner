

if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\\Bin\\NVIDIA-Phoenix\\PhoenixMiner.exe"
$Uri = "https://github.com/Minerx117/miner-binaries/releases/download/4.6c/PhoenixMiner_4.6c_Windows.7z"
$Commands = [PSCustomObject]@{
    #"ethash" = " -di $($($Config.SelGPUCC).Replace(',',''))" #Ethash(fastest)
    # "progpow" = " -coin bci -di $($($Config.SelGPUCC).Replace(',',''))" #Progpow 
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-nvdo 1 -esm 3 -allpools 1 -allcoins 1 -platform 2 -mport -$($Variables.NVIDIAMinerAPITCPPort) -epool $($Pool.Host):$($Pool.Port) -ewal $($Pool.User) -epsw $($Password)"

        [PSCustomObject]@{
            Type = "NVIDIA"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .9935} # substract 1% devfee
            API = "ethminer"
            Port = $Variables.NVIDIAMinerAPITCPPort #3333
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
