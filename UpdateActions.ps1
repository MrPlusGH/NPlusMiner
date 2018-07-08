<#
This file is part of NPlusMiner
Copyright (c) 2018 MrPlus

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
File:           UpdateActions.ps1
version:        4.0.1
version date:   20180703
#>

# $Config | Add-Member @{Autoupdate = $true} -force
# $Config | Add-Member @{ManualConfig = $false} -force
# Write-Config -ConfigFile $ConfigFile -Config $Config

if (Test-Path ".\Miners\EWBF.ps1") {Remove-item .\Miners\EWBF.ps1}
if (Test-Path ".\Miners\wrapper.ps1") {Remove-item .\Miners\Wrapper.ps1}
