if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-zealotenemy\z-enemy.exe"
$Uri = "https://github.com/Minerx117/ZEnemy-Miner/releases/download/v2.0.0/ZEnemy200cuda10.7z"

$Commands = [PSCustomObject]@{
    "aeriumx" = " -i 23" #AeriumX(fastest)
    #"bcd"     = "" #Bcd(trex faster)
    #"phi"        = "" #Phi (CryptoDredge faster)
    #"phi2"       = "" #Phi2 (CryptoDredge faster)
    #"poly"       = "" #Polytimos(fastest) 
    #"bitcore"    = "" #Bitcore (trex faster)
    #"x16r"       = "" #X16r (trex faster)
    #"x16s"       = "" #X16s (trex faster)
    #"sonoa"      = "" #SonoA (trex faster)
    #"skunk"      = "" #Skunk (CryptoDredge faster)
    #"timetravel" = "" #Timetravel (trex faster)
    #"tribus"     = "" #Tribus (not profitable atm)
    #"c11"        = "" #C11 (trex faster)
    "xevan"   = " -i 22" #Xevan (fastest)
    #"x17"        = "" #X17(trex faster)
    "hex" = " -i 24" #Hex (fastest)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-b $($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -R 1 -q -a $AlgoNorm -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Day * .99} # substract 1% devfee
            API       = "ccminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User      = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
