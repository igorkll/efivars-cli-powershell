# efivars-cli-powershell
* CLI for efivars for windows

## usage:
* powershell -ExecutionPolicy Bypass -File "efivars_auto_write.ps1" - demonstrates the ability to write EFI-variable from the script itself. it works automatically and specifically in this example sets the Timeout to 0
* powershell -ExecutionPolicy Bypass -File "efivars_write.ps1" -Name Timeout -Guid "{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}" -Value "0x00,0x00" - demonstrates the ability to write arbitrary variables to EFI-variables
