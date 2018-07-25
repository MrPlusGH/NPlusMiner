if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
$Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.7.0/CryptoDredge_0.7.0_windows.zip"

$Commands = [PSCustomObject]@{
    "allium" = "" #Allium
    "lyra2v2" = "" #Lyra2RE2
    "lyra2z" = " --submit-stale" #Lyra2z
    "neoscrypt" = "" #NeoScrypt
    "phi" = "" #Phi
    "phi2" = "" #Phi2
    "skein" = "" #Skein
    "skunk" = "" #Skunk
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$Port = $Variables.NVIDIAMinerAPITCPPort

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = " -b 127.0.0.1:$($Port) -d $($Config.SelGPUCC) -a $_ --no-watchdog -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_) -R 1 -q -N 1"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week * .99} # substract 1% devfee
        API = "cryptodredge"
        Port = $Port
        Wrap = $false
        URI = $Uri
        User = $Pools.(Get-Algorithm($_)).User
        Host = $Pools.(Get-Algorithm $_).Host
        Coin = $Pools.(Get-Algorithm $_).Coin
    }
}
