if (!(IsLoaded(".\Include.ps1"))) {. .\Include.ps1; RegisterLoaded(".\Include.ps1")}

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
	$Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-port=$($Variables.AMDMinerAPITCPPort) --algo $_ --url=$($Pools.($Algo).Host):$($Pools.($Algo).Port) --user=$($Pools.($Algo).User) --pass=$($Pools.($Algo).Pass) $($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Live}
        API = "Xmrig"
        Port = $Variables.AMDMinerAPITCPPort
        Wrap = $false
        URI = $Uri
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
}
