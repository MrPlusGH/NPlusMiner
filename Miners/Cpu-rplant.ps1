if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

If (!($Variables.CPUFeatures)){
    try {$Variables.CPUFeatures = $($feat = @{}; switch -regex ((& .\Includes\CHKCPU32.exe /x) -split "</\w+>") {"^\s*<_?(\w+)>(.*).*" {$feat.($matches[1]) = try {[int]$matches[2]}catch{$matches[2]}}}; $feat)} catch {if ($Error.Count){$Error.RemoveAt(0)}}
}

$Path = ".\Bin\CPU-rplant\cpuminer-sse42.exe"
$Uri = "https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.19/cpuminer-opt-win.zip"

$Commands = [PSCustomObject]@{
    "ghostrider" = "" #ghostrider 
    "yescryptR8G" = "" #YescryptR8
    "yespowerIOTS" = "" #yespowerIOTS
    # "yespowerSUGAR" = "" #yespowerSUGAR
    # "yespowerLITB" = "" #yespowerLITB
    # "yespowerIC" = "" #yespowerIC
    # "yespowerLNC" = "" #yespowerLTNCG
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
    switch ($_) { 
        ghostrider { 
            $ThreadCount = $Variables.ProcessorCount - 2
            If ($Variables.CPUFeatures.avx2) {$Path = ".\Bin\CPU-rplant\cpuminer-avx2.exe"}
        }
        default { $ThreadCount = $Variables.ProcessorCount - 2 }
    }

    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        $Arguments = "-q -t $($ThreadCount) -b $($Variables.CPUMinerAPITCPPort) -a $AlgoNorm -o $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"

        [PSCustomObject]@{
            Type = "CPU"
            Path = $Path
            Arguments = Merge-Command -Slave $Arguments -Master $CustomCmdAdds -Type "Command"
            HashRates = [PSCustomObject]@{($AlgoNorm) = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week} 
            API = "ccminer"
            Port = $Variables.CPUMinerAPITCPPort
            Wrap = $false
            URI = $Uri
            User = $Pool.User
            Host = $Pool.Host
            Coin = $Pool.Coin
            ThreadCount      = $ThreadCount
        }
    }
}
