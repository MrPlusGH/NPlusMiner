$headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}

$Status = ((Invoke-ProxiedWebRequest "https://prohashing.com/api/v1/status" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).data
Sleep 1
$CurrenciesQuery = ((Invoke-ProxiedWebRequest "https://prohashing.com/api/v1/currencies" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).data
$Currencies = [PSCustomObject]@{}
# $Status.PSObject.Properties.name | ? {$_ -eq "Neoscrypt"} | foreach {
$Status.PSObject.Properties.name | foreach {
    $Algo = $_.ToLower()
    
    $Status.$Algo | Add-Member -Force @{algo = $Algo}
    $Status.$Algo | Add-Member -Force @{fees = $Status.$Algo.pps_fee}

    $CurrenciesQuery.PsObject.Properties.Name | Foreach {
        If ($CurrenciesQuery.$_.enabled) {
            $Currency = $CurrenciesQuery.$_
            $Currency | Add-Member -Force @{symbol = $_}
            $Currency | Add-Member -Force @{fees = $Status.($Currency.algo).pps_fees}
            $Currency | Add-Member -Force @{estimate = $Status.($Currency.algo).estimate_current}
            $Currency | Add-Member -Force @{port = $Status.($Currency.algo).Port}
            # Write-host "$($Currency.algo) -- $($Currency.symbol) -- $($Status.($Currency.algo).estimate_current)"
            $Currencies | Add-Member -Force @{$_ = $Currency}
        }
    }

}
    $API = [PSCustomObject]@{
        Status = $Status
        Currencies = $Currencies
        Blocks = $AllBlocks
    }

    $API
