;=====================================================================
;-  Configuration & App Start
;=====================================================================

Global name.s = "Sulzer Assistant"

Declare EnsureSingleInstance()
EnsureSingleInstance() ; Bring running instance to front, do not open second instance

Declare OpenMainWindow()
Declare MainLoop()
Declare CleanUp()
Declare.s GetHostName(url.s)
Declare.s EscapeHostForFileName(url.s)
Declare GetAppIcon()
Declare ErrorHandler()
Declare IsDarkModeActive()
Declare LoadUserData()
Declare SetStaticWebviewGadgetJSSnippets()
Declare CreateTrayIcon()
Declare BuildTrayMenu()
Declare CreateSettingsWindow()

Global url.s  = "https://chat.sulzer.de"
; Change url and name with app params
If CountProgramParameters() > 0
  url  = ProgramParameter(0)
EndIf
If CountProgramParameters() > 1
  name = ProgramParameter(1)
EndIf

Structure WindowDimension
  x.l
  y.l
  w.l
  h.l
  desktop.l
  desk_w.l
  desk_h.l
EndStructure

Global host.s = GetHostName(url.s)
Global safeHost.s = EscapeHostForFileName(LCase(host))
Global appTemp.s  = GetTemporaryDirectory() + name+"\"
Global jsonPath.s = appTemp + safeHost + "-settings.json"
Global appIcon = GetAppIcon()
Global isDarkModeActiveCached = IsDarkModeActive()
Global webviewVisible = #False
Global numberDesktops = ExamineDesktops()
Global windowDimension.WindowDimension
Global trayIconID = 1
Global menuOpenID = 100
Global menuSettingsID = 101
Global menuExitID = 102
Global logginIn.b = #False
Global location.s
Global beforeLoginWindowWidth = 0
Global NewMap StaticControlThemeProcs()
Global themeBgBrush
Debug jsonPath
CreateDirectory(appTemp)

OnErrorCall(@ErrorHandler()) ; comment out if not needed 

#WINDOW_MAIN = 0
#Min_Window_Width  = 300
#Min_Window_Height = 350





Enumeration
  #WINDOW_SETTINGS = 100
  #TEXT_SHORTCUT_LABEL
  #STRING_SHORTCUT_DISPLAY
  #BTN_CAPTURE
  #BTN_OK
  #BTN_CANCEL
EndEnumeration

; Virtual Key Codes
#VK_LCONTROL = $A2
#VK_RCONTROL = $A3
#VK_LSHIFT = $A0
#VK_RSHIFT = $A1
#VK_LMENU = $A4    ; Left Alt
#VK_RMENU = $A5    ; Right Alt
#VK_LWIN = $5B
#VK_RWIN = $5C

; Capture settings
#CAPTURE_WAIT_TIME = 800  ; Wait 800ms after last key press before finalizing
#MAX_KEYS = 4             ; Maximum number of keys in combination

; Global variables for shortcut configuration
Global SettingsHook = 0
Global IsCapturing = #False
Global CapturedKeys.s = ""
Global NewList CapturedVKs()
Global LastKeyPressTime.q = 0
Global CaptureTimerRunning = #False

; Structure to store shortcut configuration
Structure ShortcutConfig
  Key1.i
  Key2.i
  Key3.i
  Key4.i
  DisplayText.s
EndStructure

Global CurrentShortcut.ShortcutConfig



SetStaticWebviewGadgetJSSnippets()
CreateSettingsWindow()

LoadUserData()
OpenMainWindow()
CreateTrayIcon()
BuildTrayMenu()

MainLoop()

CleanUp()

End  



;-======================APP PROCEDURES=====================================================================

;=====================================================================
;-  JS Script to adjust assistant for Desktop App
;=====================================================================


Procedure SetStaticWebviewGadgetJSSnippets()
  
  Global activateInputJS.s = ""+
                             ~"(() => {\n" +
                             ~"   document.querySelectorAll('div[contenteditable]').forEach(w => {\n" +
                             ~"     if (!w.closest('#chat-input')) return;\n" +
                             ~"     w.setAttribute('tabindex','-1');\n" +
                             ~"     w.focus();\n" +
                             ~"     const p = w.querySelector('.ProseMirror p:last-child');\n" +
                             ~"     if(!p) return;\n" +
                             ~"     const r = document.createRange(), s = window.getSelection();\n" +
                             ~"     r.selectNodeContents(p);\n" +
                             ~"     r.collapse(false);\n" +
                             ~"     s.removeAllRanges();\n" +
                             ~"     s.addRange(r);\n" +
                             ~"   });\n" +
                             ~"})();"
  
  Global disableAutomaticScrollJS.s =  ""+
                                       ~"(() => {\n" +
                                       ~"  //window.scrollBy = function() {};\n" +
                                       ~"  //window.scroll = function() {};\n" +
                                       ~"  //Element.prototype.scrollIntoView = function() {};\n" +
                                       ~"  const patchScroll = () => {\n" +
                                       ~"    document.querySelectorAll('*').forEach(el => {\n" +
                                       ~"      //el.scrollIntoView = function() {};\n" +
                                       ~"      if(!el.scrollToOrig){el.scrollToOrig = el.scrollTo};\n" +
                                       ~"      el.scrollTo = function(...args) {\n" +
                                       ~" if(args[0] && args[0].behavior === 'smooth') {\n" +
                                       ~"   el.scrollToOrig(...args);\n" +
                                       activateInputJS +  ~"\n" +
                                       ~" }\n" +
                                       ~"      };\n" +
                                       ~"    });\n" +
                                       ~"  };\n" +
                                       ~"  patchScroll();\n" +
                                       ~"  const observer = new MutationObserver(patchScroll);\n" +
                                       ~"  observer.observe(document.body, {childList: true, subtree: true});\n" +
                                       ~"})();"
  
  
  Global disableUnnecessaryScrollbar.s = ""+
                                         ~"(() => {\n" +
                                         ~"  var el = document.getElementById('pb-start-style');\n" +
                                         ~"  if (el) el.remove();\n" +
                                         ~"  const style = document.createElement('style');\n" +
                                         ~"  style.id = 'pb-start-style';\n" +
                                         ~"  style.textContent = `\n" +
                                         ~"    .m-auto.w-full.max-w-6xl.px-2.translate-y-6.py-24.text-center {\n" +
                                         ~"     padding-block: 0 !important;\n" +
                                         ~"  }\n" +
                                         ~"`\n" +
                                         ~"  document.head.appendChild(style);\n" +
                                         ~"})();"
  
EndProcedure

Procedure.s SetWebviewStyleJS()
  Protected bgHex.s
  If isDarkModeActiveCached
    bgHex = "#0a0a0a"   ; black background
  Else
    bgHex = "#FFFFFF"   ; white background
  EndIf
  ProcedureReturn ~"(() => {\n" +
                  ~"  var el = document.getElementById('pb-theme-style');\n" +
                  ~"  if (el) el.remove();\n" +
                  ~"  const style = document.createElement('style');\n" +
                  ~"  style.id = 'pb-theme-style';\n" +
                  ~"  style.textContent = `\n" +
                  ~"    :root {\n" +
                  ~"      --color-gray-900: rgb(10, 10, 10);\n" +
                  ~"    }\n" +
                  ~"    html, body {\n" +
                  "      background: " + bgHex + " !important;\n" +
                  "      background-color: " + bgHex + " !important;\n" +
                  ~"    }\n" +
                  ~"    .absolute.w-full.h-full.flex.z-50 {\n" +
                  ~"      background: #fff !important;\n" +
                  ~"      background-color: #fff !important;\n" +
                  ~"    }\n" +
                  ~"    /* Info text below input, reduce space */\n" +
                  ~"    .mx-auto.max-w-2xl.font-primary.mt-2 {\n" +
                  ~"      max-height: 25px !important;\n" +
                  ~"      margin-top: 0 !important;\n" +
                  ~"      margin-bottom: 70px !important;\n" +
                  ~"    }\n" +
                  ~"  `;\n" +
                  ~"  document.head.appendChild(style);\n" +
                  ~"})();"
  
  
  
EndProcedure


;=====================================================================
;-  ErrorHandler
;=====================================================================

Procedure ErrorHandler()
  ErrorMessage$ = "A program error was detected:" + Chr(13)
  ErrorMessage$ + Chr(13)
  ErrorMessage$ + "Error Message:   " + ErrorMessage()      + Chr(13)
  ErrorMessage$ + "Error Code:      " + Str(ErrorCode())    + Chr(13)
  ErrorMessage$ + "Code Address:    " + Str(ErrorAddress()) + Chr(13)
  If ErrorCode() = #PB_OnError_InvalidMemory
    ErrorMessage$ + "Target Address:  " + Str(ErrorTargetAddress()) + Chr(13)
  EndIf
  If ErrorLine() = -1
    ErrorMessage$ + "Sourcecode line: Enable OnError lines support to get code line information." + Chr(13)
  Else
    ErrorMessage$ + "Sourcecode line: " + Str(ErrorLine()) + Chr(13)
    ErrorMessage$ + "Sourcecode file: " + ErrorFile() + Chr(13)
  EndIf
  ErrorMessage$ + Chr(13)
  ErrorMessage$ + "Register content:" + Chr(13)
  CompilerSelect #PB_Compiler_Processor
    CompilerCase #PB_Processor_x86
      ErrorMessage$ + "EAX = " + Str(ErrorRegister(#PB_OnError_EAX)) + Chr(13)
      ErrorMessage$ + "EBX = " + Str(ErrorRegister(#PB_OnError_EBX)) + Chr(13)
      ErrorMessage$ + "ECX = " + Str(ErrorRegister(#PB_OnError_ECX)) + Chr(13)
      ErrorMessage$ + "EDX = " + Str(ErrorRegister(#PB_OnError_EDX)) + Chr(13)
      ErrorMessage$ + "EBP = " + Str(ErrorRegister(#PB_OnError_EBP)) + Chr(13)
      ErrorMessage$ + "ESI = " + Str(ErrorRegister(#PB_OnError_ESI)) + Chr(13)
      ErrorMessage$ + "EDI = " + Str(ErrorRegister(#PB_OnError_EDI)) + Chr(13)
      ErrorMessage$ + "ESP = " + Str(ErrorRegister(#PB_OnError_ESP)) + Chr(13)
    CompilerCase #PB_Processor_x64
      ErrorMessage$ + "RAX = " + Str(ErrorRegister(#PB_OnError_RAX)) + Chr(13)
      ErrorMessage$ + "RBX = " + Str(ErrorRegister(#PB_OnError_RBX)) + Chr(13)
      ErrorMessage$ + "RCX = " + Str(ErrorRegister(#PB_OnError_RCX)) + Chr(13)
      ErrorMessage$ + "RDX = " + Str(ErrorRegister(#PB_OnError_RDX)) + Chr(13)
      ErrorMessage$ + "RBP = " + Str(ErrorRegister(#PB_OnError_RBP)) + Chr(13)
      ErrorMessage$ + "RSI = " + Str(ErrorRegister(#PB_OnError_RSI)) + Chr(13)
      ErrorMessage$ + "RDI = " + Str(ErrorRegister(#PB_OnError_RDI)) + Chr(13)
      ErrorMessage$ + "RSP = " + Str(ErrorRegister(#PB_OnError_RSP)) + Chr(13)
      ErrorMessage$ + "Display of registers R8-R15 skipped."         + Chr(13)
  CompilerEndSelect
  Debug "ERROR:"
  Debug ErrorMessage$
EndProcedure

;=====================================================================
;-  Window Fade-In & Resize
;=====================================================================
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Procedure ShowWindowFadeInWinHandle(hWnd)
    ShowWindow_(hWnd, #SW_SHOWNA)
    UpdateWindow_(hWnd)
    RedrawWindow_(hWnd, #Null, #Null, #RDW_UPDATENOW | #RDW_ALLCHILDREN | #RDW_FRAME)
    Protected msg.MSG
    While PeekMessage_(@msg, hWnd, #WM_PAINT, #WM_PAINT, #PM_REMOVE)
      DispatchMessage_(@msg)
    Wend
    Protected hUser32 = OpenLibrary(#PB_Any, "user32.dll")
    If hUser32
      Protected *AnimateWindow = GetFunction(hUser32, "AnimateWindow")
      If *AnimateWindow
        CallFunctionFast(*AnimateWindow, hWnd, 300, $80000 | $20000)
      EndIf
      CloseLibrary(hUser32)
    EndIf
  EndProcedure
CompilerEndIf

Procedure ShowWindowFadeIn(winID)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected hWnd = WindowID(winID)
    ShowWindowFadeInWinHandle(hWnd)
  CompilerElse
    HideWindow(winID, #False)
  CompilerEndIf
EndProcedure

;=====================================================================
;-  Window Management Helpers
;=====================================================================
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  
  Procedure BringWindowToFrontWinHandle(hWnd)
    Protected foregroundHwnd = GetForegroundWindow_()
    If hWnd = foregroundHwnd
      ShowWindow_(hWnd, #SW_RESTORE)
      ProcedureReturn
    EndIf
    ; commented out lines result in flicker and are not neccessary atm
    ;ShowWindow_(hWnd, #SW_RESTORE)
    ;FlashWindow_(hWnd, #True)
    Protected foregroundThread = GetWindowThreadProcessId_(foregroundHwnd, #Null)
    Protected currentThread    = GetCurrentThreadId_()
    If AttachThreadInput_(currentThread, foregroundThread, #True)
      ShowWindow_(hWnd, #SW_RESTORE)
      ; BringWindowToTop_(hWnd)
      SetWindowPos_(hWnd, #HWND_TOPMOST, 0, 0, 0, 0, #SWP_NOMOVE | #SWP_NOSIZE )
      ;SetForegroundWindow_(hWnd)
      ;SetWindowPos_(hWnd, #HWND_NOTOPMOST, 0, 0, 0, 0, #SWP_NOMOVE | #SWP_NOSIZE)
      ;SetForegroundWindow_(hWnd)
      AttachThreadInput_(currentThread, foregroundThread, #False)
    Else
      SetWindowPos_(hWnd, #HWND_TOP, 0, 0, 0, 0, #SWP_NOMOVE | #SWP_NOSIZE)
      SetForegroundWindow_(hWnd)
    EndIf
  EndProcedure
CompilerEndIf

Procedure BringWindowToFront(window)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected hWnd = WindowID(window)
    BringWindowToFrontWinHandle(hWnd) 
  CompilerEndIf
EndProcedure 

;=====================================================================
;-  Single Instance Check
;=====================================================================

Procedure EnsureSingleInstance()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Global MutexHandle = CreateMutex_(#Null, #True, @"SulzerAssistantWebViewMutex")
    If GetLastError_() = #ERROR_ALREADY_EXISTS
      ; Another instance is running → find its window and bring it to front
      hWnd = FindWindow_(#Null, @name)
      If hWnd = 0
        ; Fallback: try by title (less reliable, but safe)
        hWnd = FindWindow_("pb_window_0", #Null)  ; PureBasic main window class
      EndIf 
      If hWnd
        ShowWindow_(hWnd, #SW_RESTORE)
        BringWindowToFrontWinHandle(hWnd)
      EndIf
      End;Exit this instance
    EndIf
  CompilerEndIf
EndProcedure 
;=====================================================================
;-  Window Dark Mode Support
;=====================================================================

Procedure IsDarkModeActive()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected key, result = 0, value.l, size = SizeOf(Long)
    If RegOpenKeyEx_(#HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", 0, #KEY_READ, @key) = #ERROR_SUCCESS
      If RegQueryValueEx_(key, "AppsUseLightTheme", 0, 0, @value, @size) = #ERROR_SUCCESS
        result = Bool(value = 0)
      EndIf
      RegCloseKey_(key)
    EndIf
    ProcedureReturn result
  CompilerElse
    ProcedureReturn #False
  CompilerEndIf 
EndProcedure


; For Windows
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  
  #DWMWA_USE_IMMERSIVE_DARK_MODE = 20
  Procedure DwmSetWindowAttributeDynamic(hwnd.i, dwAttribute.i, *pvAttribute, cbAttribute.i)
    Protected result = 0
    Protected hDll = OpenLibrary(#PB_Any, "dwmapi.dll")
    If hDll
      Protected *fn = GetFunction(hDll, "DwmSetWindowAttribute")
      If *fn
        result = CallFunctionFast(*fn, hwnd, dwAttribute, *pvAttribute, cbAttribute)
      EndIf
      CloseLibrary(hDll)
    EndIf
    ProcedureReturn result
  EndProcedure
  
  Procedure SetDarkTitleBar(hwnd.i, enable)
    Protected attrValue.i = Bool(enable)
    DwmSetWindowAttributeDynamic(hwnd, #DWMWA_USE_IMMERSIVE_DARK_MODE, @attrValue, SizeOf(Integer))
  EndProcedure
  
  
  
  Procedure SetWindowThemeDynamic(hwnd.i, subAppName.s)
    Protected hUxTheme = OpenLibrary(#PB_Any, "uxtheme.dll")
    If hUxTheme
      Protected *fn = GetFunction(hUxTheme, "SetWindowTheme")
      If *fn
        CallFunctionFast(*fn, hwnd, @subAppName, 0)
      EndIf
      CloseLibrary(hUxTheme)
    EndIf
  EndProcedure
  
  Procedure ApplyGadgetTheme(gadgetId)
    
    ; Only apply if dark mode active
    If isDarkModeActiveCached
      SetWindowThemeDynamic(gadgetId, "DarkMode_Explorer")
    Else
      SetWindowThemeDynamic(gadgetId, "Explorer")
    EndIf
    
    ; Force repaint
    SendMessage_(gadgetId, #WM_THEMECHANGED, 0, 0)
    InvalidateRect_(gadgetId, #Null, #True)
  EndProcedure
  
  
  Procedure StaticControlThemeProc(hwnd, msg, wParam, lParam)
    
    Protected oldProc = StaticControlThemeProcs(Str(hwnd))
    Protected fg, bg
    
    If isDarkModeActiveCached
      bg = RGB(10,10,10)
      fg = RGB(220, 220, 220)
    Else
      bg = RGB(255, 255, 255)
      fg = RGB(0, 0, 0)
    EndIf 
    Protected result
    Select msg
      Case #WM_SETTEXT
        ; Let Windows actually set the text first
        result = CallWindowProc_(oldProc, hwnd, msg, wParam, lParam)
        ; Now trigger repaint AFTER text changed
        InvalidateRect_(hwnd, #Null, #True)
        UpdateWindow_(hwnd) ; force immediate paint
        ProcedureReturn result
        
      Case #WM_PAINT
        Protected ps.PAINTSTRUCT
        Protected hdc = BeginPaint_(hwnd, @ps)
        Protected rect.RECT
        GetClientRect_(hwnd, @rect)
        
        ; Draw background
        Protected hBrush = CreateSolidBrush_(bg)
        FillRect_(hdc, @rect, hBrush)
        DeleteObject_(hBrush)
        
        ; Font + color
        Protected hFont = SendMessage_(hwnd, #WM_GETFONT, 0, 0)
        If hFont : SelectObject_(hdc, hFont) : EndIf
        SetBkMode_(hdc, #TRANSPARENT)
        SetTextColor_(hdc, fg)
        
        ; Get text
        Protected textLen = GetWindowTextLength_(hwnd)
        
        If textLen > 0
          Protected *text = AllocateMemory((textLen + 1) * SizeOf(Character))
          GetWindowText_(hwnd, *text, textLen + 1)
          
          ; Alignment + ellipsis setup
          Protected style = GetWindowLong_(hwnd, #GWL_STYLE)
          Protected format = #DT_VCENTER | #DT_SINGLELINE | #DT_END_ELLIPSIS | #DT_NOPREFIX | #DT_WORD_ELLIPSIS | #DT_MODIFYSTRING | #DT_LEFT
          
          If style & #SS_CENTER
            format | #DT_CENTER
          ElseIf style & #SS_RIGHT
            format | #DT_RIGHT
          EndIf
          
          ; Draw clipped text with ellipsis
          DrawText_(hdc, *text, -1, @rect, format)
          
          FreeMemory(*text)
        EndIf
        
        EndPaint_(hwnd, @ps)
        ProcedureReturn 0
        
        
        
      Case #WM_ERASEBKGND
        ProcedureReturn 1
    EndSelect
    
    ProcedureReturn CallWindowProc_(oldProc, hwnd, msg, wParam, lParam) ; sometimes stackoveflow, fix wip
  EndProcedure
  
  Global themeBackgroundColor.l
  Global themeForegroundColor.l
  
  ; Change the callback to use proper calling convention
  ProcedureC ApplyThemeToWindowChildren(hWnd, lParam)  ; Added CDLL
    Protected className.s = Space(256)
    
    Protected length = GetClassName_(hWnd, @className, 256)
    
    If length > 0
      className = LCase(PeekS(@className))
      
      Select className
          
          
        Case "button"; Applies to Button, CheckBox, Option gadgets
          
          style.l = GetWindowLong_(hWnd, #GWL_STYLE)
          
          If Not (((style & #BS_CHECKBOX) <> 0) Or ((style & #BS_AUTOCHECKBOX) <> 0)) ; Not Checkbox
            
            ApplyGadgetTheme(hWnd)
          EndIf
          ; Force repaint for checkboxes/options
          ;SendMessage_(hWnd, #WM_THEMECHANGED, 0, 0)
          InvalidateRect_(hWnd, #Null, #True)          
        Case "static"
          Protected textLength = GetWindowTextLength_(hWnd)
          If textLength = 0
            ProcedureReturn #True ; probably ImageGadget
          EndIf
          
          ; 1. Get old WndProc
          CompilerIf #PB_Compiler_Processor = #PB_Processor_x64
            Protected oldProc = GetWindowLongPtr_(hWnd, #GWLP_WNDPROC)
          CompilerElse
            Protected oldProc = GetWindowLong_(hWnd, #GWL_WNDPROC)
          CompilerEndIf
          If Not FindMapElement(StaticControlThemeProcs(),Str(hWnd))
            StaticControlThemeProcs(Str(hWnd)) = oldProc
          EndIf 
          CompilerIf #PB_Compiler_Processor = #PB_Processor_x64
            SetWindowLongPtr_(hWnd, #GWLP_WNDPROC, @StaticControlThemeProc())
          CompilerElse
            SetWindowLong_(hWnd, #GWL_WNDPROC, @StaticControlThemeProc())
          CompilerEndIf
          
      EndSelect
      
      
    EndIf
    
    InvalidateRect_(hWnd, #Null, #True)
    ProcedureReturn #True
  EndProcedure
  
  Procedure ApplyThemeToWinHandle(hWnd)
    Protected bg, fg
    If isDarkModeActiveCached
      bg = RGB(10,10,10)
      fg = RGB(220, 220, 220)
    Else
      bg = RGB(255, 255, 255)
      fg = RGB(0, 0, 0)
    EndIf 
    SetDarkTitleBar(hWnd, isDarkModeActiveCached)
    EnumChildWindows_(hWnd, @ApplyThemeToWindowChildren(), 0)
  EndProcedure
CompilerEndIf


;=====================================================================
;-  Inject JS into the webview
;=====================================================================

Procedure InjectWebViewCustomJS()
  If  Not FindString(location,"login",1,  #PB_String_NoCase) And IsGadget(0) 
    WebViewExecuteScript(0, SetWebviewStyleJS())
    WebViewExecuteScript(0, disableAutomaticScrollJS) ;Disable autoscroll (auto), allow manual scrolling (smooth)
    WebViewExecuteScript(0, disableUnnecessaryScrollbar)
  EndIf
EndProcedure

;=====================================================================
;-  Host name and safe Filename from Host
;=====================================================================

Procedure.s EscapeHostForFileName(url.s)
  Protected fullKey.s = "", schemePos, startPos, queryPos, hostPart.s, cleanHost.s
  
  schemePos = FindString(url, "://", 1)
  startPos = 1
  If schemePos > 0
    startPos = schemePos + 3
  EndIf
  
  queryPos = FindString(url, "?", startPos)
  If queryPos = 0 : queryPos = Len(url) + 1 : EndIf
  
  hostPart = Mid(url, startPos, queryPos - startPos)
  If schemePos = 0 And FindString(hostPart, ".") = 0
    hostPart = url
  EndIf
  
  cleanHost = ""
  For i = 1 To Len(hostPart)
    Protected ch.s = Mid(hostPart, i, 1)
    If ch = "."
      cleanHost + "-"
    Else
      cleanHost + LCase(ch)
    EndIf
  Next
  
  fullKey = "webwrapper-" + cleanHost
  
  If queryPos <= Len(url)
    Protected query.s = Mid(url, queryPos + 1)
    Protected p = 1, len = Len(query)
    While p <= len
      Protected eq = FindString(query, "=", p)
      If eq = 0 : Break : EndIf
      Protected key.s = Mid(query, p, eq - p)
      Protected amp = FindString(query, "&", eq)
      If amp = 0 : amp = len + 1 : EndIf
      Protected value.s = Mid(query, eq + 1, amp - eq - 1)
      
      Protected cleanKey.s = "", cleanValue.s = ""
      For i = 1 To Len(key)
        Protected c = Asc(Mid(key, i, 1))
        If (c >= 'a' And c <= 'z') Or (c >= 'A' And c <= 'Z') Or (c >= '0' And c <= '9') Or c = '-' Or c = '_'
          cleanKey + LCase(Chr(c))
        EndIf
      Next
      For i = 1 To Len(value)
        c = Asc(Mid(value, i, 1))
        If (c >= 'a' And c <= 'z') Or (c >= 'A' And c <= 'Z') Or (c >= '0' And c <= '9') Or c = '-' Or c = '_'
          cleanValue + LCase(Chr(c))
        EndIf
      Next
      
      If cleanKey <> "" And cleanValue <> ""
        fullKey + "-" + cleanKey + "-" + cleanValue
      EndIf
      
      p = amp + 1
    Wend
  EndIf
  
  If fullKey = "webwrapper-" : fullKey = "webwrapper-default" : EndIf
  ProcedureReturn fullKey
EndProcedure


Procedure.s GetHostName(url.s)
  Protected  host.s
  pos1 = FindString(url, "://", 1)
  If pos1 > 0
    pos1 + 3
    pos2 = FindString(url, "/", pos1)
    If pos2 = 0 : pos2 = Len(url) + 1 : EndIf
    host = Mid(url, pos1, pos2 - pos1)
  EndIf
  ProcedureReturn host
EndProcedure 


;=====================================================================
;-  Icon Handling (Windows only)
;=====================================================================


Procedure GetAppIcon()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected hIcon, exePath.s = ProgramFilename()
    ExtractIconEx_(exePath, 0, @hIcon, 0, 1)
    If hIcon
      ProcedureReturn hIcon
    EndIf
    ProcedureReturn LoadIcon_(0, #IDI_APPLICATION)
  CompilerElse
    ProcedureReturn 0 : 
  CompilerEndIf
EndProcedure


;=====================================================================
;-  Geometry Structure & Desktop Helpers
;=====================================================================


CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Procedure IsRectOnDesktop(x.l, y.l, w.l, h.l, deskIdx.l)
    Protected numberDesktops = ExamineDesktops()
    If deskIdx < 0 Or deskIdx >= numberDesktops
      ProcedureReturn #False
    EndIf
    Protected dx = DesktopX(deskIdx), dy = DesktopY(deskIdx)
    Protected dw = DesktopWidth(deskIdx), dh = DesktopHeight(deskIdx)
    ProcedureReturn Bool(x + w > dx And x < dx + dw And y + h > dy And y < dy + dh)
  EndProcedure
  
  Procedure FindCurrentDesktop(x.l, y.l, w.l, h.l)
    Protected numberDesktops = ExamineDesktops()
    For i = 0 To numberDesktops - 1
      If IsRectOnDesktop(x, y, w, h, i)
        ProcedureReturn i
      EndIf
    Next
    ProcedureReturn 0
  EndProcedure
CompilerElse
  Procedure IsRectOnDesktop(x.l, y.l, w.l, h.l, deskIdx.l) : ProcedureReturn #True : EndProcedure
  Procedure FindCurrentDesktop(x.l, y.l, w.l, h.l) : ProcedureReturn 0 : EndProcedure
CompilerEndIf

;=====================================================================
;-  JSON Geometry Load / Save
;=====================================================================



Procedure LoadUserDataFromJSON(path.s, *geom.WindowDimension)
  If FileSize(path) <= 0
    ProcedureReturn #False
  EndIf
  
  Protected json = LoadJSON(#PB_Any, path)
  If Not json
    ProcedureReturn #False
  EndIf
  
  Protected root = JSONValue(json)
  If Not root Or JSONType(root) <> #PB_JSON_Object
    FreeJSON(json)
    ProcedureReturn #False
  EndIf
  
  Protected member
  member = GetJSONMember(root, "x")       : If member : *geom\x = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "y")       : If member : *geom\y = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "w")       : If member : *geom\w = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "h")       : If member : *geom\h = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "desktop") : If member : *geom\desktop = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "desk_w")  : If member : *geom\desk_w = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "desk_h")  : If member : *geom\desk_h = GetJSONInteger(member) : EndIf
  
  ; Load shortcut configuration
  member = GetJSONMember(root, "shortcut_key1") : If member : CurrentShortcut\Key1 = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "shortcut_key2") : If member : CurrentShortcut\Key2 = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "shortcut_key3") : If member : CurrentShortcut\Key3 = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "shortcut_key4") : If member : CurrentShortcut\Key4 = GetJSONInteger(member) : EndIf
  member = GetJSONMember(root, "shortcut_display") : If member : CurrentShortcut\DisplayText = GetJSONString(member) : EndIf
  
  FreeJSON(json)
  ProcedureReturn #True
EndProcedure

Procedure SaveUserDataToJSON(path.s, *geom.WindowDimension)
  Protected json = CreateJSON(#PB_Any, #PB_JSON_NoCase)
  If Not json
    ProcedureReturn #False
  EndIf
  
  Protected root = SetJSONObject(JSONValue(json))
  
  SetJSONInteger(AddJSONMember(root, "x"), *geom\x)
  SetJSONInteger(AddJSONMember(root, "y"), *geom\y)
  SetJSONInteger(AddJSONMember(root, "w"), *geom\w)
  SetJSONInteger(AddJSONMember(root, "h"), *geom\h)
  SetJSONInteger(AddJSONMember(root, "desktop"), *geom\desktop)
  SetJSONInteger(AddJSONMember(root, "desk_w"), *geom\desk_w)
  SetJSONInteger(AddJSONMember(root, "desk_h"), *geom\desk_h)
    ; Save shortcut configuration
  SetJSONInteger(AddJSONMember(root, "shortcut_key1"), CurrentShortcut\Key1)
  SetJSONInteger(AddJSONMember(root, "shortcut_key2"), CurrentShortcut\Key2)
  SetJSONInteger(AddJSONMember(root, "shortcut_key3"), CurrentShortcut\Key3)
  SetJSONInteger(AddJSONMember(root, "shortcut_key4"), CurrentShortcut\Key4)
  SetJSONString(AddJSONMember(root, "shortcut_display"), CurrentShortcut\DisplayText)
  Protected result = SaveJSON(json, path, #PB_JSON_PrettyPrint)
  FreeJSON(json)
  ProcedureReturn result
EndProcedure

;=====================================================================
;-  Geometry Management
;=====================================================================

Procedure SaveUserData()
  If Not IsWindow(0) : ProcedureReturn : EndIf
  If  IsZoomed_(WindowID(0)) Or IsIconic_(WindowID(0))
    ProcedureReturn
  EndIf 
  
  Protected numberDesktops = ExamineDesktops()
  Protected saveGeom.WindowDimension
  
  saveGeom\x = DesktopScaledX(WindowX(0))
  saveGeom\y = DesktopScaledY(WindowY(0)) 
  saveGeom\w = DesktopScaledX(WindowWidth(0, #PB_Window_FrameCoordinate))
  saveGeom\h = DesktopScaledY(WindowHeight(0, #PB_Window_FrameCoordinate))
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    saveGeom\desktop = FindCurrentDesktop(saveGeom\x, saveGeom\y, saveGeom\w, saveGeom\h)
    If saveGeom\desktop >= 0 And saveGeom\desktop < numberDesktops
      saveGeom\desk_w = DesktopWidth(saveGeom\desktop)
      saveGeom\desk_h = DesktopHeight(saveGeom\desktop)
    Else
      saveGeom\desk_w = 0
      saveGeom\desk_h = 0
    EndIf
  CompilerElse
    saveGeom\desktop = 0
    saveGeom\desk_w = 0
    saveGeom\desk_h = 0
  CompilerEndIf
  
  SaveUserDataToJSON(jsonPath, @saveGeom)
EndProcedure

;=====================================================================
;-  Load & Validate Saved Geometry
;=====================================================================
Procedure LoadUserData()
  numberDesktops = ExamineDesktops()
  
  windowDimension\w = 800
  windowDimension\h = 750
  windowDimension\x = #PB_Ignore
  windowDimension\y = #PB_Ignore
  windowDimension\desktop = 0
  windowDimension\desk_w = 0
  windowDimension\desk_h = 0
  valid = #False
  
  If LoadUserDataFromJSON(jsonPath, @windowDimension)    
    If windowDimension\x <> #PB_Ignore And windowDimension\y <> #PB_Ignore And windowDimension\w >= #Min_Window_Width And windowDimension\h >= #Min_Window_Height
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
        If windowDimension\desktop >= 0 And windowDimension\desktop < numberDesktops
          If IsRectOnDesktop(windowDimension\x, windowDimension\y, windowDimension\w, windowDimension\h, windowDimension\desktop)
            valid = #True
          EndIf
        EndIf
        
        If Not valid And windowDimension\desk_w > 0 And windowDimension\desk_h > 0
          For i = 0 To numberDesktops - 1
            If DesktopWidth(i) = windowDimension\desk_w And DesktopHeight(i) = windowDimension\desk_h
              If IsRectOnDesktop(windowDimension\x, windowDimension\y, windowDimension\w, windowDimension\h, i)
                windowDimension\desktop = i
                valid = #True
                Break
              EndIf
            EndIf
          Next
        EndIf
        
        If Not valid
          For i = 0 To numberDesktops - 1
            If IsRectOnDesktop(windowDimension\x, windowDimension\y, windowDimension\w, windowDimension\h, i)
              windowDimension\desktop = i
              valid = #True
              Break
            EndIf
          Next
        EndIf
      CompilerEndIf
    EndIf
    
  EndIf
  If Not valid And numberDesktops > 0
    windowDimension\desktop = 0
    windowDimension\x = DesktopX(0) + (DesktopWidth(0) - windowDimension\w) / 2
    windowDimension\y = DesktopY(0) + (DesktopHeight(0) - windowDimension\h) / 2
  EndIf
EndProcedure

;=====================================================================
;-  System Tray (Windows only)
;=====================================================================



Procedure CreateTrayIcon()
  If IsWindow(0)
    AddSysTrayIcon(trayIconID, WindowID(0), appIcon)
    SysTrayIconToolTip(trayIconID, name)
  EndIf
EndProcedure

Procedure RemoveTrayIcon()
  RemoveSysTrayIcon(trayIconID)
EndProcedure

Procedure BuildTrayMenu()
  CreatePopupMenu(0)
  MenuItem(menuOpenID, "Open")
  MenuItem(menuSettingsID, "Settings")
  MenuBar()
  MenuItem(menuExitID, "Exit")
  SysTrayIconMenu(trayIconID, MenuID(0))   
EndProcedure


;=====================================================================
;-  Global Hotkey: Ctrl+Alt Double-Tap
;=====================================================================

Declare ShowMainWindow()
Declare HideMainWindow()

Procedure FocusInput()
  If IsGadget(0)
    SetActiveGadget(0)
    WebViewExecuteScript(0, activateInputJS)
  EndIf 
EndProcedure 


CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  #DOUBLE_TAP_DELAY = 400
  
  
  Global DoubleCtrl_LastTime.q = 0
  Global DoubleCtrl_Count = 0
  Global KeyboardHook = 0
  Global Shift_Down = #False
  
  ProcedureDLL.i KeyboardProc(nCode, wParam, lParam)
    
    Static CombinationToggle_Count = 0
    Static CombinationToggle_LastTime = 0
    Static CombinationNew_Count = 0
    Static CombinationNew_LastTime = 0
    
    Protected foregroundHwnd = GetForegroundWindow_()
    
    ; CRITICAL: Don't process hotkeys when settings window is active!
    If IsWindow(#WINDOW_SETTINGS) And Not IsIconic_(WindowID(#WINDOW_SETTINGS)) And IsWindowVisible_(WindowID(#WINDOW_SETTINGS))
      ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
    EndIf
    
    If nCode < 0
      ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
    EndIf
    
    Protected vKey = PeekL(lParam) & $FF
    Protected flags = PeekL(lParam + 8)
    Protected isDown = Bool(Not (flags & $80000000))
    Protected now = 0
    
    ; Track Shift state for Enter handling
    If vKey = #VK_LSHIFT Or vKey = #VK_RSHIFT
      Shift_Down = 1 - Shift_Down
      ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
    EndIf
    
    ;=======================================================================
    ; DYNAMIC TOGGLE SHORTCUT (from CurrentShortcut structure)
    ;=======================================================================
    
    ; Check if current key is part of the configured shortcut
    Protected isShortcutKey = #False
    If vKey = CurrentShortcut\Key1 Or vKey = CurrentShortcut\Key2 Or 
       vKey = CurrentShortcut\Key3 Or vKey = CurrentShortcut\Key4
      isShortcutKey = #True
    EndIf
    
    If isShortcutKey And isDown
      ; Check if ALL configured shortcut keys are currently pressed
      Protected allKeysPressed = #True
      
      ; Check Key1 (always required)
      If CurrentShortcut\Key1
        If Not (GetAsyncKeyState_(CurrentShortcut\Key1) & $8000)
          allKeysPressed = #False
        EndIf
      EndIf
      
      ; Check Key2 (always required)
      If CurrentShortcut\Key2
        If Not (GetAsyncKeyState_(CurrentShortcut\Key2) & $8000)
          allKeysPressed = #False
        EndIf
      EndIf
      
      ; Check Key3 (optional)
      If CurrentShortcut\Key3
        If Not (GetAsyncKeyState_(CurrentShortcut\Key3) & $8000)
          allKeysPressed = #False
        EndIf
      EndIf
      
      ; Check Key4 (optional)
      If CurrentShortcut\Key4
        If Not (GetAsyncKeyState_(CurrentShortcut\Key4) & $8000)
          allKeysPressed = #False
        EndIf
      EndIf
      
      ; If all keys are pressed, handle the toggle action
      If allKeysPressed
        now = ElapsedMilliseconds()
        
        If CombinationToggle_LastTime = 0 Or now - CombinationToggle_LastTime < #DOUBLE_TAP_DELAY
          CombinationToggle_Count + 1
          
          If CombinationToggle_Count >= 1 ; Single press to toggle
            If WindowID(0) = foregroundHwnd
              HideMainWindow()
            Else 
              ShowMainWindow()
              FocusInput()
            EndIf
            
            CombinationToggle_Count = 0
            CombinationToggle_LastTime = 0
          Else
            CombinationToggle_LastTime = now
          EndIf
        Else
          CombinationToggle_Count = 1
          CombinationToggle_LastTime = now
        EndIf
      EndIf
    Else
      ; If a non-shortcut key is pressed or shortcut key released, reset counter
      If Not isDown
        ; Check if any of the shortcut keys are still pressed
        Protected anyShortcutKeyPressed = #False
        
        If CurrentShortcut\Key1 And (GetAsyncKeyState_(CurrentShortcut\Key1) & $8000)
          anyShortcutKeyPressed = #True
        EndIf
        If CurrentShortcut\Key2 And (GetAsyncKeyState_(CurrentShortcut\Key2) & $8000)
          anyShortcutKeyPressed = #True
        EndIf
        If CurrentShortcut\Key3 And (GetAsyncKeyState_(CurrentShortcut\Key3) & $8000)
          anyShortcutKeyPressed = #True
        EndIf
        If CurrentShortcut\Key4 And (GetAsyncKeyState_(CurrentShortcut\Key4) & $8000)
          anyShortcutKeyPressed = #True
        EndIf
        
        If Not anyShortcutKeyPressed
          CombinationToggle_Count = 0
        EndIf
      EndIf
    EndIf
    
    ;=======================================================================
    ; CTRL+N for New Chat
    ;=======================================================================
    
    If vKey = #VK_LCONTROL Or vKey = #VK_N
      If isDown
        If GetAsyncKeyState_(#VK_CONTROL) & $8000 And GetAsyncKeyState_(#VK_N) & $8000
          now = ElapsedMilliseconds()
          
          If CombinationNew_LastTime = 0 Or now - CombinationNew_LastTime < #DOUBLE_TAP_DELAY
            CombinationNew_Count + 1
            
            If CombinationNew_Count >= 1
              If WindowID(0) = foregroundHwnd
                WebViewExecuteScript(0, ~"document.querySelector('button[aria-label=\"New Chat\"]').click();")
              EndIf 
              
              CombinationNew_Count = 0
              CombinationNew_LastTime = 0
            Else
              CombinationNew_LastTime = now
            EndIf
          Else
            CombinationNew_Count = 1
            CombinationNew_LastTime = now
          EndIf
        EndIf
      Else
        If Not (GetAsyncKeyState_(#VK_CONTROL) & $8000) Or Not (GetAsyncKeyState_(#VK_N) & $8000)
          CombinationNew_Count = 0
        EndIf
      EndIf
      
      ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
    EndIf
    
    ;=======================================================================
    ; ENTER to Send Message (without Shift)
    ;=======================================================================
    
    If vKey = #VK_RETURN And Not Shift_Down And isDown And 
       GetActiveWindow_() = WindowID(0) And foregroundHwnd = WindowID(0)
      
      WebViewExecuteScript(0, ~"document.getElementById('send-message-button').click();")
      keybd_event_(#VK_BACK, 0, 0, 0)
      keybd_event_(#VK_BACK, 0, #KEYEVENTF_KEYUP, 0)
    EndIf
    
    ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
  EndProcedure
  
  
CompilerEndIf

Procedure InstallKeyboardHook()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If KeyboardHook = 0
      KeyboardHook = SetWindowsHookEx_(#WH_KEYBOARD_LL, @KeyboardProc(), GetModuleHandle_(0), 0)
    EndIf
  CompilerEndIf
EndProcedure

Procedure RemoveKeyboardHook()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If KeyboardHook
      UnhookWindowsHookEx_(KeyboardHook)
      KeyboardHook = 0
    EndIf
  CompilerEndIf
EndProcedure


;=====================================================================
;-  Window Resize
;=====================================================================




Global oldW = -1
Global oldH = -1
Procedure ResizeAppWindow()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If Not (IsWindow(#WINDOW_MAIN) And IsGadget(0))
      ProcedureReturn
    EndIf
    ResizeGadget(0,0,0,WindowWidth(#WINDOW_MAIN), WindowHeight(#WINDOW_MAIN))  
  CompilerEndIf
EndProcedure


#DWMWA_BORDER_COLOR = 34 

Procedure WindowCallback(hwnd, msg, wParam, lParam)
  Protected bg.l
  If isDarkModeActiveCached
    bg = RGB(10,10,10)
  Else
    bg = RGB(255, 255, 255)
  EndIf   
  Select msg 
    Case #WM_ERASEBKGND
      Protected hdc = wParam
      Protected rect.RECT
      GetClientRect_(hwnd, @rect)
      Protected brush = CreateSolidBrush_(bg)
      FillRect_(hdc, @rect, brush)
      DeleteObject_(brush)
      ProcedureReturn #True ; handled
    Case #WM_SETTINGCHANGE
      If lParam
        themeName.s = PeekS(lParam)
        If themeName = "ImmersiveColorSet"
          isDarkModeActiveCached = IsDarkModeActive()
          ApplyThemeToWinHandle(hwnd)
          InvalidateRect_(hwnd, #Null, #True)
        EndIf
      EndIf
    Case #WM_SETFOCUS
      If hwnd = WindowID(#WINDOW_MAIN)
        FocusInput()
      EndIf 
    Case #WM_ACTIVATE
      If hwnd = WindowID(#WINDOW_MAIN)
        If (wParam & $FFFF) <> #WA_INACTIVE
          FocusInput() 
        EndIf 
      EndIf
    Case #WM_CTLCOLORSTATIC
      SetTextColor_(wParam, fg)
      SetBkMode_(wParam, #TRANSPARENT)
      parentBrush = GetClassLongPtr_(hwnd, #GCL_HBRBACKGROUND)
      If parentBrush
        ProcedureReturn parentBrush
      Else
        ProcedureReturn GetStockObject_(#NULL_BRUSH)
      EndIf
    Case #WM_CTLCOLORBTN
      SetTextColor_(wParam, fg)
      SetBkMode_(wParam, #TRANSPARENT)
      If themeBgBrush
        DeleteObject_(themeBgBrush)
      EndIf
      themeBgBrush = CreateSolidBrush_( bg )
      
      ProcedureReturn themeBgBrush
      
      
  EndSelect
  ProcedureReturn #PB_ProcessPureBasicEvents
EndProcedure

;=====================================================================
;-  WebView Ready Callback
;=====================================================================


Procedure ShowWebViewGadgetThread(gadgetID)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ; Animate fade in
    Delay(150)
    duration = 800
    Protected hWnd = GadgetID(gadgetID)
    If hWnd = 0 : ProcedureReturn : EndIf
    ; Enable layered window
    Protected style = GetWindowLong_(hWnd, #GWL_EXSTYLE)
    SetWindowLong_(hWnd, #GWL_EXSTYLE, style | #WS_EX_LAYERED)
    HideGadget(gadgetId, #False)
    SetLayeredWindowAttributes_(hWnd, 0, 0, #LWA_ALPHA)
    Protected startTime = ElapsedMilliseconds()
    Protected endTime = startTime + duration
    Repeat
      Protected now = ElapsedMilliseconds()
      Protected alpha.f = (now - startTime) / (endTime - startTime)
      If alpha > 1 : alpha = 1 : EndIf
      SetLayeredWindowAttributes_(hWnd, 0, 255 * alpha, #LWA_ALPHA)
      Delay(10)
    Until now >= endTime
    SetLayeredWindowAttributes_(hWnd, 0, 255, #LWA_ALPHA)
  CompilerElse   
    HideGadget(0, #False)
  CompilerEndIf
EndProcedure

Procedure ShowWebView()
  If Not webviewVisible
    webviewVisible = #True
    CreateThread(@ShowWebViewGadgetThread(), 0)
    FocusInput()
  EndIf 
EndProcedure


Procedure CallbackReadyState(JsonParameters$)
  ShowWebView()
  ProcedureReturn UTF8(~"")
EndProcedure

;=====================================================================
;-  Main Window Control Procedures
;=====================================================================

Procedure OpenMainWindow()
  
  OpenWindow(#WINDOW_MAIN, windowDimension\x, windowDimension\y, windowDimension\w, windowDimension\h, name,
             #PB_Window_SystemMenu | #PB_Window_MinimizeGadget |
             #PB_Window_MaximizeGadget | #PB_Window_SizeGadget | #PB_Window_Invisible)
  SetWindowCallback(@WindowCallback())
  
  StickyWindow(#WINDOW_MAIN,#True)
  
  SetWindowCallback(@WindowCallback())
  BindEvent(#PB_Event_SizeWindow, @ResizeAppWindow(), 0)
  
  InstallKeyboardHook()
  
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected hWnd = WindowID(#WINDOW_MAIN)
    ApplyThemeToWinHandle(hWnd)
    SetWindowPos_(hWnd, 0, windowDimension\x, windowDimension\y, windowDimension\w, windowDimension\h, #SWP_NOZORDER | #SWP_NOACTIVATE)
    SendMessage_(hWnd, #WM_SETICON, #ICON_SMALL, appIcon)
    SendMessage_(hWnd, #WM_SETICON, #ICON_BIG, appIcon)
  CompilerEndIf
  
  WindowBounds(#WINDOW_MAIN, #Min_Window_Width, #Min_Window_Height, #PB_Ignore, #PB_Ignore)
  
  WebViewGadget(0, -10, -10, WindowWidth(#WINDOW_MAIN)+20, WindowHeight(#WINDOW_MAIN)+20,#PB_WebView_Debug)
  SetGadgetText(0, url)
  InjectWebViewCustomJS()
  WebViewExecuteScript(0, ~"document.addEventListener('DOMContentLoaded', () => {callbackReadyState()});")
  BindWebViewCallback(0, "callbackReadyState", @CallbackReadyState())
  
  ResizeGadget(0,0,0,WindowWidth(#WINDOW_MAIN), WindowHeight(#WINDOW_MAIN))
  HideGadget(0, #True)
  
  Repeat : Delay(1) : Until WindowEvent() = 0
  ShowWindowFadeIn(#WINDOW_MAIN)
  SetActiveWindow_(WindowID(#WINDOW_MAIN))
EndProcedure

Procedure HideMainWindow()
  If  IsWindow(0) 
    SaveUserData()
    HideWindow(0, #True)
  EndIf
EndProcedure

Procedure ShowMainWindow()
  If  IsWindow(0)
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      ShowWindow_(WindowID(0), #SW_SHOWNOACTIVATE) ; #SW_SHOWNOACTIVATE to avoid flicker, BringWindowToFront -> active
    CompilerElse
      HideWindow(0,#False)
    CompilerEndIf
    SetWindowState(0, #PB_Window_Normal)
    BringWindowToFront(0)
    StickyWindow(0,#True)
    SetActiveWindow(0)
  EndIf
EndProcedure

;=====================================================================
;-  Callback to trach URL Location change and handle it
;=====================================================================

Procedure CallbackLocation(jsonParameters.s)
  Dim Parameters.s(0)
  ParseJSON(0, jsonParameters)
  ExtractJSONArray(JSONValue(0), Parameters())
  location.s = Parameters(0)
  
  ; Resize for Login and resize back
  If Not logginIn 
    If FindString(location,"login",1,  #PB_String_NoCase)
      logginIn = #True
      beforeLoginWindowWidth = WindowWidth(#WINDOW_MAIN)
      If WindowWidth(#WINDOW_MAIN)< 660
        wDifference = 660-WindowWidth(#WINDOW_MAIN)
        ResizeWindow(#WINDOW_MAIN,WindowX(#WINDOW_MAIN)-wDifference/2,#PB_Ignore,660,#PB_Ignore)
      EndIf 
    EndIf
  Else
    If Not FindString(location,"login",1,  #PB_String_NoCase)
      logginIn = #False 
      wDifference = WindowWidth(#WINDOW_MAIN)-beforeLoginWindowWidth
      ResizeWindow(#WINDOW_MAIN,WindowX(#WINDOW_MAIN)+wDifference/2,#PB_Ignore,beforeLoginWindowWidth,#PB_Ignore)
    EndIf   
  EndIf   
  ProcedureReturn UTF8(~"")
EndProcedure 



;=====================================================================
;-  Settings Window Control Procedures
;=====================================================================


Procedure.s GetKeyName(vKey)
  ; Convert virtual key code to display name
  Select vKey
    Case #VK_LCONTROL, #VK_RCONTROL
      ProcedureReturn "Ctrl"
    Case #VK_LSHIFT, #VK_RSHIFT
      ProcedureReturn "Shift"
    Case #VK_LMENU, #VK_RMENU
      ProcedureReturn "Alt"
    Case #VK_LWIN, #VK_RWIN
      ProcedureReturn "Win"
    Case $41 To $5A ; A-Z
      ProcedureReturn Chr(vKey)
    Case $30 To $39 ; 0-9
      ProcedureReturn Chr(vKey)
    Case $70 To $87 ; F1-F24
      ProcedureReturn "F" + Str(vKey - $6F)
    Case $20
      ProcedureReturn "Space"
    Case $09
      ProcedureReturn "Tab"
    Case $08
      ProcedureReturn "Backspace"
    Case $2E
      ProcedureReturn "Delete"
    Case $24
      ProcedureReturn "Home"
    Case $23
      ProcedureReturn "End"
    Case $21
      ProcedureReturn "PageUp"
    Case $22
      ProcedureReturn "PageDown"
    Case $25
      ProcedureReturn "Left"
    Case $26
      ProcedureReturn "Up"
    Case $27
      ProcedureReturn "Right"
    Case $28
      ProcedureReturn "Down"
    Default
      ProcedureReturn "Key" + Str(vKey)
  EndSelect
EndProcedure

Procedure.i IsModifierKey(vKey)
  ; Check if the key is a modifier
  Select vKey
    Case #VK_LCONTROL, #VK_RCONTROL, #VK_LSHIFT, #VK_RSHIFT, 
         #VK_LMENU, #VK_RMENU, #VK_LWIN, #VK_RWIN
      ProcedureReturn #True
    Default
      ProcedureReturn #False
  EndSelect
EndProcedure

Procedure UpdateCapturedKeysDisplay()
  ; Build display string from captured keys
  CapturedKeys = ""
  Protected first = #True
  
  ; Sort modifiers first for consistent display
  Protected NewList SortedKeys()
  Protected NewList ModifierKeys()
  Protected NewList RegularKeys()
  
  ForEach CapturedVKs()
    If IsModifierKey(CapturedVKs())
      AddElement(ModifierKeys())
      ModifierKeys() = CapturedVKs()
    Else
      AddElement(RegularKeys())
      RegularKeys() = CapturedVKs()
    EndIf
  Next
  
  ; Add modifiers first
  ForEach ModifierKeys()
    If Not first
      CapturedKeys + "+"
    EndIf
    CapturedKeys + GetKeyName(ModifierKeys())
    first = #False
  Next
  
  ; Then regular keys
  ForEach RegularKeys()
    If Not first
      CapturedKeys + "+"
    EndIf
    CapturedKeys + GetKeyName(RegularKeys())
    first = #False
  Next
  
  SetGadgetText(#STRING_SHORTCUT_DISPLAY, CapturedKeys)
EndProcedure

Procedure FinalizeCapture()
  ; Stop capturing
  IsCapturing = #False
  CaptureTimerRunning = #False
  SetGadgetText(#BTN_CAPTURE, "Change")
  
  If SettingsHook
    UnhookWindowsHookEx_(SettingsHook)
    SettingsHook = 0
  EndIf
  
  ; Validate the combination (at least 2 keys)
  If ListSize(CapturedVKs()) < 2
    CapturedKeys = "Invalid - at least 2 keys"
    ClearList(CapturedVKs())
    SetGadgetText(#STRING_SHORTCUT_DISPLAY, CapturedKeys)
  EndIf
  
  ; Remove focus from the input field so it can be clicked again
  SetActiveGadget(#BTN_OK)
EndProcedure

ProcedureDLL.i SettingsKeyboardProc(nCode, wParam, lParam)
  If nCode < 0
    ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
  EndIf
  
  Protected vKey = PeekL(lParam) & $FF
  Protected flags = PeekL(lParam + 8)
  Protected isDown = Bool(Not (flags & $80000000))
  
  If IsCapturing
    If isDown
      ; Key pressed down
      ; Check if we haven't exceeded max keys
      If ListSize(CapturedVKs()) >= #MAX_KEYS
        ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
      EndIf
      
      ; Add to captured keys list if not already there
      Protected found = #False
      ForEach CapturedVKs()
        If CapturedVKs() = vKey
          found = #True
          Break
        EndIf
      Next
      
      If Not found
        AddElement(CapturedVKs())
        CapturedVKs() = vKey
      EndIf
      
      ; Update display
      UpdateCapturedKeysDisplay()
      
      ; Reset the timer - we're waiting for more keys
      LastKeyPressTime = ElapsedMilliseconds()
      CaptureTimerRunning = #True
      
    EndIf
  EndIf
  
  ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
EndProcedure

Procedure CheckCaptureTimeout()
  ; Check if we should finalize the capture
  If IsCapturing And CaptureTimerRunning
    Protected now = ElapsedMilliseconds()
    If now - LastKeyPressTime >= #CAPTURE_WAIT_TIME
      ; Timeout reached - finalize capture
      FinalizeCapture()
    EndIf
  EndIf
EndProcedure

Procedure StartCapture()
  IsCapturing = #True
  CapturedKeys = "Press keys..."
  ClearList(CapturedVKs())
  LastKeyPressTime = 0
  CaptureTimerRunning = #False
  
  SetGadgetText(#STRING_SHORTCUT_DISPLAY, CapturedKeys)
  SetGadgetText(#BTN_CAPTURE, "Listening...")
  
  ; Install keyboard hook
  If Not SettingsHook
    SettingsHook = SetWindowsHookEx_(#WH_KEYBOARD_LL, @SettingsKeyboardProc(), 
                                     GetModuleHandle_(0), 0)
  EndIf
EndProcedure

Procedure StopCapture()
  IsCapturing = #False
  CaptureTimerRunning = #False
  SetGadgetText(#BTN_CAPTURE, "Change")
  
  If SettingsHook
    UnhookWindowsHookEx_(SettingsHook)
    SettingsHook = 0
  EndIf
  
  ; Remove focus from the input field so it can be clicked again
  SetActiveGadget(#BTN_OK)
EndProcedure

Procedure SaveShortcut()
  ; Save the captured keys to CurrentShortcut structure
  CurrentShortcut\Key1 = 0
  CurrentShortcut\Key2 = 0
  CurrentShortcut\Key3 = 0
  CurrentShortcut\Key4 = 0
  
  ; Store up to 4 keys
  Protected count = 0
  ForEach CapturedVKs()
    count + 1
    Select count
      Case 1: CurrentShortcut\Key1 = CapturedVKs()
      Case 2: CurrentShortcut\Key2 = CapturedVKs()
      Case 3: CurrentShortcut\Key3 = CapturedVKs()
      Case 4: CurrentShortcut\Key4 = CapturedVKs()
    EndSelect
  Next
  
  CurrentShortcut\DisplayText = CapturedKeys
EndProcedure

Procedure.i ValidateShortcut()
  ; Check if we have a valid shortcut (at least 2 keys)
  If ListSize(CapturedVKs()) >= 2
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure CreateSettingsWindow()
  ; Initialize default shortcut (Ctrl+Win)
  If CurrentShortcut\DisplayText = ""
    CurrentShortcut\Key1 = #VK_LCONTROL
    CurrentShortcut\Key2 = #VK_SPACE
    CurrentShortcut\DisplayText = "Ctrl+Space"
  EndIf
  
  If OpenWindow(#WINDOW_SETTINGS, 0, 0, 400, 135, "Settings", 
                #PB_Window_SystemMenu | #PB_Window_ScreenCentered| #PB_Window_Invisible)
    
    StickyWindow(#WINDOW_SETTINGS,#True)
    
    
    SendMessage_(hWnd, #WM_SETICON, #ICON_SMALL, appIcon)
    SendMessage_(hWnd, #WM_SETICON, #ICON_BIG, appIcon)
    ; Keyboard shortcut label
    TextGadget(#TEXT_SHORTCUT_LABEL, 20, 16, 120, 25, "Keyboard shortcut:")
    
    ; Display current shortcut - Remove #PB_String_ReadOnly to allow clicking
    StringGadget(#STRING_SHORTCUT_DISPLAY, 150, 17, 150, 25, 
                 CurrentShortcut\DisplayText)

    ; Capture button
    ButtonGadget(#BTN_CAPTURE, 310, 17, 70, 25, "Change")
    
    ; OK button
    ButtonGadget(#BTN_OK, 210, 85, 80, 30, "OK")
    
    ; Cancel button
    ButtonGadget(#BTN_CANCEL, 300, 85, 80, 30, "Cancel")
    
    ; Add timer to check for capture timeout
    
    
    ApplyThemeToWinHandle(WindowID(#WINDOW_SETTINGS))
    
    
  EndIf
EndProcedure


;=====================================================================
;-  Main Loop
;=====================================================================

Procedure HideCaretHandler()
  Static lastFocus = #False
  If GetFocus_() = GadgetID(#STRING_SHORTCUT_DISPLAY)
    If Not lastFocus
      HideCaret_(GadgetID(#STRING_SHORTCUT_DISPLAY))
      lastFocus = #True
    EndIf
  Else
    lastFocus = #False
  EndIf
EndProcedure



Procedure MainLoop()
  
  startTime = ElapsedMilliseconds()
  executeScriptTime = ElapsedMilliseconds()
  SetWindowTitle(#WINDOW_MAIN,name+" - "+CurrentShortcut\DisplayText)
  resetTitle = #False 
  Repeat
    
    If Not webviewVisible And ElapsedMilliseconds() - startTime > 1500
      webviewVisible = #True
      HideGadget(0, #False) 
    EndIf 

    
    If Not resetTitle And ElapsedMilliseconds() - startTime > 60000
      resetTitle = #True
      SetWindowTitle(#WINDOW_MAIN,name)
    EndIf 
    
    ; Don't inject JS or do webview operations when settings window is open!
    Protected settingsVisible = #False
    CompilerIf #PB_Compiler_OS = #PB_OS_Windows
      If IsWindow(#WINDOW_SETTINGS)
        settingsVisible = Bool(IsWindowVisible_(WindowID(#WINDOW_SETTINGS)))
      EndIf
    CompilerEndIf
    
    If Not settingsVisible And ElapsedMilliseconds() - executeScriptTime > 2000
      executeScriptTime = ElapsedMilliseconds() 
      InjectWebViewCustomJS()
      BindWebViewCallback(0, "callbackLocation", @CallbackLocation())      
      WebViewExecuteScript(0, ~"callbackLocation(document.location.href);")
    EndIf 
    
    windowEvent = WaitWindowEvent(10) ; Add timeout so it doesn't block
    currentWindow = EventWindow()
        
    Select currentWindow
      Case #WINDOW_MAIN
        Select windowEvent
          Case #PB_Event_SysTray
            ShowMainWindow()
            
          Case #PB_Event_Menu
            Select EventMenu()
              Case menuOpenID
                ShowMainWindow()
                
              Case menuSettingsID
                ; First hide main window
                HideMainWindow()
                
                ; CRITICAL: Temporarily unhook keyboard to prevent focus stealing!
                RemoveKeyboardHook()
                
                ; Stop any capturing
                If IsCapturing
                  StopCapture()
                EndIf
                
                ; Reset display to current shortcut
                If IsGadget(#STRING_SHORTCUT_DISPLAY)
                  SetGadgetText(#STRING_SHORTCUT_DISPLAY, CurrentShortcut\DisplayText)
                EndIf
                
                ; Show settings window
                CompilerIf #PB_Compiler_OS = #PB_OS_Windows
                  Protected settingsHwnd = WindowID(#WINDOW_SETTINGS)
                  
                  ShowWindow_(settingsHwnd, #SW_RESTORE)
                  UpdateWindow_(settingsHwnd)
                  SetForegroundWindow_(settingsHwnd)
                  BringWindowToTop_(settingsHwnd)
                  SetFocus_(settingsHwnd)
                CompilerElse
                  HideWindow(#WINDOW_SETTINGS, #False)
                CompilerEndIf
                
                ; Start timer AFTER showing
                AddWindowTimer(#WINDOW_SETTINGS, 1, 50)
                
              Case menuExitID
                SaveUserData()
                RemoveTrayIcon()
                End
            EndSelect
            
          Case #PB_Event_SizeWindow, #PB_Event_MoveWindow
            If IsWindow(#WINDOW_MAIN)
              ResizeGadget(0, 0, 0, WindowWidth(#WINDOW_MAIN), WindowHeight(#WINDOW_MAIN))
              SaveUserData() 
            EndIf
            
          Case #PB_Event_CloseWindow
            HideMainWindow()
        EndSelect
        
      Case #WINDOW_SETTINGS
         HideCaretHandler()
        Protected closedSettings = #False
        
        Select windowEvent
          Case #PB_Event_Timer
            If EventTimer() = 1
              CheckCaptureTimeout()
            EndIf
            
          Case #PB_Event_Gadget
            
            Select EventGadget()
              Case #STRING_SHORTCUT_DISPLAY
                If EventType() = #PB_EventType_Focus
                  If Not IsCapturing
                    StartCapture()
                  EndIf
                EndIf
                
              Case #BTN_CAPTURE
                If Not IsCapturing
                  StartCapture()
                Else
                  StopCapture()
                  If CurrentShortcut\DisplayText <> ""
                    SetGadgetText(#STRING_SHORTCUT_DISPLAY, CurrentShortcut\DisplayText)
                  Else
                    SetGadgetText(#STRING_SHORTCUT_DISPLAY, "")
                  EndIf
                EndIf
                
              Case #BTN_OK
                StopCapture()
                
                If ListSize(CapturedVKs()) > 0
                  If ValidateShortcut()
                    SaveShortcut()
                  Else
                    MessageRequester("Error", "Please capture a valid shortcut (at least 2 keys) or click Cancel.", 
                                     #PB_MessageRequester_Error)
                    Break ; Don't close window
                  EndIf
                EndIf
                
                closedSettings = #True 
                
              Case #BTN_CANCEL
                StopCapture()
                closedSettings = #True 
                
            EndSelect
            
          Case #PB_Event_CloseWindow
            StopCapture()
            closedSettings = #True
        EndSelect
        
        If closedSettings
          RemoveWindowTimer(#WINDOW_SETTINGS, 1)
          HideWindow(#WINDOW_SETTINGS, #True)
          
          ; CRITICAL: Re-install keyboard hook after settings closes!
          InstallKeyboardHook()
          
          ShowMainWindow()
        EndIf
        
    EndSelect
  ForEver
EndProcedure

;=====================================================================
;-  Cleanup
;=====================================================================

Procedure CleanUp()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If themeBgBrush
      DeleteObject_(themeBgBrush)
    EndIf
    RemoveKeyboardHook()
    If themeBgBrush
      DeleteObject_(themeBgBrush)
    EndIf 
    If appIcon
      DestroyIcon_(appIcon)
    EndIf 
    If MutexHandle
      CloseHandle_(MutexHandle)
    EndIf 
  CompilerEndIf
EndProcedure 

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1180
; FirstLine = 1160
; Folding = --------------
; Optimizer
; EnableThread
; EnableXP
; DPIAware
; EnableOnError
; UseIcon = icon\icon.ico
; Executable = ..\Assistant.exe
; Compiler = PureBasic 6.21 - C Backend (Windows - x64)