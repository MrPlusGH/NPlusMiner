$headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}

$Status = (Invoke-WebRequest "https://www.mining-dutch.nl/api/status/" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json
sleep 1
$CurrenciesQuery = ((Invoke-WebRequest "https://www.mining-dutch.nl/api/v1/public/pooldata/?method=poolstats&algorithm=all" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).Result
$Currencies = [PSCustomObject]@{}
# $Status.PSObject.Properties.name | ? {$_ -eq "Neoscrypt"} | foreach {
$Status.PSObject.Properties.name | foreach {
    $Algo = $_.ToLower()
    
    $Status.$Algo | Add-Member -Force @{algo = $Algo}
    
}

    $CurrenciesQuery | ? {$_.Tag -and $_.status -eq "online" -and $_.algorithm -notin @("scrypt","sha256","tribus","equihash","odocrypt","x11","skunk","blake2s","nist5","myrgro","lyra2rev2","quark","YescryptR16" ) } | Sort blocks24h -Descending | foreach {
        $CurrentCurrency = $_
        Write-host "$($_.algorithm) -- $($_.Tag) -- $($Status.($_.algorithm).estimate_current)"
        $_ | add-member -force @{algo = $_.algorithm}
        $_ | add-member -force @{port = $Status.($_.algorithm).Port}
        $_ | add-member -force @{estimate = $Status.($_.algorithm).estimate_current}
        $Currencies | add-member -force @{$_.Tag = $_}

        # $Currency = $_.currency.ToLower()
        # Sleep 1
        # $Blocks = @()
        # Try {
            # $Blocks = ((Invoke-WebRequest "https://www.mining-dutch.nl/pools/$($Currency).php?page=api&action=getblocksfound&api_key=786485a87175fd1ac4ed2948c76a701aa97291058199996346e6f86db3272d22&id=56079" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).getblocksfound.data
            # Write-Host "$($_.algorithm) -- $($Currency) -- Blocks success"
        # } catch {
            # Write-Host -F Y "$($_.algorithm) -- $($Currency) -- Blocks error"
        # }
        # $Blocks | foreach {
            # $_ | add-member -force @{algo = ($CurrentCurrency.algorithm)}
            # $_ | add-member -force @{currency = $Currency}
            # $_ | add-member -force @{symbol = $CurrentCurrency.Tag}
            # $_ | add-member -force @{Type = "Shared"}
            # $_ | add-member -force @{category = "Immature"}
        # }
            # $AllBlocks += $Blocks
    }

    $API = [PSCustomObject]@{
        Status = $Status
        Currencies = $Currencies
        Blocks = $AllBlocks
    }
    $API
