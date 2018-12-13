if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1; RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\NVIDIA-zealotenemy\z-enemy.exe"
$Uri = "https://nemosminer.com/data/optional/z-enemy.1-27-cuda10.0.7z"

$Commands = [PSCustomObject]@{
    "aeriumx"    = "" #AeriumX(RTX)
    "bcd"        = "" #Bcd(RTX)
    "bitcore"    = "" #Bitcore (RTX)
    "c11"        = " -i 21" #C11 (RTX)
    "hex"        = "" #Hex (RTX)
    "hsr"        = " -i 21" #Hsr
    "phi"        = "" #Phi (RTX)
    "phi2"       = "" #Phi2 (RTX)
    "poly"       = "" #Polytimos(RTX) 
    "skunk"      = "" #Skunk (RTX)
    "sonoa"      = "" #SonoA (RTX)
    "timetravel" = "" #Timetravel (RTX)
    "tribus"     = "" #Tribus (RTX)
    "x16r"       = "" #X16r (RTX)
    "x16s"       = "" #X16s (RTX)
    "x17"        = " -i 21" #X17(RTX)
    "xevan"      = "" #Xevan (RTX)
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type      = "NVIDIA"
        Path      = $Path
        Arguments = "-b $($Variables.NVIDIAMinerAPITCPPort) -d $($Config.SelGPUCC) -R 1 -q -a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Day * .99} # substract 1% devfee
        API       = "ccminer"
        Port      = $Variables.NVIDIAMinerAPITCPPort
        Wrap      = $false
        URI       = $Uri
        User      = $Pools.(Get-Algorithm($_)).User
        Host = $Pools.(Get-Algorithm $_).Host
        Coin = $Pools.(Get-Algorithm $_).Coin
    }
}
