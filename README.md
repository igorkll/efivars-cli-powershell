# efivars-cli-powershell
* CLI for efivars for windows
* scripts must be run in the console running as an administrator

## usage:
* show all EFI-variables
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_list.ps1"
```

* show all EFI-variables with values
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_list_values.ps1"
```

* demonstrates the ability to write arbitrary variables to EFI-variables
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_write.ps1" -Guid "{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}" -Name Timeout -Value "0x00,0x00"
```

* reading efivar
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_read.ps1" -Guid "{8BE4DF61-93CA-11D2-AA0D-00E098032B8C}" -Name Timeout
```

* demonstrates the ability to write EFI-variable from the script itself. it works automatically and specifically in this example sets the Timeout to 0
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_auto_write.ps1"
```

* outputs efivars as a byte array
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_list_raw.ps1"
```

* outputs efivars as a text representation of a byte array
```powershell
powershell -ExecutionPolicy Bypass -File "efivars_list_raw_text.ps1"
```

## GUIDs:
* EFI_GLOBAL_VARIABLE / EFI_SETUP_MODE / EFI_SECURE_BOOT_MODE - {8BE4DF61-93CA-11D2-AA0D-00E098032B8C} - Used for: Windows system variables like Timeout, BootOrder, BootNext, and other standard boot settings. Almost all the “Windows EFI variables" are here.
* EFI_ACPI_VARIABLE - {591209C0-B3A8-4F3F-AB89-DF54D2244F20} - For ACPI variables, which the firmware uses for power and device configuration.
* EFI_CERTIFICATE_AUTHORITY_VARIABLE - {A5C059A1-94E4-4AA7-87B5-8CDAACF4EFB3} - For Secure Boot, keys, bootloader signature, and certificates.

## EFI_VENDOR_VARIABLES
* ASUS: {BBD6D7F0-1E06-11D4-9A1C-0090273FC14D}
* Dell: {D2E0FE1B-8D5E-41D9-82B0-DF2E1C4F8D32}
* Apple: {7C436110-AB2A-4BBB-A880-FE41995C9F82}