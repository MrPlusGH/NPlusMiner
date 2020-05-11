if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1")}

$Path = ".\Bin\CryptoNight-FireIce\xmr-stak.exe"
$Uri = "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/MinersBinaries/A-xmrstak/xmr-stak-win64-2.10.5.7z"

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName
$Port = 3335

$Commands = [PSCustomObject]@{
    #"cryptonight_heavy" = "" # CryptoNight-Heavy(cryptodredge faster)
    #"cryptonight_lite"  = "" # CryptoNight-Lite
    #"cryptonight_v7"    = "" # CryptoNightV7(cryptodredge faster)
    #"cryptonight_v8"    = "" # CryptoNightV8
    # "monero"     = "" # Monero(v8)
    "cryptonight_r"     = "" #Cryptonight_r (Monero)
}

$Commands.PSObject.Properties.Name | ForEach-Object {

    $Algo =$_
    
    $AlgoNorm = Get-Algorithm($_)
    $Pools.($AlgoNorm) | foreach {
        $Pool = $_
        ([PSCustomObject]@{
                pool_list       = @([PSCustomObject]@{
                        pool_address    = "$($Pool.Host):$($Pool.Port)"
                        wallet_address  = "$($Pool.User)"
                        pool_password   = "$($Pool.Pass)"
                        use_nicehash    = $true
                        use_tls         = $Pool.SSL
                        tls_fingerprint = ""
                        pool_weight     = 1
                        rig_id          = ""
                    }
                )
                currency        = if ($Pool.Info) {"$($Pool.Info -replace '^monero$', 'monero7' -replace '^aeon$', 'aeon7')"} else {"$AlgoNorm"}
                call_timeout    = 10
                retry_time      = 10
                giveup_limit    = 0
                verbose_level   = 3
                print_motd      = $true
                h_print_time    = 60
                aes_override    = $null
                use_slow_memory = "warn"
                tls_secure_algo = $true
                daemon_mode     = $false
                flush_stdout    = $false
                output_file     = ""
                httpd_port      = $Port
                http_login      = ""
                http_pass       = ""
                prefer_ipv4     = $true
            } | ConvertTo-Json -Depth 10
        ) -replace "^{" -replace "}$" | Set-Content "$(Split-Path $Path)\$($Pool.Name)_$($AlgoNorm)_$($Pool.User)_AMD.txt" -Force -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Type      = "AMD"
            Path      = $Path
            Arguments = "-C $($Pool.Name)_$($AlgoNorm)_$($Pool.User)_AMD.txt --noNVIDIA --noCPU -i $($Port)"
            HashRates = [PSCustomObject]@{$AlgoNorm = $Stats."$($Name)_$($AlgoNorm)_HashRate".Week * .98} # substract 2% devfee
            API       = "fireice"
            Port      = $Port
            URI       = $Uri
        }
    }
}
