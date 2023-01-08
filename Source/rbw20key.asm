; history:
; 1.0   initial release
;       tested with: Rainbow VSTi v2.0 

; Rainbow Synth VSTi v2.0 Open-Source Keymaker
; (C) Lorian / UNION

; #########################################################################
    .386
    .model flat, stdcall
    option casemap:none
; #########################################################################

    include \masm32\include\windows.inc

    include \masm32\include\kernel32.inc
    includelib \masm32\lib\kernel32.lib

    include \masm32\include\user32.inc
    includelib \masm32\lib\user32.lib

    include \masm32\include\comdlg32.inc
    includelib \masm32\lib\comdlg32.lib


; #########################################################################

;== local macros ==

    m2m MACRO M1, M2
        push M2
        pop  M1
    ENDM

    return MACRO arg
        mov eax, arg
        ret
    ENDM

;== local prototypes ==

DlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
keyengine PROTO :DWORD
setregkey PROTO

; #########################################################################


 .const
    IDC_STATIC          equ -1
    IDD_DIALOG          equ 100
    IDC_NAME            equ 3001
    IDC_UNLOCKKEY       equ 3002
    IDC_REGISTRY        equ 3003
    IDC_EXIT            equ 3004
    
    IDM_EXIT            equ 5000

    MAXSIZE             equ 040h-1
    
 .data
    wsprintfa           dd 0
    regopenkey          dd 0
    regclosekey         dd 0
    regsetvalueex       dd 0
    userlib             db "user32.dll",0
ALIGN 4
    userfunction        db "wsprintfA",0
ALIGN 4
    advapilib           db "advapi32.dll", 0
ALIGN 4
    funcname1           db "RegOpenKeyA", 0
ALIGN 4
    funcname2           db "RegCloseKey", 0
ALIGN 4
    funcname3           db "RegSetValueExA", 0

ALIGN 4
    lpCode              db "%08X-%08X-%04X-%08X-%02X",0
ALIGN 4
    regkey              db "Software\Rainbow Synth V2",0
ALIGN 4
    szName              db MAXSIZE+1 dup (0)
ALIGN 4
    szEmail             db MAXSIZE+1 dup (0)
ALIGN 4
    lpNoName            db "Enter your name if you want a key...",0
ALIGN 4
    regvalue1           db "serial",0
ALIGN 4
    regvalue2           db "userName",0
    Adjuster dd 33fh

.data?
    BigBuffer               db 50 dup (?)   ; universally used :)
ALIGN 4
    Key_Part_1          dd ?
    Key_Part_2          dd ?
    Key_Part_3          dd ?
    Key_Part_4          dd ?
    reghandle           dd ?

    NameCode_Part_1     dd ?
    NameCode_Part_2     dd ?

    Temp_Part_1         dd ?
    Temp_Part_2         dd ?
    namesize            dd ?

    hInstance               HINSTANCE ?
    CommandLine             LPSTR ?
    hWindow                 DWORD ?

 .code

start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke GetCommandLine
    mov CommandLine, eax
    invoke DialogBoxParam, hInstance, 100, NULL, addr DlgProc, NULL
    invoke ExitProcess,eax

; ########################################################################
DlgProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    .IF uMsg == WM_INITDIALOG
        invoke GetDlgItem, hWnd, IDC_NAME
        invoke SetFocus, eax
        invoke LoadLibrary, addr userlib
        push eax
        invoke GetProcAddress, eax, addr userfunction
        mov dword ptr wsprintfa, eax
        pop eax
        invoke FreeLibrary, eax
        invoke LoadLibrary, addr advapilib
        push eax
        invoke GetProcAddress, eax, addr funcname1
        mov dword ptr regopenkey, eax
        pop eax
        push eax
        invoke GetProcAddress, eax, addr funcname2
        mov dword ptr regclosekey, eax
        pop eax
        push eax
        invoke GetProcAddress, eax, addr funcname3
        mov dword ptr regsetvalueex, eax
        pop eax
        invoke FreeLibrary, eax

        invoke SendDlgItemMessage, hWnd, 3001, EM_SETLIMITTEXT, MAXSIZE-1, 0
        invoke SetDlgItemText, hWnd, 3002, addr lpNoName
        
        invoke SendMessage, hWnd, 128h, 30002h, 0
        
    .ELSEIF uMsg == WM_CLOSE
        invoke SendMessage, hWnd, WM_COMMAND, 5000, 0
    .ELSEIF uMsg == WM_COMMAND
        mov eax, wParam
        .IF lParam == 0
            .IF ax == 5000
                invoke EndDialog, hWnd, NULL
            .ENDIF
        .ELSE
            mov edx, wParam
            shr edx, 16
            .IF dx == EN_CHANGE
                cmp ax, 3001
                jne dont_proceed_info
proceed_info:
                invoke keyengine, hWnd
dont_proceed_info:
            .ELSEIF dx == BN_CLICKED
                cmp ax, 3003
                jnz noregistrybutton
                invoke setregkey
noregistrybutton:
                cmp ax, 3004
                jnz noclosebutton
                invoke SendMessage, hWnd, WM_COMMAND, 5000, 0
noclosebutton:
            .ENDIF
        .ENDIF
    .ELSE
        mov eax, FALSE
        ret
    .ENDIF
    mov eax, TRUE
    ret
DlgProc endp

; ########################################################################

setregkey proc
    pusha

    cmp  byte ptr [BigBuffer], 0
    jz   srk_exit
    cmp  byte ptr [szName], 0
    jz   srk_exit

    push offset reghandle
    push offset regkey
    push 080000001h
    call dword ptr [regopenkey]
    or   eax, eax
    jnz  srk_exit

    push 35
    push offset BigBuffer
    push 1
    push 0
    push offset regvalue1
    push dword ptr [reghandle]
    call dword ptr [regsetvalueex]

    push dword ptr [namesize]
    push offset szName
    push 1
    push 0
    push offset regvalue2
    push dword ptr [reghandle]
    call dword ptr [regsetvalueex]


    push dword ptr [reghandle]
    call dword ptr [regclosekey]
srk_exit:
    popa
    ret
setregkey endp

; ########################################################################

keyengine proc hWnd:HWND
    pusha

; == Get Name from DialogBox
    invoke GetDlgItemText, hWnd, 3001, addr szName, MAXSIZE
    mov [namesize], eax
    .IF eax == 0
        invoke SetDlgItemText, hWnd, 3002, addr lpNoName
    .ELSE

; == Calculate UserCode
CalcUserCode:
        mov ecx, 100h
        mov dword ptr [NameCode_Part_2], 0FEDCBA98h
        mov dword ptr [NameCode_Part_1], 12345678h

UserCodeOuterLoop:
        lea esi, szName
UserCodeInnerLoop:
        lodsb
        or  al, al
        jz  UserCodeInnerLoopEnd  
        movzx eax, al
        mov   ebx, dword ptr [NameCode_Part_1]
        add   ebx, dword ptr [NameCode_Part_2]
        add   ebx, eax
        xor   ebx, 0FEDCBA98h
        mov   dword ptr [NameCode_Part_1], ebx

       ; mov   ebx, dword ptr [NameCode_Part_1]
        sub   ebx, dword ptr [NameCode_Part_2]
        sub   ebx, eax
        xor   ebx, 12345678h
        mov   dword ptr [NameCode_Part_2], ebx
        jmp   UserCodeInnerLoop

UserCodeInnerLoopEnd:
        dec ecx
        jnz UserCodeOuterLoop

; == Generate 3rd part = Adjuster
        mov  eax, [Adjuster]
        and  eax, 0ffffh
        mov  [Key_Part_3], eax
        add  [NameCode_Part_1], eax
        imul eax, eax
        sub  [NameCode_Part_2], eax
;db 0cch
; == Generate 4th part = Code decryption key
        mov  eax, [NameCode_Part_1]
        mov  ebx, [NameCode_Part_2]
        mov  ecx, eax
        xor  ecx, ebx
        sub  ecx, ebx
        xor  ecx, 3d50433dh
        add  ecx, eax
        mov  [Key_Part_4], ecx

; == Generate 1st and 2nd part = stupid algo
        push ebp
        xor  ecx, ecx   ; ECX = numbits
        mov  [Key_Part_1], ecx
        mov  [Key_Part_2], ecx
        mov  ebp, 1     ; EBP = mymask
firstl:
        mov  esi, [NameCode_Part_1]
        and  esi, ebp   ; M1
        mov  edi, [NameCode_Part_2]
        and  edi, ebp   ; M2

        mov  edx, 3
secondl:
        mov  ebx, edx  ; Get bit 
        and  ebx, 1
        shl  ebx, cl
        add  ebx, [Key_Part_1]
        mov  [Temp_Part_1], ebx

        mov  ebx, edx  ; Get bit
        shr  ebx, 1
        shl  ebx, cl
        add  ebx, [Key_Part_2]
        mov  [Temp_Part_2], ebx

        mov  ebx, esi
        mov  eax, esi
        and  ebx, 0FFFFFFFEh
        imul ebx, [Temp_Part_1]
        and  ebx, ebp
        imul eax, [Temp_Part_2]
        and  eax, ebp
        neg  ebx
        inc  ebx
        and  ebx, ebp
        xor  ebx, eax
        cmp  ebx, [Temp_Part_1]
        jnz  failed

        mov  ebx, edi
        mov  eax, edi
        and  ebx, 0FFFFFFFEh
        imul ebx, [Temp_Part_2]
        and  ebx, ebp
        imul eax, [Temp_Part_1]
        and  eax, ebp
        neg  ebx
        inc  ebx
        and  ebx, ebp
        xor  ebx, eax
        cmp  ebx, [Temp_Part_2]
        jz   seconde
failed:
        dec  edx
        jns  secondl
seconde:
        mov  eax, [Temp_Part_1]
        mov  [Key_Part_1], eax
        mov  eax, [Temp_Part_2]
        mov  [Key_Part_2], eax
        inc  ecx
        shl  ebp, 1
        inc  ebp
        cmp  ecx, 32
        jnz  firstl

        pop  ebp

        mov  eax, [Adjuster]
        imul eax, 08088405h
        inc  eax
        mov  [Adjuster], eax

        xor  ecx, ecx
        mov  eax, [Key_Part_1]
aa:
        or   eax, eax
        jz   cc
        test al, 1
        je   bb
        inc  ecx
bb:
        shr  eax, 1
        jmp  aa
cc:

        mov  eax, [Key_Part_2]
aa2:
        or   eax, eax
        jz   cc2
        test al, 1
        je   bb2
        inc  ecx
bb2:
        shr  eax, 1
        jmp  aa2
cc2:

        cmp  ecx, 16
        jb   CalcUserCode

        mov  eax, [Key_Part_1]
        cmp  eax, [Key_Part_2]
        jz   CalcUserCode


; == Calculate Key Checksum
        xor  edx, edx
        xor  eax, eax
        xor  ebx, ebx
        lea  esi, Key_Part_1
        mov  ecx, 16
calcsumloop:
        lodsb
        mov  bl, al
        and  al, 0Fh
        shr  bl, 4
        add  edx, eax
        add  edx, ebx
        dec  ecx
        jnz  calcsumloop
        and  edx, 0FFh

        push edx
        push dword ptr [Key_Part_4]
        push dword ptr [Key_Part_3]
        push dword ptr [Key_Part_1] ; ehmm sorry but thats
        push dword ptr [Key_Part_2] ; the correct order
        push offset lpCode
        push offset BigBuffer
        call dword ptr [wsprintfa]
        add  esp, 7*4

        invoke SetDlgItemText, hWnd, 3002, addr BigBuffer
    .ENDIF
    popa
    ret
keyengine endp


end start
