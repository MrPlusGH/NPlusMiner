Function InitApplication {
	. .\include.ps1
	Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

	$MainForm.Variables | Add-Member -Force @{ScriptStartDate = (Get-Date)}
	# Fix issues on some SSL invokes following GitHub Supporting only TLSv1.2 on feb 22 2018
	[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
	Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)
	Get-ChildItem . -Recurse | Unblock-File
	Update-Status("INFO: Adding NPlusMiner path to Windows Defender's exclusions.. (may show an error if Windows Defender is disabled)")
	try{if((Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)){Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}}catch{}
	if($Proxy -eq ""){$PSDefaultParameterValues.Remove("*:Proxy")}
	else{$PSDefaultParameterValues["*:Proxy"] = $Proxy}
	Update-Status("Initializing Variables...")
	$MainForm.Variables | Add-Member -Force @{DecayStart = Get-Date}
	$MainForm.Variables | Add-Member -Force @{DecayPeriod = 120} #seconds
	$MainForm.Variables | Add-Member -Force @{DecayBase = 1-0.1} #decimal percentage
	$MainForm.Variables | Add-Member -Force @{ActiveMinerPrograms = @()}
	$MainForm.Variables | Add-Member -Force @{Miners = @()}
	#Start the log
		Start-Transcript -Path ".\Logs\miner.log" -Append -Force
	#Update stats with missing data and set to today's date/time
	if(Test-Path "Stats"){Get-ChildItemContent "Stats" | ForEach {$Stat = Set-Stat $_.Name $_.Content.Week}}
	#Set donation parameters
	#Randomly sets donation minutes per day between 0 - 5 minutes if not set
	$MainForm.Variables | Add-Member -Force @{DonateRandom = [PSCustomObject]@{}}
	$MainForm.Variables | Add-Member -Force @{LastDonated = (Get-Date).AddDays(-1).AddHours(1)}
	If ($MainForm.Config.Donate -lt 1) {$MainForm.Config.Donate = Get-Random -Maximum 5}
	$MainForm.Variables | Add-Member -Force @{WalletBackup = $MainForm.Config.Wallet}
	$MainForm.Variables | Add-Member -Force @{UserNameBackup = $MainForm.Config.UserName}
	$MainForm.Variables | Add-Member -Force @{WorkerNameBackup = $MainForm.Config.WorkerName}
	$MainForm.Variables | Add-Member -Force @{EarningsPool = ""}
	# Starts Brains if necessary
	Update-Status("Starting Brains for Plus...")
	$MainForm.Variables | Add-Member -Force @{BrainJobs = @()}
	$MainForm.Config.PoolName | foreach {
		$BrainPath = (Split-Path $script:MyInvocation.MyCommand.Path)+"\BrainPlus\"+$_
		# $BrainPath = ".\BrainPlus\"+$_
		$BrainName = (".\BrainPlus\"+$_+"\Brain-2.1.ps1")
		if (Test-Path $BrainName){
			$MainForm.Variables.BrainJobs += Start-Job -FilePath $BrainName -ArgumentList @($BrainPath)
		}
	}
	# Starts Earnings Tracker Job
	Update-Status("Starting Earnings Tracker...")
	$MainForm.Variables | Add-Member -Force @{EarningsTrackerJobs = @()}
	$MainForm.Variables | Add-Member -Force @{Earnings = @{}}
	$StartDelay = 0
	if ($MainForm.Config.TrackEarnings){$MainForm.Config.PoolName | sort | foreach {
		$Params = @{
			pool = $_
			Wallet = $Wallet
			Interval = 10
			WorkingDirectory = (Split-Path $script:MyInvocation.MyCommand.Path)
			StartDelay = $StartDelay
		}
		$MainForm.Variables.EarningsTrackerJobs += Start-Job -FilePath .\EarningsTrackerJob.ps1 -ArgumentList $Params
		# Delay Start when several instances to avoid conflicts.
		$StartDelay = $StartDelay + 10
	}
	}
	$Location = $MainForm.Config.Location
}

Function NPMCycle {
		. .\include.ps1
		$timerCycle.Enabled = $False
		Update-Status("Starting Cycle")
		Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)
		$host.UI.RawUI.WindowTitle = $MainForm.Variables.CurrentProduct + " " + $MainForm.Variables.CurrentVersion + " Runtime " + ("{0:dd\ \d\a\y\s\ hh\:mm}" -f ((get-date)-$MainForm.Variables.ScriptStartDate)) + " Path: " + (Split-Path $script:MyInvocation.MyCommand.Path)
		$DecayExponent = [int](((Get-Date)-$MainForm.Variables.DecayStart).TotalSeconds/$MainForm.Variables.DecayPeriod)
		#Activate or deactivate donation
		if((Get-Date).AddDays(-1).AddMinutes($MainForm.Config.Donate) -ge $MainForm.Variables.LastDonated -and ($MainForm.Config.Wallet -eq $MainForm.Variables.WalletBackup -or $MainForm.Config.UserName -eq $MainForm.Variables.UserNameBackup)){
			# Get donation addresses randomly from agreed list
			# This will fairly distribute donations to Devs
			# Devs list and wallets is publicly available at: http://bit.ly/2EqYXGr 
			try { 
				$Donation = Invoke-WebRequest "http://tiny.cc/r355qy" -UseBasicParsing -Headers @{"Cache-Control"="no-cache"} | ConvertFrom-Json
				} catch { # Fall back in case web request fails
					if ($MainForm.Config.Wallet) {$MainForm.Config.Wallet = "134bw4oTorEJUUVFhokDQDfNqTs7rBMNYy"}
					if ($MainForm.Config.UserName) {$MainForm.Config.UserName = "mrplus"}
					if ($MainForm.Config.WorkerName) {$MainForm.Config.WorkerName = "NPlusMiner-v2.0"}
				}
			if ($Donation -ne $null) {
			$MainForm.Variables.DonateRandom = $Donation | Get-Random
			if ($MainForm.Config.Wallet) {$MainForm.Config.Wallet = $MainForm.Variables.DonateRandom.Wallet}
				if ($MainForm.Config.UserName) {$MainForm.Config.UserName = $MainForm.Variables.DonateRandom.UserName}
				if ($MainForm.Config.WorkerName) {$MainForm.Config.WorkerName = "NPlusMiner-v2.0"}
			}
		}
		if((Get-Date).AddDays(-1) -ge $MainForm.Variables.LastDonated -and ($MainForm.Config.Wallet -ne $MainForm.Variables.WalletBackup -or $MainForm.Config.UserName -ne $MainForm.Variables.UserNameBackup))
		{
			$MainForm.Config.Wallet = $MainForm.Variables.WalletBackup
			$MainForm.Config.UserName = $MainForm.Variables.UserNameBackup
			$MainForm.Config.WorkerName = $MainForm.Variables.WorkerNameBackup
			$MainForm.Variables.LastDonated = Get-Date
			$Donation = $null
		}
		$Wallet = $MainForm.Config.Wallet
		$UserName = $MainForm.Config.UserName
		$WorkerName = $MainForm.Config.WorkerName
		Update-Status("Loading BTC rate from 'api.coinbase.com'..")
		$Rates = Invoke-RestMethod "https://api.coinbase.com/v2/exchange-rates?currency=BTC" -UseBasicParsing | Select-Object -ExpandProperty data | Select-Object -ExpandProperty rates
		$MainForm.Config.Currency | Where-Object {$Rates.$_} | ForEach-Object {$Rates | Add-Member $_ ([Double]$Rates.$_) -Force}
		#Load the Stats
		$Stats = [PSCustomObject]@{}
		if(Test-Path "Stats"){Get-ChildItemContent "Stats" | ForEach {$Stats | Add-Member $_.Name $_.Content}}
		#Load information about the Pools
		Update-Status("Loading pool stats..")
		$PoolFilter = @()
		$MainForm.Config.PoolName | foreach {$PoolFilter+=($_+=".*")}
		$AllPools = if(Test-Path "Pools"){Get-ChildItemContent "Pools" -Include $PoolFilter | ForEach {$_.Content | Add-Member @{Name = $_.Name} -PassThru} | 
			# Use location as preference and not the only one
			# Where Location -EQ $MainForm.Config.Location | 
			Where SSL -EQ $MainForm.Config.SSL | 
			Where {$MainForm.Config.PoolName.Count -eq 0 -or (Compare $MainForm.Config.PoolName $_.Name -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}}
		# Use location as preference and not the only one
		$AllPools = ($AllPools | ?{$_.location -eq $MainForm.Config.Location}) + ($AllPools | ?{$_.name -notin ($AllPools | ?{$_.location -eq $MainForm.Config.Location}).Name})
		#if($AllPools.Count -eq 0){Update-Status("Error contacting pool, retrying.."); sleep 15; continue}
		if($AllPools.Count -eq 0){Update-Status("Error contacting pool, retrying.."); $timerCycle.Interval = 15000 ; $timerCycle.Start() ; return}
		$Pools = [PSCustomObject]@{}
		$Pools_Comparison = [PSCustomObject]@{}
		$AllPools.Algorithm | Select -Unique | ForEach {$Pools | Add-Member $_ ($AllPools | Where Algorithm -EQ $_ | Sort Price -Descending | Select -First 1)}
		$AllPools.Algorithm | Select -Unique | ForEach {$Pools_Comparison | Add-Member $_ ($AllPools | Where Algorithm -EQ $_ | Sort StablePrice -Descending | Select -First 1)}
		#Load information about the Miners
		#Messy...?
		Update-Status("Loading miners..")
		$MainForm.Variables.Miners = if(Test-Path "Miners"){Get-ChildItemContent "Miners" | ForEach {$_.Content | Add-Member @{Name = $_.Name} -PassThru} | 
			Where {$MainForm.Config.Type.Count -eq 0 -or (Compare $MainForm.Config.Type $_.Type -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0} | 
			Where {$MainForm.Config.Algorithm.Count -eq 0 -or (Compare $MainForm.Config.Algorithm $_.HashRates.PSObject.Properties.Name -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0} | 
			Where {$MainForm.Config.MinerName.Count -eq 0 -or (Compare $MainForm.Config.MinerName $_.Name -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}}
		$MainForm.Variables.Miners = $MainForm.Variables.Miners | ForEach {
			$Miner = $_
			if((Test-Path $Miner.Path) -eq $false)
			{
				Update-Status("Downloading $($Miner.Name)..")
				if((Split-Path $Miner.URI -Leaf) -eq (Split-Path $Miner.Path -Leaf))
				{
					New-Item (Split-Path $Miner.Path) -ItemType "Directory" | Out-Null
					Invoke-WebRequest $Miner.URI -OutFile $_.Path -UseBasicParsing
				}
				elseif(([IO.FileInfo](Split-Path $_.URI -Leaf)).Extension -eq '')
				{
					$Path_Old = Get-PSDrive -PSProvider FileSystem | ForEach {Get-ChildItem -Path $_.Root -Include (Split-Path $Miner.Path -Leaf) -Recurse -ErrorAction Ignore} | Sort LastWriteTimeUtc -Descending | Select -First 1
					$Path_New = $Miner.Path

					if($Path_Old -ne $null)
					{
						if(Test-Path (Split-Path $Path_New)){(Split-Path $Path_New) | Remove-Item -Recurse -Force}
						(Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
					}
					else
					{
						Update-Status("Cannot find $($Miner.Path) distributed at $($Miner.URI). ")
					}
				}
				else
				{
					Expand-WebRequest $Miner.URI (Split-Path $Miner.Path)
				}
			}
			else
			{
				$Miner
			}
		}
		if($MainForm.Variables.Miners.Count -eq 0){Update-Status("No Miners!")}#; sleep $MainForm.Config.Interval; continue}
		$MainForm.Variables.Miners | ForEach {
			$Miner = $_
			$Miner_HashRates = [PSCustomObject]@{}
			$Miner_Pools = [PSCustomObject]@{}
			$Miner_Pools_Comparison = [PSCustomObject]@{}
			$Miner_Profits = [PSCustomObject]@{}
			$Miner_Profits_Comparison = [PSCustomObject]@{}
			$Miner_Profits_Bias = [PSCustomObject]@{}
			$Miner_Types = $Miner.Type | Select -Unique
			$Miner_Indexes = $Miner.Index | Select -Unique
			$Miner.HashRates | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
				$Miner_HashRates | Add-Member $_ ([Double]$Miner.HashRates.$_)
				$Miner_Pools | Add-Member $_ ([PSCustomObject]$Pools.$_)
				$Miner_Pools_Comparison | Add-Member $_ ([PSCustomObject]$Pools_Comparison.$_)
				$Miner_Profits | Add-Member $_ ([Double]$Miner.HashRates.$_*$Pools.$_.Price)
				$Miner_Profits_Comparison | Add-Member $_ ([Double]$Miner.HashRates.$_*$Pools_Comparison.$_.Price)
				$Miner_Profits_Bias | Add-Member $_ ([Double]$Miner.HashRates.$_*$Pools.$_.Price*(1-($MainForm.Config.MarginOfError*[Math]::Pow($MainForm.Variables.DecayBase,$DecayExponent))))
			}
			$Miner_Profit = [Double]($Miner_Profits.PSObject.Properties.Value | Measure -Sum).Sum
			$Miner_Profit_Comparison = [Double]($Miner_Profits_Comparison.PSObject.Properties.Value | Measure -Sum).Sum
			$Miner_Profit_Bias = [Double]($Miner_Profits_Bias.PSObject.Properties.Value | Measure -Sum).Sum
			$Miner.HashRates | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
				if(-not [String]$Miner.HashRates.$_)
				{
					$Miner_HashRates.$_ = $null
					$Miner_Profits.$_ = $null
					$Miner_Profits_Comparison.$_ = $null
					$Miner_Profits_Bias.$_ = $null
					$Miner_Profit = $null
					$Miner_Profit_Comparison = $null
					$Miner_Profit_Bias = $null
				}
			}
			if($Miner_Types -eq $null){$Miner_Types = $MainForm.Variables.Miners.Type | Select -Unique}
			if($Miner_Indexes -eq $null){$Miner_Indexes = $MainForm.Variables.Miners.Index | Select -Unique}
			if($Miner_Types -eq $null){$Miner_Types = ""}
			if($Miner_Indexes -eq $null){$Miner_Indexes = 0}
			$Miner.HashRates = $Miner_HashRates
			$Miner | Add-Member Pools $Miner_Pools
			$Miner | Add-Member Profits $Miner_Profits
			$Miner | Add-Member Profits_Comparison $Miner_Profits_Comparison
			$Miner | Add-Member Profits_Bias $Miner_Profits_Bias
			$Miner | Add-Member Profit $Miner_Profit
			$Miner | Add-Member Profit_Comparison $Miner_Profit_Comparison
			$Miner | Add-Member Profit_Bias $Miner_Profit_Bias
			$Miner | Add-Member Profit_Bias_Orig $Miner_Profit_Bias
			$Miner | Add-Member Type $Miner_Types -Force
			$Miner | Add-Member Index $Miner_Indexes -Force
			$Miner.Path = Convert-Path $Miner.Path
		}
		$MainForm.Variables.Miners | ForEach {
			$Miner = $_ 
			$Miner_Devices = $Miner.Device | Select -Unique
			if($Miner_Devices -eq $null){$Miner_Devices = ($MainForm.Variables.Miners | Where {(Compare $Miner.Type $_.Type -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}).Device | Select -Unique}
			if($Miner_Devices -eq $null){$Miner_Devices = $Miner.Type}
			$Miner | Add-Member Device $Miner_Devices -Force
		}
		# Remove miners when no estimation info from pools. Avoids mining when algo down at pool or benchmarking for ever
		$MainForm.Variables.Miners = $MainForm.Variables.Miners | ? {$_.Pools.PSObject.Properties.Value.Price -ne $null}

		#Don't penalize active miners. Miner could switch a little bit later and we will restore his bias in this case
		$MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" } | ForEach {$Miners | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments | ForEach {$_.Profit_Bias = $_.Profit * (1 + $MainForm.Config.ActiveMinerGainPct / 100)}}
		#Get most profitable miner combination i.e. AMD+NVIDIA+CPU
		$BestMiners = $MainForm.Variables.Miners | Select Type,Index -Unique | ForEach {$Miner_GPU = $_; ($MainForm.Variables.Miners | Where {(Compare $Miner_GPU.Type $_.Type | Measure).Count -eq 0 -and (Compare $Miner_GPU.Index $_.Index | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit_Bias -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
		$BestDeviceMiners = $MainForm.Variables.Miners | Select Device -Unique | ForEach {$Miner_GPU = $_; ($MainForm.Variables.Miners | Where {(Compare $Miner_GPU.Device $_.Device | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit_Bias -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
		$BestMiners_Comparison = $MainForm.Variables.Miners | Select Type,Index -Unique | ForEach {$Miner_GPU = $_; ($MainForm.Variables.Miners | Where {(Compare $Miner_GPU.Type $_.Type | Measure).Count -eq 0 -and (Compare $Miner_GPU.Index $_.Index | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit_Comparison -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
		$BestDeviceMiners_Comparison = $MainForm.Variables.Miners | Select Device -Unique | ForEach {$Miner_GPU = $_; ($MainForm.Variables.Miners | Where {(Compare $Miner_GPU.Device $_.Device | Measure).Count -eq 0} | Sort -Descending {($_ | Where Profit -EQ $null | Measure).Count},{($_ | Measure Profit_Comparison -Sum).Sum},{($_ | Where Profit -NE 0 | Measure).Count} | Select -First 1)}
		$Miners_Type_Combos = @([PSCustomObject]@{Combination = @()}) + (Get-Combination ($MainForm.Variables.Miners | Select Type -Unique) | Where{(Compare ($_.Combination | Select -ExpandProperty Type -Unique) ($_.Combination | Select -ExpandProperty Type) | Measure).Count -eq 0})
		$Miners_Index_Combos = @([PSCustomObject]@{Combination = @()}) + (Get-Combination ($MainForm.Variables.Miners | Select Index -Unique) | Where{(Compare ($_.Combination | Select -ExpandProperty Index -Unique) ($_.Combination | Select -ExpandProperty Index) | Measure).Count -eq 0})
		$Miners_Device_Combos = (Get-Combination ($MainForm.Variables.Miners | Select Device -Unique) | Where{(Compare ($_.Combination | Select -ExpandProperty Device -Unique) ($_.Combination | Select -ExpandProperty Device) | Measure).Count -eq 0})
		$BestMiners_Combos = $Miners_Type_Combos | ForEach {$Miner_Type_Combo = $_.Combination; $Miners_Index_Combos | ForEach {$Miner_Index_Combo = $_.Combination; [PSCustomObject]@{Combination = $Miner_Type_Combo | ForEach {$Miner_Type_Count = $_.Type.Count; [Regex]$Miner_Type_Regex = '^(' + (($_.Type | ForEach {[Regex]::Escape($_)}) -join '|') + ')$'; $Miner_Index_Combo | ForEach {$Miner_Index_Count = $_.Index.Count; [Regex]$Miner_Index_Regex = '^(' + (($_.Index | ForEach {[Regex]::Escape($_)}) -join '|') + ')$'; $BestMiners | Where {([Array]$_.Type -notmatch $Miner_Type_Regex).Count -eq 0 -and ([Array]$_.Index -notmatch $Miner_Index_Regex).Count -eq 0 -and ([Array]$_.Type -match $Miner_Type_Regex).Count -eq $Miner_Type_Count -and ([Array]$_.Index -match $Miner_Index_Regex).Count -eq $Miner_Index_Count}}}}}}
		$BestMiners_Combos += $Miners_Device_Combos | ForEach {$Miner_Device_Combo = $_.Combination; [PSCustomObject]@{Combination = $Miner_Device_Combo | ForEach {$Miner_Device_Count = $_.Device.Count; [Regex]$Miner_Device_Regex = '^(' + (($_.Device | ForEach {[Regex]::Escape($_)}) -join '|') + ')$'; $BestDeviceMiners | Where {([Array]$_.Device -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.Device -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}}}}
		$BestMiners_Combos_Comparison = $Miners_Type_Combos | ForEach {$Miner_Type_Combo = $_.Combination; $Miners_Index_Combos | ForEach {$Miner_Index_Combo = $_.Combination; [PSCustomObject]@{Combination = $Miner_Type_Combo | ForEach {$Miner_Type_Count = $_.Type.Count; [Regex]$Miner_Type_Regex = '^(' + (($_.Type | ForEach {[Regex]::Escape($_)}) -join '|') + ')$'; $Miner_Index_Combo | ForEach {$Miner_Index_Count = $_.Index.Count; [Regex]$Miner_Index_Regex = '^(' + (($_.Index | ForEach {[Regex]::Escape($_)}) -join '|') + ')$'; $BestMiners_Comparison | Where {([Array]$_.Type -notmatch $Miner_Type_Regex).Count -eq 0 -and ([Array]$_.Index -notmatch $Miner_Index_Regex).Count -eq 0 -and ([Array]$_.Type -match $Miner_Type_Regex).Count -eq $Miner_Type_Count -and ([Array]$_.Index -match $Miner_Index_Regex).Count -eq $Miner_Index_Count}}}}}}
		$BestMiners_Combos_Comparison += $Miners_Device_Combos | ForEach {$Miner_Device_Combo = $_.Combination; [PSCustomObject]@{Combination = $Miner_Device_Combo | ForEach {$Miner_Device_Count = $_.Device.Count; [Regex]$Miner_Device_Regex = '^(' + (($_.Device | ForEach {[Regex]::Escape($_)}) -join '|') + ')$'; $BestDeviceMiners_Comparison | Where {([Array]$_.Device -notmatch $Miner_Device_Regex).Count -eq 0 -and ([Array]$_.Device -match $Miner_Device_Regex).Count -eq $Miner_Device_Count}}}}
		$BestMiners_Combo = $BestMiners_Combos | Sort -Descending {($_.Combination | Where Profit -EQ $null | Measure).Count},{($_.Combination | Measure Profit_Bias -Sum).Sum},{($_.Combination | Where Profit -NE 0 | Measure).Count} | Select -First 1 | Select -ExpandProperty Combination
		$BestMiners_Combo_Comparison = $BestMiners_Combos_Comparison | Sort -Descending {($_.Combination | Where Profit -EQ $null | Measure).Count},{($_.Combination | Measure Profit_Comparison -Sum).Sum},{($_.Combination | Where Profit -NE 0 | Measure).Count} | Select -First 1 | Select -ExpandProperty Combination
		#Add the most profitable miners to the active list
		$BestMiners_Combo | ForEach {
			if(($MainForm.Variables.ActiveMinerPrograms | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments).Count -eq 0)
			{
				$MainForm.Variables.ActiveMinerPrograms += [PSCustomObject]@{
					Name = $_.Name
					Path = $_.Path
					Arguments = $_.Arguments
					Wrap = $_.Wrap
					Process = $null
					API = $_.API
					Port = $_.Port
					Algorithms = $_.HashRates.PSObject.Properties.Name
					New = $false
					Active = [TimeSpan]0
					Activated = 0
					Status = "Idle"
					HashRate = 0
					Benchmarked = 0
					Hashrate_Gathered = ($_.HashRates.PSObject.Properties.Value -ne $null)
				}
			}
		}
		#Stop or start miners in the active list depending on if they are the most profitable
		# We have to stop processes first or the port would be busy
		$MainForm.Variables.ActiveMinerPrograms | ForEach {
			[Array]$filtered = ($BestMiners_Combo | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments)
			if($filtered.Count -eq 0)
			{
				if($_.Process -eq $null)
				{
					$_.Status = "Failed"
				}
				elseif($_.Process.HasExited -eq $false)
				{
				$_.Active += (Get-Date)-$_.Process.StartTime
				   $_.Process.CloseMainWindow() | Out-Null
				   Sleep 1
				   # simply "Kill with power"
				   Stop-Process $_.Process -Force | Out-Null
				   Update-Status("closing current miner and switching")
				   Sleep 1
				   $_.Status = "Idle"
				}
				#Restore Bias for non-active miners
				$MainForm.Variables.Miners | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments | ForEach {$_.Profit_Bias = $_.Profit_Bias_Orig}
			}
		}
		$newMiner = $false
		$CurrentMinerHashrate_Gathered =$false 
		$newMiner = $false
		$CurrentMinerHashrate_Gathered =$false 
		$MainForm.Variables.ActiveMinerPrograms | ForEach {
			[Array]$filtered = ($BestMiners_Combo | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments)
			if($filtered.Count -gt 0)
			{
				if($_.Process -eq $null -or $_.Process.HasExited -ne $false)
				{
					# Log switching information to .\log\swicthing.log
					[pscustomobject]@{date=(get-date);algo=$_.Algorithms;wallet=$MainForm.Config.Wallet;username=$MainForm.Config.UserName;Stratum=($_.Arguments.Split(" ") | ?{$_ -match "stratum"})} | export-csv .\Logs\switching.log -Append -NoTypeInformation
					
					# Launch prerun if exists
					$PrerunName = ".\Prerun\"+$_.Algorithms+".bat"
					$DefaultPrerunName = ".\Prerun\default.bat"
							If (Test-Path $PrerunName) {
						Update-Status("Launching Prerun: $PrerunName")
						Start-Process $PrerunName -WorkingDirectory ".\Prerun"
						Sleep 2
					} else {
						If (Test-Path $DefaultPrerunName) {
							Write-Host -F Yellow "Launching Prerun: " $DefaultPrerunName
							Update-Status("Launching Prerun: $DefaultPrerunName")
							Start-Process $DefaultPrerunName -WorkingDirectory ".\Prerun"
							Sleep 2
							}
					}
			
					Sleep $MainForm.Config.Delay #Wait to prevent BSOD
					Update-Status("Starting miner")
					$MainForm.Variables.DecayStart = Get-Date
					$_.New = $true
					$_.Activated++
					if($_.Process -ne $null){$_.Active += $_.Process.ExitTime-$_.Process.StartTime}
					if($_.Wrap){$_.Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)'" -PassThru}
					else{$_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path)}
					if($_.Process -eq $null){$_.Status = "Failed"}
					else {
						$_.Status = "Running"
						$newMiner = $true
						#Newely started miner should looks better than other in the first run too
						$MainForm.Variables.Miners | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments | ForEach {$_.Profit_Bias = $_.Profit * (1 + $MainForm.Config.ActiveMinerGainPct / 100)}
						$newMiner = $true
						#Newely started miner should looks better than other in the first run too
						$MainForm.Variables.Miners | Where Path -EQ $_.Path | Where Arguments -EQ $_.Arguments | ForEach {$_.Profit_Bias = $_.Profit * (1 + $MainForm.Config.ActiveMinerGainPct / 100)}
					}
				}
				$CurrentMinerHashrate_Gathered = $_.Hashrate_Gathered
			}
		}
		#Display mining information
		if($host.UI.RawUI.KeyAvailable){$KeyPressed = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp");sleep -Milliseconds 300;$host.UI.RawUI.FlushInputBuffer()
		If ($KeyPressed.KeyDown){
		Switch ($KeyPressed.Character) {
				"s"	{if ($MainForm.Config.UIStyle -eq "Light"){$MainForm.Config.UIStyle="Full"}else{$MainForm.Config.UIStyle="Light"}}
				"e"	{$MainForm.Config.TrackEarnings=-not $MainForm.Config.TrackEarnings}
		}}}
		Clear-Host
		[Array] $processesIdle = $MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Idle" }
		IF ($MainForm.Config.UIStyle -eq "Full"){
			if ($processesIdle.Count -gt 0) {
				Write-Host "Idle: " $processesIdle.Count
				$processesIdle | Sort {if($_.Process -eq $null){(Get-Date)}else{$_.Process.ExitTime}} | Format-Table -Wrap (
					@{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
					@{Label = "Exited"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.ExitTime}) }},
					@{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
					@{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
					@{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
				) | Out-Host
			}
		}
		Write-Host "      1BTC = " $Rates.$Currency "$Currency"
		# Get and display earnings stats
		$MainForm.Variables.EarningsTrackerJobs | ? {$_.state -eq "Running"} | foreach {
			$EarnTrack = $_ | Receive-Job
				If ($EarnTrack) {
					$MainForm.Variables.EarningsPool = (($EarnTrack[($EarnTrack.Count - 1)]).Pool)
					# $MainForm.Variables.Earnings.$MainForm.Variables.EarningsPool = $EarnTrack[($EarnTrack.Count - 1)]
					$MainForm.Variables.Earnings.(($EarnTrack[($EarnTrack.Count - 1)]).Pool) = $EarnTrack[($EarnTrack.Count - 1)]
				}
			}
		If ($MainForm.Variables.Earnings -and $MainForm.Config.TrackEarnings) {
			# $MainForm.Variables.Earnings.Values | select Pool,Wallet,Balance,AvgDailyGrowth,EstimatedPayDate,TrustLevel | ft *
			$MainForm.Variables.Earnings.Values | foreach {
				Write-Host "+++++" $_.Wallet -B DarkBlue -F DarkGray -NoNewline; Write-Host " " $_.pool "Balance="$_.balance ("{0:P0}" -f ($_.balance/$_.PaymentThreshold))
				Write-Host "Trust Level                     " ("{0:P0}" -f $_.TrustLevel) -NoNewline; Write-Host -F darkgray " Avg based on [" ("{0:dd\ \d\a\y\s\ hh\:mm}" -f ($_.Date - $_.StartTime))"]"
				Write-Host "Average BTC/H                    BTC =" ("{0:N8}" -f $_.AvgHourlyGrowth) "| mBTC =" ("{0:N3}" -f ($_.AvgHourlyGrowth*1000))
				Write-Host "Average BTC/D" -NoNewline; Write-Host "                    BTC =" ("{0:N8}" -f ($_.AvgDailyGrowth)) "| mBTC =" ("{0:N3}" -f ($_.AvgDailyGrowth*1000)) -F Yellow
				Write-Host "Estimated Pay Date              " $_.EstimatedPayDate ">" $_.PaymentThreshold "BTC"
				# Write-Host "+++++" -F Blue
			}
		}
		Write-Host "+++++" -F Blue
		if ($MainForm.Variables.Miners | ? {$_.HashRates.PSObject.Properties.Value -eq $null}) {$MainForm.Config.UIStyle = "Full"}
		IF ($MainForm.Config.UIStyle -eq "Full"){

			$MainForm.Variables.Miners | Sort -Descending Type,Profit | Format-Table -GroupBy Type (
			@{Label = "Miner"; Expression={$_.Name}}, 
			@{Label = "Algorithm"; Expression={$_.HashRates.PSObject.Properties.Name}}, 
			@{Label = "Speed"; Expression={$_.HashRates.PSObject.Properties.Value | ForEach {if($_ -ne $null){"$($_ | ConvertTo-Hash)/s"}else{"Benchmarking"}}}; Align='right'}, 
			@{Label = "mBTC/Day"; Expression={$_.Profits.PSObject.Properties.Value*1000 | ForEach {if($_ -ne $null){$_.ToString("N3")}else{"Benchmarking"}}}; Align='right'}, 
			@{Label = "BTC/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){$_.ToString("N5")}else{"Benchmarking"}}}; Align='right'}, 
			@{Label = "$Currency/Day"; Expression={$_.Profits.PSObject.Properties.Value | ForEach {if($_ -ne $null){($_ * $Rates.$Currency).ToString("N3")}else{"Benchmarking"}}}; Align='right'}, 
			@{Label = "BTC/GH/Day"; Expression={$_.Pools.PSObject.Properties.Value.Price | ForEach {($_*1000000000).ToString("N5")}}; Align='right'},
			@{Label = "Pool"; Expression={$_.Pools.PSObject.Properties.Value | ForEach {"$($_.Name)-$($_.Info)"}}}
			) | Out-Host
				#Display active miners list
			[Array] $processRunning = $MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" }
			Write-Host "Running:"
			$processRunning | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Select -First (1) | Format-Table -Wrap (
				@{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
				@{Label = "Started"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.StartTime}) }},
				@{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
				@{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
				@{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
			) | Out-Host
			[Array] $processesFailed = $MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Failed" }
			if ($processesFailed.Count -gt 0) {
				Write-Host -ForegroundColor Red "Failed: " $processesFailed.Count
				$processesFailed | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Format-Table -Wrap (
					@{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
					@{Label = "Exited"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.ExitTime}) }},
					@{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
					@{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
					@{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
				) | Out-Host
			}
			Write-Host "--------------------------------------------------------------------------------"
		
		} else {
			[Array] $processRunning = $MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" }
			Write-Host "Running:"
			$processRunning | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Select -First (1) | Format-Table -Wrap (
				@{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
				@{Label = "Started"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.StartTime}) }},
				@{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
				@{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
				@{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
			) | Out-Host
			Write-Host "--------------------------------------------------------------------------------"
		}
		Write-Host -ForegroundColor Yellow "Last Refresh: $(Get-Date)"
		#Do nothing for a few seconds as to not overload the APIs
		if ($newMiner -eq $true) {
			if ($MainForm.Config.Interval -ge $MainForm.Config.FirstInterval -and $MainForm.Config.Interval -ge $MainForm.Config.StatsInterval) { $timeToSleep = $MainForm.Config.Interval }
			else {
				if ($CurrentMinerHashrate_Gathered -eq $true) { $timeToSleep = $MainForm.Config.FirstInterval }
				else { $timeToSleep =  $MainForm.Config.StatsInterval }
			}
		} else {
			$timeToSleep = $MainForm.Config.Interval
		}
		# IF ($MainForm.Config.UIStyle -eq "Full"){Write-Host "Sleep" ($timeToSleep) "sec"} else {Write-Host "Sleep" ($timeToSleep*2) "sec"}
		
		# Sleep $timeToSleep
		$timerCycle.Interval = $timeToSleep*1000
		Write-Host "--------------------------------------------------------------------------------"
		IF ($MainForm.Config.UIStyle -eq "Full"){
		#Display active miners list
		[Array] $processRunning = $MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Running" }
		Write-Host "Running:"
		$processRunning | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Select -First (1) | Format-Table -Wrap (
			@{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
			@{Label = "Started"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.StartTime}) }},
			@{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
			@{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
			@{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
		) | Out-Host
		[Array] $processesFailed = $MainForm.Variables.ActiveMinerPrograms | Where { $_.Status -eq "Failed" }
		if ($processesFailed.Count -gt 0) {
			Write-Host -ForegroundColor Red "Failed: " $processesFailed.Count
			$processesFailed | Sort {if($_.Process -eq $null){[DateTime]0}else{$_.Process.StartTime}} | Format-Table -Wrap (
				@{Label = "Speed"; Expression={$_.HashRate | ForEach {"$($_ | ConvertTo-Hash)/s"}}; Align='right'}, 
				@{Label = "Exited"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){(0)}else{(Get-Date) - $_.Process.ExitTime}) }},
				@{Label = "Active"; Expression={"{0:dd}:{0:hh}:{0:mm}" -f $(if($_.Process -eq $null){$_.Active}else{if($_.Process.ExitTime -gt $_.Process.StartTime){($_.Active+($_.Process.ExitTime-$_.Process.StartTime))}else{($_.Active+((Get-Date)-$_.Process.StartTime))}})}}, 
				@{Label = "Cnt"; Expression={Switch($_.Activated){0 {"Never"} 1 {"Once"} Default {"$_"}}}}, 
				@{Label = "Command"; Expression={"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
			) | Out-Host
		}
		Write-Host "--------------------------------------------------------------------------------"
		}
		#Do nothing for a few seconds as to not overload the APIs
		if ($newMiner -eq $true) {
			if ($MainForm.Config.Interval -ge $MainForm.Config.FirstInterval -and $MainForm.Config.Interval -ge $MainForm.Config.StatsInterval) { $timeToSleep = $MainForm.Config.Interval }
			else {
				if ($CurrentMinerHashrate_Gathered -eq $true) { $timeToSleep = $MainForm.Config.FirstInterval }
				else { $timeToSleep =  $MainForm.Config.StatsInterval }
			}
		} else {
		$timeToSleep = $MainForm.Config.Interval
		}
		$timerCycle.Interval = $timeToSleep*1000
		#Save current hash rates
		$MainForm.Variables.ActiveMinerPrograms | ForEach {
			if($_.Process -eq $null -or $_.Process.HasExited)
			{
				if($_.Status -eq "Running"){$_.Status = "Failed"}
			}
			else
			{
				# we don't want to store hashrates if we run less than $MainForm.Config.StatsInterval sec
				$WasActive = [math]::Round(((Get-Date)-$_.Process.StartTime).TotalSeconds)
				if ($WasActive -ge $MainForm.Config.StatsInterval) {
					$_.HashRate = 0
					$Miner_HashRates = $null
					if($_.New){$_.Benchmarked++}         
					$Miner_HashRates = Get-HashRate $_.API $_.Port ($_.New -and $_.Benchmarked -lt 3)
					$_.HashRate = $Miner_HashRates | Select -First $_.Algorithms.Count           
					if($Miner_HashRates.Count -ge $_.Algorithms.Count)
					{
						for($i = 0; $i -lt $_.Algorithms.Count; $i++)
						{
							$Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate" -Value ($Miner_HashRates | Select -Index $i)
						}
						$_.New = $false
						$_.Hashrate_Gathered = $true
						Write-Host "Stats '"$_.Algorithms"' -> "($Miner_HashRates | ConvertTo-Hash)"after"$WasActive" sec"
					}
				}
			}
			#Benchmark timeout
	#        if($_.Benchmarked -ge 6 -or ($_.Benchmarked -ge 2 -and $_.Activated -ge 2))
	#        {
	#            for($i = 0; $i -lt $_.Algorithms.Count; $i++)
	#            {
	#                if((Get-Stat "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate") -eq $null)
	#                {
	#                    $Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithms | Select -Index $i)_HashRate" -Value 0
	#                }
	#            }
	#        }
		}
	# }
	Update-Status("Sleeping $($timeToSleep)")
	$timerCycle.Start()
}
#Stop the log
# Stop-Transcript
