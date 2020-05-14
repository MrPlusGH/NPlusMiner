if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\AMD-WildRigMulti\wildrig.exe"
$Uri = "https://github.com/andru-kun/wildrig-multi/releases/download/0.23.2/wildrig-multi-windows-0.23.2.7z"

$Commands = [PSCustomObject]@{
    "astralhash"    = " --algo glt-astralhash" #Astralhash
    "bcd"           = " --algo bcd" #BitcoinDiamond
    "bitcore"       = " --algo bitcore" #Bitcore
    "bmw512"        = " --algo bmw512" #bmw512
    "c11"           = " --algo c11" #C11
    "dedal"         = " --algo dedal" #Dedal
    "exosis"        = " --algo exosis" #Exosis
    "geek"          = " --algo geek" #GeekCash
    "hex"           = " --algo hex" #XDNA
    "hmq1725"       = " --algo hmq1725" #Hmq1725
    "honeycomb"     = " --algo honeycomb" #Honeycomb 
    "jeonghash"     = " --algo glt-jeonghash" #Jeonghash
    "kawpow"        = " --algo kawpow"
    "lyra2v3"       = " --algo lyra2v3"
    "mtp"           = " --algo mtp" #Mtp
    "mtp-trc"       = " --algo mtp-trc" #Mtp-trc
    "padihash"      = " --algo glt-padihash" #Padihash
    "pawelhash"     = " --algo glt-pawelhash" #powelhash
    "phi"           = " --algo phi" #Phi
    "polytimos"     = " --algo polytimos"
    "renesis"       = " --algo renesis" #renesis
    "sha256q"       = " --algo sha256q"
    "sha256t"       = " --algo sha256t"
    "skein2"        = " --algo skein2" #Skein2
    "skunkhash"     = " --algo skunkhash" #Skunk
    "sonoa"         = " --algo sonoa" #sonoa
    "timetravel"    = " --algo timetravel" #timetravel
    "tribus"        = " --algo tribus" #Tribus
    "Xevan"         = "--algo xevan" #Xevan
    "x16r"          = " --algo x16r" #x16r
    "x16rt"         = " --algo x16rt"
    "x16rv2"        = " --algo x16rv2" #X16rv2
    "x16s"          = " --algo x16s" #x16s
    "x17"           = " --algo x17" #x17
    "x21s"          = " --algo x21s" #x21s
    "x22i"          = " --algo x22i" #x22i
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

        [PSCustomObject]@{
            Type = "AMD"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .99} # substract 1% devfee
            API = "Xmrig"
            Port = $Variables.AMDMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
