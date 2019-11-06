if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-zjazz12\zjazz_cuda.exe"
$Uri = "https://github.com/zjazz/zjazz_cuda_miner/releases/download/1.2/zjazz_cuda_win64_1.2.zip"

$Commands = [PSCustomObject]@{
    # "bitcash" = " -a bitcash" #Bitcash (testing)
    "cuckoo"  = " -a bitcash --cuckoo-intensity 22 " #Cuckoo (testing nlpool) --cuckoo-cpu-assist-min 
    #"x22i"    = " -a x22i" #SUQA (testing)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-d $($Config.SelGPUDSTM.Replace(' ', ' -d ')) --api-bind $($Variables.NVIDIAMinerAPITCPPort) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".week * .98 * 2000} # substract 2% devfee + Temp fix for nlpool wrong hashrate
            API       = "ccminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort #4068
            Wrap      = $false
            URI       = $Uri
            User      = $Pool.User
            Host      = $Pool.Host
            Coin      = $Pool.Coin
            PreventCPUMining      = $true
        }
    }
}
