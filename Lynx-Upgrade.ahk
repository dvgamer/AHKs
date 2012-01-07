;#singleinstance force
#include FcnLib.ahk
#include Lynx-FcnLib.ahk
#include Lynx-UpgradeParts.ahk
;#singleinstance force
Lynx_MaintenanceType := "upgrade"

;Beginning of the actual upgrade procedure
notify("Starting Upgrade of the LynxGuide server")
SendStartMaintenanceEmail()
TestScriptAbilities()
RunTaskManagerMinimized()

LynxOldVersion:=GetLynxVersion()
LynxDestinationVersion := GetLatestLynxVersion()
msg("Attempting an upgrade from Lynx Version: " . LynxOldVersion . " to " . LynxDestinationVersion)
PerlUpgradeNeeded:=IsPerlUpgradeNeeded()
ApacheUpgradeNeeded:=IsApacheUpgradeNeeded()

DownloadAllLynxFilesForUpgrade()

;TODO get client information and insert it into the database (if empty)
; log the info as well
CreateSmsKey()
CheckDatabaseFileSize()
GetServerSpecs()
GetClientInfo()
msg("Backup Lynx database")

notify("Start of Downtime", "Turning the LynxGuide Server off, in order to perform the upgrade")
TurnOffIisIfApplicable()
StopAllLynxServices()
EnsureAllServicesAreStopped()

UpgradePerlIfNeeded()
CopyInetpubFolder()
UpgradeApacheIfNeeded()

BannerDotPlx()

;CheckDb()
msg("Run perl checkdb.plx from C:\inetpub\wwwroot\cgi")
CheckDb()

RestartService("apache2.2")
SleepSeconds(2)
InstallAll()

notify("End of Downtime", "The LynxGuide Server should be back up, now we will begin the tests and configuration phase")
EnsureAllServicesAreRunning()

;admin login (web interface)
;TODO pull password out of DB and open lynx interface automatically
msg("Open the web interface, log in as admin")
InstallSmsKey()
msg("(Change system settings > File system locations and logging):`n`nChange logging to extensive, log age to yearly, message age to never, and log size to 500MB. Save your changes")
msg("Ask the customer if they have a public subscription page`n`nIf not: Under Home Page and Subscriber Setup, change the home page to no_subscription.htm")
msg("Under back up system, set system backups monthly and database backups weekly")

;security login (web interface)
;TODO pull password out of DB and open lynx interface automatically
msg("Send Test SMS message, popup (to server), and email (to lynx2).")
SendLogsHome()
msg("Add the four LynxGuide supervision channels: 000 Normal, 006, 007, 008, 009")
msg("Add lynx2.mitsi.com to the LynxGuide channels 000 Normal, 000 Alarm, 001, 002, 003, 009")
msg("Add 000 Normal, supervision restored for all hardware alarm groups")
msg("Add lynx2@mitsi.com to 000 Alarm, 000 Normal and 990")

;testing
;msg("Note in sugar: Tested SMS and Email to lynx2@mitsi.com, failed/passed by [initials] mm-dd-yyyy")
;msg("Note server version, last updated in sugar")
;msg("Make case in sugar for 'Server upgraded to 7.##.##.#', note specific items/concerns addressed with customer in description")

LynxNewVersion := GetLynxVersion()
ShowUpgradeSummary()
ExitApp


;TODO do all windows updates (if their server is acting funny)
;  this is a bad idea cause it will require a reboot

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; functions

;ghetto hotkey
Appskey & r::
SetTitleMatchMode, 2
WinActivate, Notepad
WinWaitActive, Notepad
Sleep, 200
Send, {ALT}fs
Sleep, 200
reload
return


msg(message)
{
   message .= "`n`nClick OK to Continue"
   MsgBox, , Lynx Upgrade Assistant, %message%
}

LynxError(message)
{
   msg("ERROR: " . message)
}

;Returns a true or false, confirming that they did or didn't complete this step
;ConfirmMsgBox(message)
;{
   ;title=Lynx Install

   ;MsgBox, 4, %title%, %message%
   ;IfMsgBox, Yes
      ;return true
   ;else
      ;return false
;}

;TODO get important info and condense into a summary
;importantLogInfo(message)
;{
;}

UnzipInstallPackage(file)
{
   ;7z=C:\temp\lynx_upgrade_files\7z.exe
   p=C:\temp\lynx_upgrade_files
   folder:=file
   ;cmd=%7z% a -t7z %p%\archive.7z %p%\*.txt
   cmd=%p%\unzip.exe %p%\%file%.zip -d %p%\%folder%
   CmdRet_RunReturn(cmd, p)
   ;notify("Working on " . file)
}

;WRITEME
DownloadLynxFile(filename)
{
   global downloadPath

   TestDownloadProtocol("ftp")
   TestDownloadProtocol("http")

   destinationFolder=C:\temp\lynx_upgrade_files
   url=%downloadPath%/%filename%
   dest=%destinationFolder%\%filename%

   FileCreateDir, %destinationFolder%
   UrlDownloadToFile, %url%, %dest%

   ;TODO perhaps we want to unzip the file now (if it is a 7z)
   if RegExMatch(filename, "^(.*)\.zip$", match)
      UnzipInstallPackage(match1)
}

TestDownloadProtocol(testProtocol)
{
   global connectionProtocol
   global downloadPath

   if connectionProtocol
      return ;we already found a protocol, so don't run the test again

   ;prepare for the test
   pass:=GetLynxPassword("generic")
   if (testProtocol == "ftp")
      downloadPath=ftp://update:%pass%@lynx.mitsi.com/upgrade_files
   else if (testProtocol == "http")
      downloadPath=http://update:%pass%@lynx.mitsi.com/Private/techsupport/upgrade_files

   ;test it
   url=%downloadPath%/test.txt
   joe:=UrlDownloadToVar(url)

   ;determine if the test was successful
   if (joe == "test message")
      connectionProtocol:=testProtocol
}

IsPerlUpgradeNeeded()
{
   if (GetPerlVersion() != "5.8.9")
      return true
   else
      return false
}

IsApacheUpgradeNeeded()
{
   if (GetApacheVersion() != "2.2.21")
      return true
   else
      return false
}

GetLatestLynxVersion()
{
   DownloadLynxFile("version.txt")
   returned := FileRead("C:\temp\lynx_upgrade_files\version.txt")
   return returned
}

EnsureApacheServiceNotExist()
{
   serviceName:="apache2.2"
   ret := CmdRet_RunReturn("sc query " . serviceName)
   if NOT InStr(ret, "service does not exist")
      msg("ERROR: An apache service exists, inform level 2 support")
}

AddSqlConnectStringFiles()
{
   ;path=C:\inetpub\
   source1=C:\inetpub\tools\sql.txt
   source2=C:\inetpub\tools\sql2.txt
   dest1=C:\inetpub\sql.txt
   dest2=C:\inetpub\sql2.txt

   if NOT FileExist(dest1)
      FileCopy(source1, dest1)
   if NOT FileExist(dest2)
      FileCopy(source2, dest2)
}

