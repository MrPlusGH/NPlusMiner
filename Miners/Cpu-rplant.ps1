if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

Get-CPUFeatures

$MinerFeatureType = if($Variables.CPUFeatures.avx512){
	'avx512'
	}elseif($Variables.CPUFeatures.avx2 -and $Variables.CPUFeatures.sha -and $Variables.CPUFeatures.aes){
		'ryzen'
		}elseif($Variables.CPUFeatures.avx2 -and $Variables.CPUFeatures.aes){
			'avx2'
			}elseif($Variables.CPUFeatures.avx -and $Variables.CPUFeatures.aes){
				'avx'
				}elseif($Variables.CPUFeatures.sse42 -and $Variables.CPUFeatures.aes){
					'sse42-aes'
					}elseif($Variables.CPUFeatures.sse42){
						'sse42'
						}elseif($Variables.CPUFeatures.cpu_vendor -eq "AMD"){
							'sse2amd'
							}else{
								'sse2'
								}
 
$Path = ".\Bin\CPU-rplant\cpuminer-$($MinerFeatureType).exe"
# $Uri = "https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.19/cpuminer-opt-win.zip"
$Uri = "https://github.com/rplant8/cpuminer-opt-rplant/releases/download/5.0.24/cpuminer-opt-win.zip"

$Commands = [PSCustomObject]@{
    # "ghostrider" = "" #ghostrider 
    "yescryptR8G" = "" #YescryptR8
    "yespowerIOTS" = "" #yespowerIOTS
    "minotaurx" = "" #minotaurx
    "yespowerARWN" = "" #yespowerARWN
    "yespowerURX" = "" #yespowerURX
    # "yespowerSUGAR" = "" #yespowerSUGAR
    # "yespowerLITB" = "" #yespowerLITB
    # "yespowerIC" = "" #yespowerIC
    # "yespowerLNC" = "" #yespowerLTNCG
}

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { 
    switch ($_) { 
        # ghostrider { 
            # $ThreadCount = $Variables.ProcessorCount - 2
            # If ($Variables.CPUFeatures.avx2) {$Path = ".\Bin\CPU-rplant\cpuminer-avx2.exe"}
        # }
        default { $ThreadCount = $Variables.ProcessorCount - 2 }
    }



    $Algo =$_
    $AlgoNorm = Get-Algorithm($_)

    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        invoke-Expression -command ( $MinerCustomConfigCode )
        If ($AbortCurrentPool) {Return}

        #Zpool fixed it on 20211205
        # If ($Pool.Host -like "*zpool.ca" -and $Algo -eq "Minotaurx") {
            # $Arguments = "-f 65536 -q -t $($ThreadCount) -b $($Variables.CPUMinerAPITCPPort) -a $AlgoNorm -o $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"
        # } else {
            # $Arguments = "-q -t $($ThreadCount) -b $($Variables.CPUMinerAPITCPPort) -a $AlgoNorm -o $($Pool.Protocol)://$($Pool.Host):$($Pool.Port) -u $($Pool.User) -p $($Password)"
        # }

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
