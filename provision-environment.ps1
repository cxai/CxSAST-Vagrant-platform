# various convinience settings
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$linkfolder="c:\bin"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
	Write-Host "Run this as a local admin" -foregroundcolor red
	exit 1
}

# need a reboot or logout/login after setting the path
$CurPath=[System.Environment]::GetEnvironmentVariable("PATH","User")
if (!($CurPath | Select-String -SimpleMatch $linkfolder)) {
	Write-Host "Adding $linkfolder to system user path"
	$env:Path+=";$linkfolder" # for the current session
	[Environment]::SetEnvironmentVariable("PATH","$CurPath;$linkfolder","User")
}

# Should already be disabled in the alexivkin/windows_2016 source box
# this service uses up too much cpu.  
if ((Get-Service -name "TrustedInstaller").StartType -eq "Automatic"){
	Set-Service -name "TrustedInstaller" -StartupType "Manual"
}

# cleanup desktop
if (Test-Path("C:\Users\Public\Desktop\Tad.lnk")){ 	rm "C:\Users\Public\Desktop\Tad.lnk"     }
if (Test-Path("C:\Users\Public\Desktop\VcXsrv.lnk")){ 	rm "C:\Users\Public\Desktop\VcXsrv.lnk"  }
if (Test-Path("C:\Users\Public\Desktop\XLaunch.lnk")){	rm "C:\Users\Public\Desktop\XLaunch.lnk" }

# Enable autologin
if((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon").AutoAdminLogon -eq 0) {
	Write-Host "Enabling auto logon..."
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -Type String -Value "vagrant"
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Type DWord -Value 1
}

# Disable shutdown tracker
if (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability")){ # or !(Get-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT").GetSubKeyNames().contains("Reliability")){
	Write-Host "Disabling shutdown event tracker..."
	New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" | out-null
	New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonUI" -Type DWord -Value 0 | out-null
} else {	
	$val = (Get-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability").GetValue("ShutdownReasonUI",$null)
	if(($val -eq $null) -or ($val -eq 1)) {
		Write-Host "Turning off shutdown event tracker..."
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -Name "ShutdownReasonUI" -Type DWord -Value 0
	}
} 

# App Init
# https://docs.microsoft.com/en-us/iis/configuration/system.webserver/applicationinitialization/

if ((Get-WindowsOptionalFeature -FeatureName IIS-ApplicationInit -Online).State -ne "Enabled") {
	Write-Host "Installing the IIS application initialization module"
	Enable-WindowsOptionalFeature -Online -FeatureName IIS-ApplicationInit | out-null
}

if (!(Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/applicationInitialization" -name ".").collection -or 
    !(Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/applicationInitialization" -name ".").collection.initializationPage -eq '/CxWebClient/ProjectState.aspx' ){
	Write-Host "Enabling Checkmarx application initialization"  
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='CxPool']" -name "startMode" -value "AlwaysRunning"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='CxPoolRestAPI']" -name "startMode" -value "AlwaysRunning"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/add[@name='CxClientPool']" -name "startMode" -value "AlwaysRunning"

	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/sites/site[@name='Default Web Site']/application[@path='/CxWebClient']" -name "preloadEnabled" -value "True"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/sites/site[@name='Default Web Site']/application[@path='/CxWebInterface']" -name "preloadEnabled" -value "True"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/sites/site[@name='Default Web Site']/application[@path='/CxRestAPI']" -name "preloadEnabled" -value "True"

	#echo "Checkmarx is loading, please wait..." | out-file -encoding ascii "C:\inetpub\wwwroot\checkmarxloading.htm"
	#Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/applicationInitialization" -name "remapManagedRequestsTo" -value "/checkmarxloading.htm"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/applicationInitialization" -name "skipManagedModules" -value "False"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/applicationInitialization" -name "doAppInitAfterRestart" -value "True"
	Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/applicationInitialization" -name "." -value @{initializationPage='/CxWebClient/ProjectState.aspx'}
	Restart-Service W3SVC
}

# Root Forward
# https://docs.microsoft.com/en-us/iis/extensions/url-rewrite-module/url-rewrite-module-configuration-reference

$RewriteDllPath = Join-Path $Env:SystemRoot 'System32\inetsrv\rewrite.dll'
if (! (Test-Path -Path $RewriteDllPath)){
	Write-Host "Installing URL rewrite..."
	Invoke-WebRequest http://download.microsoft.com/download/D/D/E/DDE57C26-C62C-4C59-A1BB-31D58B36ADA2/rewrite_amd64_en-US.msi -OutFile rewrite_amd64.msi -UseBasicParsing
    	Start-Process msiexec.exe -ArgumentList '/i', 'rewrite_amd64.msi', '/quiet', '/norestart' -NoNewWindow -Wait
    	Remove-Item rewrite_amd64.msi
	Restart-Service W3SVC   
}

if (!(Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule" -name ".") -or
    !(Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule" -name ".").name.contains("RedirectRootToCxWebClient") ) {
	Write-Host "Configuring default forwarder..."
	Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules" -name "." -value @{name='RedirectRootToCxWebClient';stopProcessing='True'}
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='RedirectRootToCxWebClient']/match" -name "url" -value "^$"
	#Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='RedirectRootToCheckmarx']/conditions" -name "." -value @{input='{CACHE_URL}';pattern='^(https?)://'}
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='RedirectRootToCxWebClient']/action" -name "url" -value "/CxWebClient/"
	# type could also be "RedirectToSubdir"
	Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site' -filter "system.webServer/rewrite/rules/rule[@name='RedirectRootToCxWebClient']/action" -name "type" -value "Redirect"

}
