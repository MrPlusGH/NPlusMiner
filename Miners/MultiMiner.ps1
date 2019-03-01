if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\NVIDIA-MultiMiner\multiminer.exe"
$Uri = "https://github.com/bogdanadnan/multiminer/releases/download/v1.1.0/multiminer_v1.1.0_24.01.2019.zip"

$Commands = [PSCustomObject]@{
    "argon2d4096" = " -t 2 --gpu-batchsize=512 " #argon2d4096 
    "argon2d-dyn" = " -t 2 --gpu-batchsize=512 " #argon2d500 
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {

	$Algo = Get-Algorithm($_)
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "--gpu-id=$($Config.SelGPUMM) -q -b $($Variables.NVIDIAMinerAPITCPPort) -a $_ -o $($Pools.($Algo).Protocol)://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass) --use-gpu=CUDA$($Commands.$_)"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week * 0.99}
        API = "Ccminer"
        Port = $Variables.NVIDIAMinerAPITCPPort
        Wrap = $false
        URI = $Uri
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--gpu-id=$($Config.SelGPUMM) -q -b $($Variables.AMDMinerAPITCPPort) -a $_ -o $($Pools.($Algo).Protocol)://$($Pools.($Algo).Host):$($Pools.($Algo).Port) -u $($Pools.($Algo).User) -p $($Pools.($Algo).Pass) --use-gpu=OPENCL --gpu-batchsize=256 -t 2"
        HashRates = [PSCustomObject]@{($Algo) = $Stats."$($Name)_$($Algo)_HashRate".Week * 0.99}
        API = "Ccminer"
        Port = $Variables.AMDMinerAPITCPPort
        Wrap = $false
        URI = $Uri
        User = $Pools.($Algo).User
        Host = $Pools.($Algo).Host
        Coin = $Pools.($Algo).Coin
    }
}
