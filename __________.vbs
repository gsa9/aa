' __________.vbs
' Clinical Database Application - Main Launcher (VBScript)
' Launches db.ps1 with NO console window at all (Windows Forms only)

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get script directory
strScriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPS1Path = objFSO.BuildPath(strScriptPath, "db.ps1")

' Launch PowerShell with hidden window (0 = hidden, False = don't wait)
strCommand = """" & objShell.ExpandEnvironmentStrings("%SystemRoot%") & "\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"" -ExecutionPolicy Bypass -File """ & strPS1Path & """"

objShell.Run strCommand, 0, False

' Cleanup
Set objShell = Nothing
Set objFSO = Nothing
