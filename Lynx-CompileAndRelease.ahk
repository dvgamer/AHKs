#include FcnLib.ahk

fatalIfNotThisPc("PHOSPHORUS")

date:=CurrentTime("hyphendate")
releaseDir=C:\Lynx Server Installs\%date%\

;Create Release Dir
;Copy files to release dir
Loop, C:\Dropbox\AHKs\*.*
{
   if RegExMatch(A_LoopFileName, "^Lynx-")
   {
      ;check if it compiles
      ;if NOT SuccessfullyCompiles(A_LoopFileFullPath)
         ;fatalErrord("didn't compile", A_LoopFileFullPath)

      ;move the file
      dest=%releaseDir%%A_LoopFileName%
      FileCopy(A_LoopFileFullPath, dest)
   }
}

;Compile EXEs and put them in the right places
allAhksToCompile=Lynx-Upgrade
;allAhksToCompile=Lynx-Install,Lynx-Upgrade
Loop, parse, allAhksToCompile, CSV
{
   thisNameOnly=%A_LoopField%
   thisAhk=%A_LoopField%.ahk
   terminatorPath=T:\TechSupport\%thisNameOnly%.exe

   exePath:=CompileAhk(thisAhk, "MitsiIcon")
   Sleep, 3000
   FileMove(exePath, terminatorPath, "overwrite")
}

ExitApp ;temporary cause I broke everything and have to move it into a common lib 2012-01-06

;delete this after we move all the junk to the ftp site
;exePath:=CompileAhk("C:\Dropbox\AHKs\Lynx-Install.ahk")
exePath:=CompileAhk("Lynx-Install.ahk")
FileMove(exePath, "E:\Lynx-Install.exe", "overwrite")
