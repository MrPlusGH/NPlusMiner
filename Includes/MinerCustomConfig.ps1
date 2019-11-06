            $MinerCustomConfig = $MinerCustomConfig | ? {$_.Enabled}
            $Combinations = $MinerCustomConfig | group algo,Pool,miner,coin
            $CustomCommands = [PSCustomObject]@{}
            $DontUseCustom = $False
            $WinningCustomConfig = $null
            $CurrentCombination = $null
            If ($Pool.Algorithm) {$CustomCommands | Add-Member -Force @{($Pool.Algorithm) = $Commands.($Pool.Algorithm)}}


            #Apply Dev Args
            If ($CustomCommands.($Algo)) {$DevCommand = If ($CustomCommands.($Algo).StartsWith(",")) {$CustomCommands.($Algo).split(" ") -replace ($CustomCommands.($Algo).split(" ")[0]),"" -join " "} else {$CustomCommands.($Algo)}}
            If ($CustomCommands.($Algo)) {$DevPass = If ($CustomCommands.($Algo).StartsWith(",")) { $CustomCommands.($Algo).split(" ")[0] } else {""}}
            $Password = Merge-Command -Slave $Pool.Pass -Master $DevPass -Type "Password"
    
            $CustomCmdAdds = $DevCommand
    
            #Apply user Args
            # Test custom config for Algo, coin, Miner, Coin
            #PrioritizedCombinations | highest at bottom
            @(
                "$($Pool.Algorithm), , , ",
                "$($Pool.Algorithm), $($Pool.Name), , ",
                "$($Pool.Algorithm), , $($Name), ",
                "$($Pool.Algorithm), $($Pool.Name), $($Name), ",
                "$($Pool.Algorithm), $($Pool.Name), , $($Pool.Coin)"
                "$($Pool.Algorithm), , , $($Pool.Coin)"
                "$($Pool.Algorithm), $($Pool.Name), $($Name), $($Pool.Coin)"
            ) | foreach {
                if ($_ -in $Combinations.name) {
                    $CurrentCombination = $_
                    $WinningCustomConfig = ($Combinations | ? {$_.name -eq $CurrentCombination}).group[0]

                    If ($WinningCustomConfig.code) {
                        $WinningCustomConfig.code | Invoke-Expression
                        # Can't get return or continue to work in context correctly when inserted in custom code.
                        # Workaround with variable. So users have a way to not apply custom config based on conditions.
                        If ($DontUseCustom) {Return}
                    }
                    If ($WinningCustomConfig.CustomPasswordAdds) {
                        $CustomPasswordAdds = $WinningCustomConfig.CustomPasswordAdds.Trim()
                        $Password = Merge-Command -Slave $Password -Master $CustomPasswordAdds -Type "Password"
                    }
                    If ($WinningCustomConfig.CustomCommandAdds) {
                        $CustomCmdAdds = $WinningCustomConfig.CustomCommandAdds.Trim()
                        $CustomCmdAdds = Merge-Command -Slave $DevCommand -Master $CustomCmdAdds -Type "Command"
                    }
                }
                $CustomPasswordAdds = $null
                $CustomCommandAdds = $null
            }

            If ($WinningCustomConfig.IncludeCoins -and $Pool.Coin -notin $WinningCustomConfig.IncludeCoins) {$AbortCurrentPool = $true ; return}
            If ($WinningCustomConfig.ExcludeCoins -and $Pool.Coin -in $WinningCustomConfig.ExcludeCoins) {$AbortCurrentPool = $true ; return}
            $WinningCustomConfig = $null

