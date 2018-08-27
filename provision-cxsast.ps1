$ProgressPreference = 'SilentlyContinue' # helps with download speed for invoke-webrequest

$installfolder='c:\vagrant' # for chrome bookmarks

$sa_password='admin' # MSSQL 'sa' password
$admin_password='hlTgLz69abv2jGHWAyj57N8MO3K4L8uBY93mEe0K3JE=' # 'admin' password for checkmarx 'admin@cx' user.
$admin_password_salt='nTwTPeNHlHdhcxk0IXapiQ=='

. c:\vagrant\software-installer.ps1 # get the install function

$i=@()
$i+=@{
	name='MSSQL 2017 Express Core Installer'
	program='temp\setup.exe'
	installer='SQLEXPR_x64_ENU.exe'
	installcmd='.\SQLEXPR_x64_ENU.exe /u /x:temp'
	url='https://download.microsoft.com/download/E/F/2/EF23C21D-7860-4F05-88CE-39AA114B014B'
	<# can also be installed in one go as:
 	sql_express_download_url "https://go.microsoft.com/fwlink/?linkid=829176"
 	Invoke-WebRequest -Uri $env:sql_express_download_url -OutFile sqlexpress.exe ; \
        Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /qs, /x:setup ; \
        .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS ; \
        Remove-Item -Recurse -Force sqlexpress.exe, setup
	#>
}
$i+=@{
	name='MSSQL 2017 Express Core'
	program='C:\Program Files\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQL\Binn\sqlservr.exe'
	installer='temp\setup.exe'
	# there is a backtick in front of the $ to escape it in powershell. If you copy-paste that command directly remove the backtick
	installcmd='temp\setup.exe /Q /ACTION=INSTALL /FEATURES=SQLEngine /ROLE="AllFeatures_WithDefaults" /INSTANCENAME=SQLEXPRESS /SQLCOLLATION=SQL_Latin1_General_CP1_CI_AS /SQLSVCSTARTUPTYPE=Automatic /SQLSVCACCOUNT="NT Service\MSSQL`$SQLEXPRESS" /SQLSYSADMINACCOUNTS="BUILTIN\Administrators" "NT AUTHORITY\NETWORK SERVICE" /ADDCURRENTUSERASSQLADMIN="True" /IAcceptSQLServerLicenseTerms="True" /SkipRules=RebootRequiredCheck /BROWSERSVCSTARTUPTYPE="Automatic" /UpdateEnabled="False" /TCPENABLED="1"'
}

# AS of 8.7 the installed may not finish when runnning in a non-GUI mode. If it happens you have to run it from the server itself.
$i+=@{
	name='CxSAST'
	program='C:\Program Files\Checkmarx\Checkmarx Engine Server\Engine Server\CxEngineAgent.exe'
	installer='CxSetup.exe'
	installcmd=".\CxSetup.exe /install /quiet MSSQLEXP=0" # MSSQLEXP=1 SQLAUTH=1 SQLUSER=sa SQLPWD=$sa_password SQLSERVER=localhost\SQLEXPRESS"
	linkcmd="start ""CxAudit"" ""C:\Program Files\Checkmarx\Checkmarx Audit\CxAudit.exe"""
	link="a.bat"
}

# Any applicable Hotfixes
#$i+=@{
#	name='CxSAST 8.7 HF1'
#	program='C:\Program Files\Checkmarx\Checkmarx Engine Server\Engine Server\CxEngineAgent.exe'
#	installer='8.7.0.HF1.CLI.exe'
#	installcmd=".\8.7.0.HF1.CLI.exe" 
#	url='https://download.checkmarx.com/8.7.0/HF/8.7.0.HF1.CLI.zip'
#	unzip='8.7.0.HF1.CLI.zip'
#}

. c:\vagrant\software-installer.ps1

DownloadInstallLink $i 'c:\vagrant' 'c:\bin'

# disable MSSQL telemetry
$val = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\140\" -Name "CustomerFeedback"
if($val.CustomerFeedback -ne 0) {
	Write-Host "Disabling MSSQL telemetry..."
	Set-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\140\" -Name "CustomerFeedback" -Type DWord -Value 0
	Set-ItemProperty -Path "HKLM:\Software\Microsoft\Microsoft SQL Server\140\" -Name "EnableErrorReporting" -Type DWord -Value 0
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\CPE" -Name "CustomerFeedback" -Type DWord -Value 0
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\CPE" -Name "EnableErrorReporting" -Type DWord -Value 0
	Set-ItemProperty -Path "HKLM:\Software\Wow6432Node\Microsoft\Microsoft SQL Server\140\" -Name "CustomerFeedback" -Type DWord -Value 0
	Set-ItemProperty -Path "HKLM:\Software\Wow6432Node\Microsoft\Microsoft SQL Server\140\" -Name "EnableErrorReporting" -Type DWord -Value 0
}

# Enable remote MSSQL connection for troubleshooting
if (!(Get-NetFirewallRule | where {$_.Name -eq "MSSQLExternal"})) {
	Write-Host "Enabling MSSQL remote connections..."
	# open firewall
	New-NetFirewallRule -Name "MSSQLExternal" -DisplayName "MS SQL Server allow remote connection to TCP/1433" -Protocol tcp -LocalPort 1433 -Action Allow -Enabled True | out-null
	New-NetFirewallRule -Name "MSSQLExternalBrowse" -DisplayName "MS SQL Server allow remote discovery of TCP/1433" -Protocol udp -LocalPort 1434 -Action Allow -Enabled True | out-null
	# enable remote port 1433 connection (which is not specified even though the server is installed with TCP enabled)
	Get-CimInstance -Namespace root/Microsoft/SqlServer/ComputerManagement14 -ClassName ServerNetworkProtocolProperty -Filter "InstanceName='SQLEXPRESS' and ProtocolName = 'Tcp' and IPAddressName='IPAll'" | ? { $_.PropertyName -eq 'TcpPort' } | Invoke-CimMethod -Name SetStringValue -Arguments @{ StrValue = '1433' } | out-null

	<# MS does it slightly differently:
	stop-service MSSQL`$SQLEXPRESS
        set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value '' ; \
        set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql14.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433 ; \
        #>

	# enable SQL auth
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.SQLEXPRESS\MSSQLServer" -Name "LoginMode" -Type DWord -Value 2
	Restart-Service 'MSSQL$SQLEXPRESS'
	# create sa user
	& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\SQLCMD.EXE" -Q "ALTER LOGIN sa WITH CHECK_POLICY = OFF; alter login sa with password='$sa_password' unlock; alter login sa enable;"
}


# Check for license correctness
if (!(Test-Path "license.cxl")) {
  # first generate the HID, we'll need it later
  $hidall=(& "c:\Program Files\Checkmarx\HID\HID.exe") | out-string
  Write-Host "Please provide a license.cxl file for the following HID: $hidall" -ForegroundColor red
} elseif (!(Test-Path("c:\program files\Checkmarx\Licenses\license.cxl"))) {
  # check if the provided license is correct by searching for the trimmed HID inside cxl. cxl needs to be converted from utf32 to utf8
  $hidall=(& "c:\Program Files\Checkmarx\HID\HID.exe") | out-string
  $hid=(Select-String -inputObject $hidall -Pattern "#([^_]*)").Matches.Groups[1].Value
  if (!((Get-content -Path "license.cxl") -match $hid)){
	Write-Host ">>> license.cxl does not match the HID for this container: $hidall" -ForegroundColor red
	# deploy it anyhow, as partial match would still sometimes work
  }
  Write-Host "Deploying the license..." -ForegroundColor green
  copy license.cxl "c:\program files\Checkmarx\Licenses\license.cxl"
  Restart-Service CxScanEngine
  Restart-Service CxJobsManager
  Restart-Service CxScansManager
  Restart-Service CxSystemManager
}

# set Checkmarx admin password
Write-Output "Setting admin password"
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\SQLCMD.EXE" -Q "UPDATE [CxDB].[dbo].Users SET Password = '$admin_password', SaltForPassword = '$admin_password_salt', IsAdviseChangePassword = 0 WHERE username='admin@cx'"

Write-Output "Fixing 8.7 REST API bug"
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\SQLCMD.EXE" -Q "UPDATE [CxDB].[dbo].[CxComponentConfiguration] SET Value = 'http://localhost' WHERE [Key] = 'IdentityAuthority'"

<#
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn\SQLCMD.EXE" -Q "
set IDENTITY_INSERT [CxDB].[dbo].Users on;
insert [CxDB].[dbo].Users ([Id],[UserName],[Password],[DateCreated],[BusinessUnitID],[FirstName],[LastName],[Email],[ValidationKey],[IsAdmin],[IsActive],[IsBusinessUnitAdmin],[JobTitle],[Phone],[Company],[ExpirationDate],[Country],[FullPath],[UPN],[TeamId],[is_deprecated],[CellPhone],[Skype],[Language],[IsAdviseChangePassword],[SaltForPassword],[LastLoginDate],[FailedLogins],[FailedLoginDate],[Role])
values (2,'admin@cx','$admin_password','2018-03-19',-1,'admin','admin','admin@cx.com','',0,1,0,'','','','2113-03-03',NULL,'admin','admin@cx@Cx','00000000-0000-0000-0000-000000000000',0,NULL,NULL,'1033',0,'$admin_password_salt',NULL,0,NULL,17);
set IDENTITY_INSERT [CxDB].[dbo].Users off;
"
#>

# enable confidence level
# "update [CxDB].[Config].[CxEngineConfigurationKeysMeta] set DefaultValue = 'true' WHERE (KeyName = 'CALCULATE_CONFIDENCE_LEVEL')"

# enable CL log 
#    update [CxDB].[Config].[CxEngineConfigurationKeysMeta] set DefaultValue = 'true' WHERE (KeyName = 'WRITE_CONFIDENCE_LEVEL_TO_LOG')"
# log is in AppData\Local\\Checkmarx\Checkmarx Engine Server\Engine Server\Scans\{projecHash}\ConfidenceLevelLogs