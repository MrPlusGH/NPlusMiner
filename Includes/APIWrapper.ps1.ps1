$headers = @{"Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"}

$Status = (Invoke-WebRequest "https://www.mining-dutch.nl/api/status/" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json
$CurrenciesQuery = @()
$Currencies = [PSCustomObject]@{}
$Status.PSObject.Properties.name | ? {$_ -eq "Neoscrypt"} | foreach {
    $Algo = $_
    
    Sleep 1
    $CurrenciesQuery += ((Invoke-WebRequest "https://www.mining-dutch.nl/api/v1/public/pooldata/?method=poolstats&algorithm=$($Algo)" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).Result
    
    $CurrenciesQuery | foreach {
        $_ | add-member -force @{Algo = $Algo}
        $Currencies | add-member -force @{$_.Tag = $_}
    }
    # $Status.$Algo | Add-Member -Force @{
        # Coins = ((Invoke-WebRequest "https://www.mining-dutch.nl/api/v1/public/pooldata/?method=poolstats&algorithm=$($Algo)" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).Result
    # }
    
    $CurrenciesQuery.Currency | foreach {
        $Currency = $_.ToLower()
        Sleep 1
        $Blocks = @()
        Try {
            $Blocks = ((Invoke-WebRequest "https://www.mining-dutch.nl/pools/$($Currency).php?page=api&action=getblocksfound&api_key=786485a87175fd1ac4ed2948c76a701aa97291058199996346e6f86db3272d22&id=56079" -UseBasicParsing -Headers $headers).Content | ConvertFrom-Json).getblocksfound.data
            Write-Host "$($Algo) -- $($Currency) -- Blocks success"
        } catch {
            Write-Host -F Y "$($Algo) -- $($Currency) -- Blocks error"
        }
        $Blocks | foreach {
            $_ | add-member -force @{Algo = $Algo}
            $_ | add-member -force @{Currency = $Currency}
            $_ | add-member -force @{Symbol = ($Status.$Algo.Coins | ? {$_.Currency -eq $Currency}).Tag}
            $_ | add-member -force @{Type = "Shared"}
        }
    $AllBlocks += $Blocks
    }
    $API = [PSCustomObject]@{
        Status = $Status
        Currencies = $Currencies
        Blocks = $AllBlocks
    }
    $API
}