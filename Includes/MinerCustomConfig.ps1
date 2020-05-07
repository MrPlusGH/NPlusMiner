<#
This file is part of NPlusMiner
Copyright (c) 2018-2019 MrPlus

NPlusMiner is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

NPlusMiner is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>

<#
Product:        NPlusMiner
File:           MinerCustomConfig.ps1
version:        5.9.9
version date:   20191108
#>

    $AbortCurrentPool = $False
    $DontUseCustom = $False
    $MinerCustomConfig = $MinerCustomConfig.Where({$_.Enabled})
    $Combinations = $MinerCustomConfig | group algo,Pool,miner,coin
    $CustomCommands = [PSCustomObject]@{}
    $DontUseCustom = $False
    $DevCommand = ""
    $WinningCustomConfig = $null
    $CurrentCombination = $null
    If ($Pool.Algorithm) {$CustomCommands | Add-Member -Force @{($Pool.Algorithm) = $Commands.($Algo)}}

    #Apply Dev Args
    If ($CustomCommands.($Pool.Algorithm)) {$DevCommand = If ($CustomCommands.($Pool.Algorithm).StartsWith(",")) {$CustomCommands.($Pool.Algorithm).split(" ") -replace ($CustomCommands.($Pool.Algorithm).split(" ")[0]),"" -join " "} else {$CustomCommands.($Pool.Algorithm)}}
    If ($CustomCommands.($Pool.Algorithm)) {$DevPass = If ($CustomCommands.($Pool.Algorithm).StartsWith(",")) { $CustomCommands.($Pool.Algorithm).split(" ")[0] } else {""}}
    $Password = Merge-Command -Slave $Pool.Pass -Master $DevPass -Type "Password"

    $CustomCmdAdds = $DevCommand
    #Apply user Args
    # Test custom config for Algo, coin, Miner, Coin
    #PrioritizedCombinations | highest at bottom

    $OrderedCombinations = @(
        ", , $($Name), ",
        "$($Pool.Algorithm), , , ",
        "$($Pool.Algorithm), $($Pool.Name), , ",
        "$($Pool.Algorithm), , $($Name), ",
        "$($Pool.Algorithm), $($Pool.Name), $($Name), ",
        "$($Pool.Algorithm), $($Pool.Name), , $($Pool.Coin)"
        "$($Pool.Algorithm), , , $($Pool.Coin)"
        "$($Pool.Algorithm), $($Pool.Name), $($Name), $($Pool.Coin)"
    ) 
    $WinningCustomConfig = ($Combinations.Where({$_.Name -like (Compare-Object $OrderedCombinations $Combinations.Name -IncludeEqual -ExcludeDifferent -PassThru | select -Last 1)})).Group
    if ($WinningCustomConfig) {
        If ($WinningCustomConfig.IncludeCoins -and $Pool.Coin -notin $WinningCustomConfig.IncludeCoins) {$AbortCurrentPool = $true ; Return}
        If ($WinningCustomConfig.ExcludeCoins -and $Pool.Coin -in $WinningCustomConfig.ExcludeCoins) {$AbortCurrentPool = $true ; Return}
        If ($WinningCustomConfig.code) {
            $WinningCustomConfig.code | Invoke-Expression
            # Can't get return or continue to work in context correctly when inserted in custom code.
            # Workaround with variable. So users have a way to not apply custom config based on conditions.
            If ($DontUseCustom) {Return}
        }
        If ($WinningCustomConfig.CustomPasswordAdds -and !($Variables.DonationStart -or $Variables.DonationRunning)) {
            $CustomPasswordAdds = $WinningCustomConfig.CustomPasswordAdds.Trim()
            $Password = Merge-Command -Slave $Password -Master $CustomPasswordAdds -Type "Password"
        }
        If ($WinningCustomConfig.CustomCommandAdds) {
            $CustomCmdAdds = $WinningCustomConfig.CustomCommandAdds.Trim()
            $CustomCmdAdds = Merge-Command -Slave $DevCommand -Master $CustomCmdAdds -Type "Command"
        }
    }
    $CustomPasswordAdds = $null

    $WinningCustomConfig = $null


