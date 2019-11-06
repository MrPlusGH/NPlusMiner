if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\CPU-XMRig\xmrig.exe"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.6.2/xmrig-2.6.2-msvc-win64.zip"

$Commands = [PSCustomObject]@{
    #"cryptonight" = "" #Cryptonight
    #"cryptonight-lite" = "" #Cryptonight-lite
    #"cryptonight-heavy" = "" #Cryptonight-Heavy
    #"cryptonightV7" = "" #CryptonightV7
}

$ThreadCount = $ThreadCount = $Variables.ProcessorCount - 2

$Port = $Variables.CPUMinerAPITCPPort #2222
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo =$_
	$AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password) --api-port $($port) --donate-level 1"

        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .99} # substract 1% devfee
            API = "XMRig"
            Port = $Port
            Wrap = $false
            URI = $Uri    
            User = $Pool.User
        }
    }
}
