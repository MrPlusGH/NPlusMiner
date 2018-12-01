if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\NVIDIA-trex083\t-rex.exe"
$Uri = "https://github.com/trexminer/T-Rex/releases/download/0.8.3/t-rex-0.8.3-win-cuda10.0.zip"

$Commands = [PSCustomObject]@{
    "balloon" = "" #Balloon(fastest)
    "bcd" = "" #Bcd(fastest)
    "bitcore" = "" #Bitcore(fastest)
    "c11" = "" #C11(fastest)
    "dedal" = "" #Dedal
    "hmq1725" = "" #Hmq1725(fastest)
    "hsr" = "" #Hsr(Testing)
    "lyra2z" = "" #Lyra2z (cryptodredge faster)
    "polytimos" = "" #Poly(fastest)
    "sha256t" = "" #Sha256t(fastest)
    "skunk" = "" #Skunk(fastest)
    "sonoa" = "" #SonoA(fastest)
    "timetravel" = "" #Timetravel(fastest)
    "tribus" = "" #Tribus(CryptoDredge faster)
    "x16r" = "" #X16r(fastest)
    "x16s" = "" #X16s(fastest)
    "x17" = "" #X17(fastest)
    "x21s" = "" #X21s
    "x22i" = "" #Suqa
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-b 127.0.0.1:$($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_) --quiet -r 10 --cpu-priority 5"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Day * .99} # substract 1% devfee
        API = "ccminer"
        Port = $Variables.NVIDIAMinerAPITCPPort
        Wrap = $false
        URI = $Uri
        User = $Pools.(Get-Algorithm($_)).User
        Host = $Pools.(Get-Algorithm $_).Host
        Coin = $Pools.(Get-Algorithm $_).Coin
    }
}
