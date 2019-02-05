if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = '.\Bin\AMD-WildRigMulti\wildrig.exe'
$Uri = 'https://github.com/andru-kun/wildrig-multi/releases/download/0.15.0/wildrig-0.15.0.6-beta.7z'

$Commands = [PSCustomObject]@{
    bcd = '' #BitcoinDiamond
    bitcore = '' #Bitcore
	c11 = '' #C11
	dedal = '' #Dedal
	exosis = '' #Exosis
	geek = '' #GeekCash
	hex = '' #XDNA
	hmq1725 = '' #Hmq1725
	phi = '' #Phi
	renesis = '' #renesis
	skunkhash = '' #Skunk
	sonoa = '' #sonoa
	timetravel = '' #timetravel
	timetravel10 = '' #Bitcore
	tribus = '' #Tribus
	x16r = '' #x16r
	x16s = '' #x16s
	x17 = '' #x17
	x21s = '' #x21s
	x22i = '' #x22i
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-port=$($Variables.AMDMinerAPITCPPort) --algo $_ --url=$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) --user=$($Pools.(Get-Algorithm($_)).User) --pass=$($Pools.(Get-Algorithm($_)).Pass) $($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Live}
        API = "Xmrig"
        Port = $Variables.AMDMinerAPITCPPort
        Wrap = $false
        URI = $Uri
        User = $Pools.(Get-Algorithm($_)).User
        Host = $Pools.(Get-Algorithm $_).Host
        Coin = $Pools.(Get-Algorithm $_).Coin
    }
}
