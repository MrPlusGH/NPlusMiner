if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\CPU-rplant\cpuminer-sse42.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/Cpu-rplant/cpuminer-opt-win.zip"

$Commands = [PSCustomObject]@{
    "yescryptR8G" = "" #YescryptR8
    "yespowerIOTS" = "" #yespowerIOTS
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {

    switch ($_) {
        "hodl" {$ThreadCount = $Variables.ProcessorCount}
        default {$ThreadCount = $Variables.ProcessorCount - 2}
    }

    $Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type = "CPU"
        Path = $Path
        Arguments = "-q -t $($ThreadCount) -b $($Variables.CPUMinerAPITCPPort) -a $_ -o $($Pools.($Algo).Protocol)://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week}
        API = "Ccminer"
        Port = $Variables.CPUMinerAPITCPPort
        Wrap = $false
        URI = $Uri
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
        ThreadCount      = $ThreadCount
    }
}
