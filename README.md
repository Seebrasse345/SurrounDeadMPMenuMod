# SurrounDead MP Menu (UE4SS)

This repo packages the UE4SS loader + the SurrounDeadMPMenu Lua mod and a simple installer.

## Install

Run in PowerShell (no admin needed):

```
powershell -ExecutionPolicy Bypass -File install.ps1
```

Optional: pass the game path if the auto-detect fails:

```
powershell -ExecutionPolicy Bypass -File install.ps1 -GameRoot "F:\SteamLibrary\steamapps\common\SurrounDead"
```

## Configure

Edit these files after install:

- `...\SurrounDead\Binaries\Win64\Mods\SurrounDeadMPMenu\host_map.txt`
- `...\SurrounDead\Binaries\Win64\Mods\SurrounDeadMPMenu\join_ip.txt`

## Usage

- F7 = refresh MP menu hook
- F8 = host (listen server)
- F9 = join (use another PC/instance)
- F10 = net status

## Notes

- Do NOT install the old shader PAK. It can crash with missing global shader errors.
- The installer adds console keys to `%LOCALAPPDATA%\SurrounDead\Saved\Config\Windows\Input.ini`.
