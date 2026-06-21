; ==============================================================================
; MPC_Screenshots.ahk
; ==============================================================================
;@Ahk2Exe-SetVersion 1.3.0.0
;@Ahk2Exe-SetProductVersion 1.3.0.0
;@Ahk2Exe-SetProductName MPC-HC Screenshot Helper
;@Ahk2Exe-SetDescription MPC-HC Screenshot Helper with Shutter Sound Selection
;@Ahk2Exe-SetOrigFilename MPC_Screenshots.exe
;
; TRAY MENU (right-click):
;   Play Capture Sound
;   ─────────────────────
;   ▸ From CaptureSounds Directory:   <- bold-style prefix, non-grayed
;     sound1.mp3  [✓ = selected]
;   ─────────────────────
;   ▸ From Windows Media          >   <- submenu, mouse wheel works via hook
;   ─────────────────────
;   Edit Capture Shortcuts
;   Exit

#Requires AutoHotkey v2.0
#SingleInstance Force

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
global MENU_PLAY        := "Play Capture Sound"
global MENU_HDR_CAPTURE := "  ▸  From CaptureSounds Directory:"
global MENU_WINDOWS_SUB := "  ▸  From Windows Media"
global MENU_EDIT        := "Edit Capture Shortcuts"
global MENU_EXIT        := "Exit"
global LOCATION_CAPTURE := "CaptureSoundsDir"
global LOCATION_WINDOWS := "WindowsMediaDir"
global WINDOWS_MEDIA_DIR := "C:\Windows\Media"

; ------------------------------------------------------------------------------
; Globals and defaults
; ------------------------------------------------------------------------------
global ConfigFile := A_ScriptDir . "\MPC_Screenshots_config.json"

global PlayCaptureSoundEnable := true
global SoundsDir               := A_ScriptDir . "\CaptureSounds"
global SelectedSoundName       := ""
global SelectedSoundLocation   := LOCATION_CAPTURE
global CaptureKeys             := "c,XButton1"

global CaptureSoundFiles    := []
global WindowsMediaFiles    := []
global ActiveHotkeys        := []
global WindowsSubMenu       := Menu()


; ------------------------------------------------------------------------------
; Startup
; ------------------------------------------------------------------------------
LoadConfig()
ScanSoundFiles()
RegisterHotkeys()
BuildTrayMenu()


; ------------------------------------------------------------------------------
; TakeScreenshot
; ------------------------------------------------------------------------------
TakeScreenshot(*) {
    Send "c"
    if PlayCaptureSoundEnable && SelectedSoundName {
        soundPath := GetSelectedSoundPath()
        if FileExist(soundPath)
            SoundPlay soundPath
    }
}

GetSelectedSoundPath() {
    if SelectedSoundLocation = LOCATION_WINDOWS
        return WINDOWS_MEDIA_DIR . "\" . SelectedSoundName
    return SoundsDir . "\" . SelectedSoundName
}


; ------------------------------------------------------------------------------
; BuildTrayMenu
; ------------------------------------------------------------------------------
BuildTrayMenu() {
    global WindowsSubMenu, CaptureSoundFiles, WindowsMediaFiles
    global SelectedSoundName, SelectedSoundLocation, PlayCaptureSoundEnable

    A_TrayMenu.Delete()
    WindowsSubMenu := Menu()

    ; --- Play Capture Sound toggle ---
    A_TrayMenu.Add(MENU_PLAY, TogglePlayCaptureSound)
    if PlayCaptureSoundEnable
        A_TrayMenu.Check(MENU_PLAY)

    A_TrayMenu.Add()  ; separator

    ; --- CaptureSounds section ---
    A_TrayMenu.Add(MENU_HDR_CAPTURE, (*) => 0)  ; label — no-op, not disabled

    if CaptureSoundFiles.Length = 0 {
        A_TrayMenu.Add("  (none found)", (*) => 0)
        A_TrayMenu.Disable("  (none found)")
    } else {
        for fname in CaptureSoundFiles {
            A_TrayMenu.Add(fname, SelectCaptureSoundFile)
            if fname = SelectedSoundName && SelectedSoundLocation = LOCATION_CAPTURE
                A_TrayMenu.Check(fname)
        }
    }

    A_TrayMenu.Add()  ; separator

    ; --- Windows Media submenu ---
    if WindowsMediaFiles.Length = 0 {
        WindowsSubMenu.Add("(none found)", (*) => 0)
        WindowsSubMenu.Disable("(none found)")
    } else {
        for fname in WindowsMediaFiles {
            WindowsSubMenu.Add(fname, SelectWindowsMediaFile)
            if fname = SelectedSoundName && SelectedSoundLocation = LOCATION_WINDOWS
                WindowsSubMenu.Check(fname)
        }
    }

    A_TrayMenu.Add(MENU_WINDOWS_SUB, WindowsSubMenu)
    if SelectedSoundLocation = LOCATION_WINDOWS && SelectedSoundName
        A_TrayMenu.Check(MENU_WINDOWS_SUB)

    A_TrayMenu.Add()  ; separator

    A_TrayMenu.Add(MENU_EDIT, EditCaptureShortcuts)
    A_TrayMenu.Add(MENU_EXIT, (*) => ExitApp())
}


; ------------------------------------------------------------------------------
; UncheckAllSounds
; ------------------------------------------------------------------------------
UncheckAllSounds() {
    for fname in CaptureSoundFiles
        try A_TrayMenu.Uncheck(fname)
    for fname in WindowsMediaFiles
        try WindowsSubMenu.Uncheck(fname)
    try A_TrayMenu.Uncheck(MENU_WINDOWS_SUB)
}


; ------------------------------------------------------------------------------
; TogglePlayCaptureSound
; ------------------------------------------------------------------------------
TogglePlayCaptureSound(*) {
    global PlayCaptureSoundEnable
    PlayCaptureSoundEnable := !PlayCaptureSoundEnable
    if PlayCaptureSoundEnable
        A_TrayMenu.Check(MENU_PLAY)
    else
        A_TrayMenu.Uncheck(MENU_PLAY)
    SaveConfig()
}


; ------------------------------------------------------------------------------
; SelectCaptureSoundFile
; ------------------------------------------------------------------------------
SelectCaptureSoundFile(name, *) {
    global SelectedSoundName, SelectedSoundLocation
    UncheckAllSounds()
    A_TrayMenu.Check(name)
    SelectedSoundName     := name
    SelectedSoundLocation := LOCATION_CAPTURE
    SaveConfig()
}


; ------------------------------------------------------------------------------
; SelectWindowsMediaFile
; ------------------------------------------------------------------------------
SelectWindowsMediaFile(name, *) {
    global SelectedSoundName, SelectedSoundLocation
    UncheckAllSounds()
    WindowsSubMenu.Check(name)
    A_TrayMenu.Check(MENU_WINDOWS_SUB)
    SelectedSoundName     := name
    SelectedSoundLocation := LOCATION_WINDOWS
    SaveConfig()
}


; ------------------------------------------------------------------------------
; EditCaptureShortcuts
; ------------------------------------------------------------------------------
EditCaptureShortcuts(*) {
    global CaptureKeys
    result := InputBox(
        "Enter capture keys separated by commas.`n"
        . "Example:  c,XButton1`n`n"
        . "Invalid keys will be skipped with a warning.",
        "Edit Capture Shortcuts",
        "w320 h150",
        CaptureKeys
    )
    if result.Result != "OK"
        return
    newKeys := Trim(result.Value)
    if !newKeys
        return
    CaptureKeys := newKeys
    SaveConfig()
    RegisterHotkeys()
}


; ------------------------------------------------------------------------------
; RegisterHotkeys
; ------------------------------------------------------------------------------
RegisterHotkeys() {
    global CaptureKeys, ActiveHotkeys

    HotIfWinActive("ahk_exe mpc-hc64.exe")
    for key in ActiveHotkeys
        try Hotkey(key, "Off")
    HotIf()
    ActiveHotkeys := []

    badKeys := []
    HotIfWinActive("ahk_exe mpc-hc64.exe")
    for key in StrSplit(CaptureKeys, ",") {
        key := Trim(key)
        if !key
            continue
        try {
            Hotkey(key, TakeScreenshot, "On")
            ActiveHotkeys.Push(key)
        } catch as e {
            badKeys.Push(key)
        }
    }
    HotIf()

    if badKeys.Length > 0 {
        badList := ""
        for k in badKeys
            badList .= k . ", "
        MsgBox(
            "These keys could not be registered and were skipped:`n" . RTrim(badList, ", "),
            "Invalid Keys", 0x30
        )
    }
}


; ------------------------------------------------------------------------------
; ScanSoundFiles
; ------------------------------------------------------------------------------
ScanSoundFiles() {
    global CaptureSoundFiles, WindowsMediaFiles, SoundsDir
    global SelectedSoundName, SelectedSoundLocation

    CaptureSoundFiles := []
    if DirExist(SoundsDir) {
        Loop Files, SoundsDir . "\*.mp3"
            CaptureSoundFiles.Push(A_LoopFileName)
        Loop Files, SoundsDir . "\*.wav"
            CaptureSoundFiles.Push(A_LoopFileName)
    }

    WindowsMediaFiles := []
    if DirExist(WINDOWS_MEDIA_DIR) {
        Loop Files, WINDOWS_MEDIA_DIR . "\*.wav"
            WindowsMediaFiles.Push(A_LoopFileName)
        Loop Files, WINDOWS_MEDIA_DIR . "\*.mp3"
            WindowsMediaFiles.Push(A_LoopFileName)
    }

    if SelectedSoundName {
        sourceList := (SelectedSoundLocation = LOCATION_WINDOWS)
            ? WindowsMediaFiles : CaptureSoundFiles
        found := false
        for fname in sourceList
            if fname = SelectedSoundName {
                found := true
                break
            }
        if !found
            SelectedSoundName := ""
    }

    if !SelectedSoundName {
        if CaptureSoundFiles.Length > 0 {
            SelectedSoundName     := CaptureSoundFiles[1]
            SelectedSoundLocation := LOCATION_CAPTURE
        } else if WindowsMediaFiles.Length > 0 {
            SelectedSoundName     := WindowsMediaFiles[1]
            SelectedSoundLocation := LOCATION_WINDOWS
        }
    }
}


; ------------------------------------------------------------------------------
; LoadConfig
; ------------------------------------------------------------------------------
LoadConfig() {
    global ConfigFile, PlayCaptureSoundEnable, SoundsDir
    global SelectedSoundName, SelectedSoundLocation, CaptureKeys

    if !FileExist(ConfigFile)
        return

    content := FileRead(ConfigFile, "UTF-8")

    if RegExMatch(content, '"PlayCaptureSoundEnable"\s*:\s*"([^"]+)"', &m)
        PlayCaptureSoundEnable := (m[1] = "True")

    if RegExMatch(content, '"CaptureSoundsDir"\s*:\s*"([^"]*)"', &m) && m[1] != ""
        SoundsDir := StrReplace(m[1], "\\", "\")

    if RegExMatch(content, '"SoundFile"\s*:\s*\{[^}]*"Name"\s*:\s*"([^"]*)"', &m) && m[1] != ""
        SelectedSoundName := m[1]

    if RegExMatch(content, '"SoundFile"\s*:\s*\{[^}]*"Location"\s*:\s*"([^"]*)"', &m) && m[1] != ""
        SelectedSoundLocation := m[1]

    if RegExMatch(content, '"CaptureKeys"\s*:\s*"([^"]+)"', &m)
        CaptureKeys := m[1]
}


; ------------------------------------------------------------------------------
; SaveConfig
; ------------------------------------------------------------------------------
SaveConfig() {
    global ConfigFile, PlayCaptureSoundEnable, SoundsDir
    global SelectedSoundName, SelectedSoundLocation, CaptureKeys

    defaultSoundsDir := A_ScriptDir . "\CaptureSounds"
    savedSoundsDir   := (SoundsDir = defaultSoundsDir) ? "" : SoundsDir
    jsonSoundsDir    := StrReplace(savedSoundsDir, "\", "\\")

    json := '{'
        . '`n  "PlayCaptureSoundEnable": "' . (PlayCaptureSoundEnable ? "True" : "False") . '",'
        . '`n  "CaptureSoundsDir": "' . jsonSoundsDir . '",'
        . '`n  "SoundFile": {'
        . '`n    "Name": "' . SelectedSoundName . '",'
        . '`n    "Location": "' . SelectedSoundLocation . '"'
        . '`n  },'
        . '`n  "CaptureKeys": "' . CaptureKeys . '"'
        . '`n}'

    try FileDelete(ConfigFile)
    FileAppend(json, ConfigFile, "UTF-8")
}

