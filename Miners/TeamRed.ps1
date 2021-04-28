if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\AMD-teamred081\teamredminer.exe"
$Uri = "https://github.com/todxx/teamredminer/releases/download/0.8.2.1/teamredminer-v0.8.2.1-win.zip"

$Commands = [PSCustomObject]@{
    "etchash"= " --algo etchash" #etchash
    "ethash" = " --algo ethash"  #ethash
    "kawpow" = " --algo kawpow"  #kawpow
    "verthash" = " --algo verthash"  #kawpow
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--api-port=$($Variables.AMDMinerAPITCPPort) --url=$($Pool.Host):$($Pool.Port) --opencl-threads auto --opencl-launch auto --user=$($Pool.User) --pass=$($Password)"
        $Arguments = "--temp_limit=90 --eth_stratum_mode=nicehash --pool_no_ensub --api_listen=127.0.0.1:$($Variables.AMDMinerAPITCPPort) --url=stratum+tcp://$($Pool.Host):$($Pool.Port) --user=$($Pool.User) --pass=$($Password)$($Commands.$_)"

        [PSCustomObject]@{
            Type = "AMD"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .99} # substract 1% devfee
            API = "teamred"
            Port = $Variables.AMDMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
