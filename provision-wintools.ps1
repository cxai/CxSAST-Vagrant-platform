# vagrant captures all stderr and terminates provisioning process if something shows up there regardless of the scrip exit code
# so we show everything on stdout, even errors, so vagrant proceeds to other provisioners even though some powershell commands may have failed here
# otherwise you might want to use [Console]::Error.WriteLine("
$ProgressPreference = 'SilentlyContinue' # helps with download speed for invoke-webrequest

$linkfolder="c:\bin"
. c:\vagrant\software-installer.ps1 # get the install function

$i=@()

# PowerPoint is no longer supported by Microsoft and may no longer be downlaodable. It may require system reboot before it is installed
# if it still fails to install - run the install manually to see the error. if the error relates to an ASP library try installing or *removing* .NET 3.5 - Get-WindowsFeature -name Net-Framework-Core
# https://answers.microsoft.com/en-us/windows/forum/all/unable-to-install-any-application-error/fb0ca806-ce16-486f-84fc-5c0d82102f5a 
$i+=@{
	# https://www.google.com/intl/en/chrome/?standalone=1&platform=win64
	name='Chrome'
	program='C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
	link='c.bat'
	installer='ChromeStandaloneSetup64.exe'
	installcmd='.\ChromeStandaloneSetup64.exe /silent /install'
	url='https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BC100A399-A153-5FBA-941A-C0C2F5B5159C%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable/chrome/install/ChromeStandaloneSetup64.exe'
	#https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BE0DB5C84-67B2-A9D1-49C3-D019504B77AB%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Ddefaultbrowser/chrome/
	#https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BA024641A-81C0-533A-53CB-AE9534821219%7D%26lang%3Den%26browser%3D4%26usagestats3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dfalse%26installdataindex%3Ddefaultbrowser/update2/installers/ChromeStandaloneSetup.exe"
}

DownloadInstallLink $i 'c:\vagrant' 'c:\bin'
