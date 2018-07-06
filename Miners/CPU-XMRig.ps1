if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1;RegisterLoaded(".\Include.ps1")}

$Path = ".\Bin\CPU-XMRig\xmrig.exe"
$Uri = "https://github.com/xmrig/xmrig/releases/download/v2.6.2/xmrig-2.6.2-msvc-win64.zip"

$Commands = [PSCustomObject]@{
    #"cryptonight" = "" #Cryptonight
    #"cryptonight-lite" = "" #Cryptonight-lite
    #"cryptonight-heavy" = "" #Cryptonight-Heavy
    #"cryptonightV7" = "" #CryptonightV7
}

$ThreadCount = (Get-WmiObject -class win32_processor).NumberOfLogicalProcessors - 2

$Port = $Variables.CPUMinerAPITCPPort #2222
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type = "CPU"
        Path = $Path
        # Arguments = "-t $($ThreadCount) -a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_) --api-port $($port) --donate-level 1"
        Arguments = "-a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_) --api-port $($port) --donate-level 1"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week * .99} # substract 1% devfee
        API = "XMRig"
        Port = $Port
        Wrap = $false
        URI = $Uri    
		User = $Pools.(Get-Algorithm($_)).User
    }
}
