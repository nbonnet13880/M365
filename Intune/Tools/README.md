# Intune Tools
The tools permit to create Intune Win32 App Package. This package is used by Intune to deploy application on Windows 10 and Windows 11 Computer

## Example

* **Example** : Intunewinapputil -c <Path> -s <SetupFile> -o <Path>

**-c** : Folder path of the folder contained all file for install application (c:\apps\Office\) 

**-s** : Setup file used for install application (setup.exe or install.bat, etc.)

**-o** : Folder path who the IntuneWinApp file is created (c:\apps\Office)