. .\includes\include.ps1

Write-Host "System Version: $([System.Environment]::OSVersion.Version)"
Write-Host "Powershell version: $($PSVersionTable.PSVersion)"

$VCRall = Get-WmiObject Win32_Product  -Filter "Name LIKE '%Microsoft Visual C++%'"

$AllVCOK = (
        ($VCRall | ? {$_.Name -like "Microsoft Visual C++ 2013 x86*"}).Count -gt 0 -and
        ($VCRall | ? {$_.Name -like "Microsoft Visual C++ 2013 x64*"}).Count -gt 0 -and
        ($VCRall | ? {$_.Name -like "Microsoft Visual C++ 2019 x86*"}).count -gt 0 -and
        ($VCRall | ? {$_.Name -like "Microsoft Visual C++ 2019 x64*"}).Count -gt 0
    )

If (-not $AllVCOK) {
	Write-Host -F Red "Some dependencies are missing. Installing."
	Write-Host -F Yellow "Please answer YES when asked."
	Write-Host "Downloading..."
    Expand-WebRequest "https://github.com/MrPlusGH/NPlusMiner-MinersBinaries/raw/master/PreReq/Visual-C-Runtimes.zip" (Split-Path ".\Utils\Prereq\Visual-C-Runtimes\install_all.bat")
	Write-Host "Installing..."
    Start-process ".\Utils\Prereq\Visual-C-Runtimes\install_all.bat"
} Else {
	Write-Host -F Green "All Good"
}
