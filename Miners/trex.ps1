if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-trex\t-rex.exe"
$Uri = "https://github.com/trexminer/T-Rex/releases/download/0.14.6/t-rex-0.14.6-win-cuda10.0.zip"
 
$Commands = [PSCustomObject]@{
    "astralhash" = "" #Astralhash
    "balloon"    = "" #Balloon(fastest)
    "bcd"        = " -i 24" #Bcd (fastest)
    "bitcore"    = " -i 25" #Bitcore( fastest)
    "c11"        = " -i 24" #C11 (fastest)
    #"dedal"      = "" #Dedal (fastest)
    "geek"       = "" #Geekcash
    "honeycomb"  = "" #honeycomb
    "jeonghash"  = "" #Jeonghash
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
    #"hmq1725" = " -i 23" #Hmq1725 (CryptoDredge faster)
    #"lyra2z" = "" #Lyra2z (Asic)
    #"skunk" = "" #Skunk (CryptoDredge faster)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $MinerAlgo = switch ($_){
		"Veil"	{ "x16rt" }
		default	{ $_ }
	}
    $Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type      = "NVIDIA"
        Path      = $Path
        Arguments = "--no-watchdog --no-nvml -b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -a $($MinerAlgo) -o stratum+tcp://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass)$($Commands.$_) --quiet -r 10 --cpu-priority 4"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week * .99} # substract 1% devfee
        API       = "ccminer"
        Port      = $Variables.NVIDIAMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
}
