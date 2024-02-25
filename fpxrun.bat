@echo off
setlocal

fpxcmd.exe -set external_manager YES -update -scan -deploy

endlocal