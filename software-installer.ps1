<# 
Powershell software downloader and installer. 
Alex Ivkin 2018. MIT License.

Create an array of hashtables that contain fields like
 
{
	name='Git client'
	program='C:\Program Files\Git\bin\git.exe'
	link='git.bat'
	linkcmd='"C:\Program Files\Git\bin\git.exe" %*'
	installer='Git-2.16.2-64-bit.exe'
	installcmd='.\Git-2.16.2-64-bit.exe /verysilent ; sqlcmd -Q "update [CxDB].[dbo].[CxComponentConfiguration] set value=''C:\Program Files\Git\bin\git.exe'' where id=176"'
	url='https://github.com/git-for-windows/git/releases/download/v2.16.2.windows.1/Git-2.16.2-64-bit.exe'
	unzip='docker.1.zip'
}

Import using
. c:\vagrant\software-installer.ps1

Run using 
DownloadInstallLink $i 'c:\vagrant' 'c:\bin'

#>
$ProgressPreference = 'SilentlyContinue' # helps with the download speed for invoke-webrequest

# .NET version > 4.5 uses SSLv3 and TLS 1.0 by default. so we need to allow them
$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols

function DownloadInstallLink($i,$installfolder,$linkfolder) {
    cd $installfolder

    foreach($e in $i) {
	if ($e.containsKey('program') -and !(Test-Path $e.program)){
		if ($e.containsKey('installer') -and !(Test-Path "$installfolder\$($e.installer)") -and $e.containsKey('url')) {
			if ($e.containsKey('unzip')) {
				if (!(Test-Path "$installfolder\$($e.unzip)")) {
					try {
						Write-Output "Downloading $($e.name) to $($e.unzip)"
						Invoke-WebRequest $e.url -OutFile "$installfolder\$($e.unzip)" -UseBasicParsing
					} catch {
						Write-Host "!!! Can not download zip for $($e.name): $($_.Exception.Message)"
						exit 1
					}
				}
				try {
					Write-Output "Unzipping $($e.name)"
					Expand-Archive $e.unzip -DestinationPath $installfolder
				} catch {
					Write-Host "!!! Can not unzip $($e.name): $($_.Exception.Message)"
					if (Test-Path "$installfolder\$($e.installer)"){
						rm "$installfolder\$($e.installer)"
					}
					exit 1
				}
				rm $e.unzip
			} else {
				try {
					Write-Output "Downloading $($e.name)"
					Invoke-WebRequest $e.url -OutFile "$installfolder\$($e.installer)" -UseBasicParsing
				} catch {
					Write-Host "!!! Can not download $($e.name): $($_.Exception.Message)"
					exit 1
		       		}
			}
		}
		if ($e.containsKey('installer') -and (Test-Path "$installfolder\$($e.installer)")) {
			Write-Output "Installing $($e.name)"
			Invoke-Expression $($e.installcmd) # out-host does not work on invoke-expression. to make it synchronous, i.e. wait for it to complete
			Start-Sleep -m 500 # give some time for the process to start 
			if ($e.installcmd -match "[^\\]*\.exe") { # monitor install by the short name
				Wait-Process $Matches[0].replace(".exe","") -erroraction 'silentlycontinue'
			} else {
				$counter=20 # If no possible/no easy way to watch for an installer, just wait until the program shows up or a timeout happens
				while (!(Test-Path $e.program) -and ($counter-- -gt 0)){ 
					Start-Sleep -s 1
				}
			}
			if (!(Test-Path $e.program)){
				Write-Host ">>> $($e.name) install may have failed. "
				#exit 1
			}
		}
	} else {
		Write-Output "$($e.name) is already installed."
	}
	if ($e.ContainsKey('link') -and !(Test-Path "$linkfolder\$($e.link)")){
		Write-Output "Linking $($e.name) to $linkfolder\$($e.link)"
		New-Item -ItemType Directory -Force -Path $linkfolder | out-null
		if ($e.containsKey('linkcmd')) {
			Write-Output "@echo off`r`n$($e.linkcmd)" | out-file -encoding ascii "$linkfolder\$($e.link)" # all this extra quoting just to make commands with spaces work
		} else {
			Write-Output "@start ""$($e.name)"" ""$($e.program)"" %*" | out-file -encoding ascii "$linkfolder\$($e.link)" # all this extra quoting just to make commands with spaces work
		}
	}
    }
}
