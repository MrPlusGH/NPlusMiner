if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-trex\t-rex.exe"
$Uri = "https://github.com/trexminer/T-Rex/releases/download/0.18.8/t-rex-0.18.8-win-cuda10.0.zip"
 
$Commands = [PSCustomObject]@{
    "astralhash" = "" #Astralhash
    "balloon"    = "" #Balloon(fastest)
    "bcd"        = " -i 24" #Bcd (fastest)
    "bitcore"    = " -i 25" #Bitcore( fastest)
    "c11"        = " -i 24" #C11 (fastest)
    "geek"       = "" #Geekcash
    "honeycomb"  = "" #honeycomb
    "jeonghash"  = "" #Jeonghash
    # "kawpow"     = "" #kawpow 
    "mtp"        = "" #MTP
    "padihash"   = "" #Padihash
    "pawelhash"  = "" #Pawelhash
    "polytimos"  = " -i 25" #Poly (fastest) 
    "sha256q"    = "" #Sha256q (testing)
    "sha256t"    = " -i 26" #Sha256t (fastest)
    "sonoa"      = " -i 23" #Sonoa (fastest)
    "timetravel" = " -i 25" #Timetravel (fastest)
    "tribus"     = " -i 23" #Tribus
    "veil"      = " -i 24" #Veil (fastest)
    "x16r"       = " -i 24" #X16r (fastest)
    "x16rt"      = " -i 24" #X16rt (fastest)
    "x16rv2"     = " -i 24" #X16rv2 ,mc=RVN
    "x16s"       = " -i 24" #X16s (fastest)
    "x17"        = " -i 24" #X17 (fastest)
    "x21s"       = "" #X21s (fastest)
    "x22i"       = " -i 23" #X22i (fastest)
    "x25x"       = " -i 21" #25x
    # "dedal"      = "" #Dedal (fastest)
    #"hmq1725" = " -i 23" #Hmq1725 (CryptoDredge faster)
    #"lyra2z" = "" #Lyra2z (Asic)
    #"skunk" = "" #Skunk (CryptoDredge faster)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands.PSObject.Properties.Name | ForEach-Object {
    $MinerAlgo = switch ($_){
        "Veil"    { "x16rt" }
        default    { $_ }
    }

    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "--no-watchdog --no-nvml -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -a $($MinerAlgo) -o stratum+tcp://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password) --quiet -r 10 --cpu-priority 4"
        
        [PSCustomObject]@{
            Type      = "NVIDIA"
            Path      = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .99} # substract 1% devfee
            API       = "ccminer"
            Port      = $Variables.NVIDIAMinerAPITCPPort
            Wrap      = $false
            URI       = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
        }
    }
}
