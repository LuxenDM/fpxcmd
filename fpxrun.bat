@echo off
setlocal

rem Set the FateLocation to the directory of the batch script
set "FateLocation=%~dp0"

rem Call the application with the updated FateLocation
fpxcmd.exe -set FateLocation "%FateLocation%" -set external_manager YES -update -scan -deploy

endlocal