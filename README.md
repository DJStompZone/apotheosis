# Apotheosis

`Apotheosis` is a PowerShell script for enumerating internal Windows shell namespace entries, with a focus on Control Panel-related GUIDs and "GodMode" tasks. It extracts information from multiple known sources of shell verbs and handlers, producing a unified list of launchable entries with optional export to JSON.

---

## Features

- Enumerates tasks exposed through **GodMode** (`shell:::{ED7BA470-8E54-465E-825C-99712043E01C}`) using COM
- Extracts CLSID entries from:
  - `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace`
  - `HKLM\SOFTWARE\Classes\Folder\shell` (context menu verbs)
  - `HKCR\CLSID\{...}\ShellFolder`
- Provides:
  - Source of each entry
  - CLSID or verb name
  - Resolved display name (if available)
  - Launchable shell command (e.g., `explorer.exe shell:::{CLSID}`)
- Optional JSON export for automation or analysis

---

## Usage

Run the script in an **elevated** PowerShell session:

```powershell
.\apotheosis.ps1
````

Optional output to file:

```powershell
.\apotheosis.ps1 -OutFile .\output.json -Force
```

### Parameters

| Parameter  | Description                                |
| ---------- | ------------------------------------------ |
| `-OutFile` | Path to save results as JSON         |
| `-Force`   | Overwrite output file if it already exists |

---

## Output Format

Each record includes:

* `Source` – One of `NameSpace`, `FolderShellVerb`, `CLSID_ShellFolder`, or `GodModeTask`
* `Key` – The CLSID or verb string
* `Name` – Display name (when available from registry or COM)
* `Command` – Launchable `explorer.exe shell:::` string

Example:

```json
{
  "Source": "NameSpace",
  "Key": "025A5937-A6BE-4686-A844-36FE4BEC8B6D",
  "Name": "Power Options",
  "Command": "explorer.exe shell:::{025A5937-A6BE-4686-A844-36FE4BEC8B6D}"
}
```

---

## Requirements

* PowerShell 5.1 or newer
* Windows 7, 10, or 11
* Administrator privileges

---

## License

MIT License
© 2025 DJ Stomp
[https://github.com/DJStompZone/apotheosis](https://github.com/DJStompZone/apotheosis)
