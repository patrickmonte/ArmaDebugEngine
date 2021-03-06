.386
option casemap :none

_TEXT    SEGMENT


    ;mangled functions
    EXTERN ?_scriptEntered@EngineHook@@QAEXI@Z:             PROC;    EngineHook::_scriptEntered
    EXTERN ?_scriptInstruction@EngineHook@@QAEXIIII@Z:      PROC;    EngineHook::_scriptInstruction
    EXTERN ?_scriptLeft@EngineHook@@QAEXI@Z:                PROC;    EngineHook::_scriptLeft
    EXTERN ?_scriptLoaded@EngineHook@@QAEXI@Z:              PROC;    EngineHook::_scriptLoaded
    EXTERN ?_scriptTerminated@EngineHook@@QAEXI@Z:          PROC;    EngineHook::_scriptTerminated
    EXTERN ?_world_OnMissionEventStart@EngineHook@@QAEXI@Z: PROC;    EngineHook::_world_OnMissionEventStart
    EXTERN ?_world_OnMissionEventEnd@EngineHook@@QAEXXZ:    PROC;    EngineHook::_world_OnMissionEventEnd
    EXTERN ?_worldSimulate@EngineHook@@QAEXXZ:              PROC;    EngineHook::_worldSimulate
    EXTERN ?_onScriptError@EngineHook@@QAEXI@Z:             PROC;    EngineHook::_onScriptError
    EXTERN ?_onScriptAssert@EngineHook@@QAEXI@Z:            PROC;    EngineHook::_onScriptAssert
    EXTERN ?_onScriptHalt@EngineHook@@QAEXI@Z:              PROC;    EngineHook::_onScriptHalt
    EXTERN ?_onScriptEcho@EngineHook@@QAEXI@Z:              PROC;    EngineHook::_onScriptEcho

    ;hool Enable fields
    EXTERN _hookEnabled_Instruction:                        dword
    EXTERN _hookEnabled_Simulate:                           dword

    ;JmpBacks

    EXTERN _instructionBreakpointJmpBack:                   dword
    EXTERN _scriptVMSimulateStartJmpBack:                   dword
    EXTERN _worldSimulateJmpBack:                           dword
    EXTERN _worldMissionEventStartJmpBack:                  dword
    EXTERN _worldMissionEventEndJmpBack:                    dword
    EXTERN _scriptVMConstructorJmpBack:                     dword
    EXTERN _onScriptErrorJmpBack:                           dword
    EXTERN _scriptPreprocessorConstructorJmpBack:           dword
    EXTERN _scriptAssertJmpBack:                            dword
    EXTERN _scriptHaltJmpBack:                              dword
    EXTERN _scriptEchoJmpBack:                              dword
    
    ;misc
    EXTERN _GlobalEngineHook:                               dword
    EXTERN _scriptVM:                                       dword
    EXTERN _currentScriptVM:                                dword
    EXTERN _scriptPreprocessorDefineDefine:                 dword
    EXTERN _preprocMacroName:                               dword
    EXTERN _preprocMacroValue:                              dword

    ;##########
    PUBLIC _instructionBreakpoint
    _instructionBreakpoint PROC

        ;mov instructionBP_gameState, ebp;
        ;mov instructionBP_VMContext, edi;
        ;mov instructionBP_Instruction, ebx;
        ;push    eax;                                               don't need to keep because get's overwritten by fixup
        push    ecx;
        mov     ecx, _hookEnabled_Instruction;                      Skip if hook is disabled
        test    ecx, ecx;
        jz      _return;
        mov     eax, [esp + 14Ch]; instructionBP_IDebugScript
        push    eax; instructionBP_IDebugScript
        push    ebp; instructionBP_gameState
        push    edi; instructionBP_VMContext
        push    ebx; instructionBP_Instruction
        mov     ecx, offset _GlobalEngineHook;
        call    ?_scriptInstruction@EngineHook@@QAEXIIII@Z;         EngineHook::_scriptInstruction
    _return:
        pop     ecx;
        ;pop     eax;
        mov     eax, [ebx + 14h];                                   Fixup
        lea     edx, [ebx + 14h];
        jmp     _instructionBreakpointJmpBack;

    _instructionBreakpoint ENDP

    ;##########
    PUBLIC _scriptVMConstructor
    _scriptVMConstructor PROC

        push    edi;                                                scriptVM Pointer
        mov     ecx, offset _GlobalEngineHook;
        call    ?_scriptLoaded@EngineHook@@QAEXI@Z;                 EngineHook::_scriptLoaded;
        ;_return:
        push    1;                                                  Fixup
        lea     eax, [edi + 29Ch];
        jmp     _scriptVMConstructorJmpBack;

    _scriptVMConstructor ENDP



    IFDEF  passSimulateScriptVMPtr
        .ERR <"hookEnabled_Simulate may kill engine if it's disabled after simulateStart and before simulateEnd">
    ENDIF

    ;##########
    PUBLIC _scriptVMSimulateStart
    _scriptVMSimulateStart PROC

        push    eax;
        push    ecx;
        
    IFNDEF passSimulateScriptVMPtr
        mov     eax, offset _currentScriptVM;
        mov     [eax], ecx;                                         use this in case of scriptVM ptr not being easilly accessible in SimEnd
    ENDIF
       
        mov     eax, _hookEnabled_Simulate;                         Skip if hook is disabled
        test    eax, eax;
        jz      _return;

        push    ecx;                                                _scriptEntered arg
        mov     ecx, offset _GlobalEngineHook;
        call    ?_scriptEntered@EngineHook@@QAEXI@Z;                EngineHook::_scriptEntered;
    _return:
        pop     ecx;
        pop     eax;
        sub     esp, 34h;                                           Fixup
        push    ebp;
        mov     ebp, ecx;
    IFDEF passSimulateScriptVMPtr
        cmp     byte ptr[edi + 2A0h], 0;                            if !Loaded we exit right away and never hit scriptVMSimulateEnd
        jz      _skipVMPush;
        push    edi;                                                scriptVM to receive again in scriptVMSimulateEnd
    _skipVMPush:
    ENDIF
        jmp     _scriptVMSimulateStartJmpBack;
    _scriptVMSimulateStart ENDP


    ;##########
    PUBLIC _scriptVMSimulateEnd
    _scriptVMSimulateEnd PROC

        push    eax;
        push    ecx;
        push    edx;

        mov     ecx, _hookEnabled_Simulate;                        Skip if hook is disabled
        test    ecx, ecx;
        jz      _return;

        ;prepare arguments for func call
    IFDEF passSimulateScriptVMPtr
        mov     edi, [esp + Ch + 4h/*I added push edx*/];           Retrieve our pushed scriptVM ptr
    ELSE
        mov     edi, _currentScriptVM;                              use this in case of scriptVM ptr not being easilly accessible 
    ENDIF
        push    edi;                                                scriptVM
        mov     ecx, offset _GlobalEngineHook;
        test    al, al;                                             al == done
        jz      short _notDone;                                     script is not Done  
        call    ?_scriptTerminated@EngineHook@@QAEXI@Z;             EngineHook::_scriptTerminated;    script is Done
        jmp     short _return;
    _notDone:
        call    ?_scriptLeft@EngineHook@@QAEXI@Z;                   EngineHook::_scriptLeft;
    _return:
        pop     edx;
        pop     ecx;                                                These are probably not needed. But I can't guarantee that the compiler didn't expect these to stay unchanged
        pop     eax;
    IFDEF passSimulateScriptVMPtr
        pop     edi;                                                Remove our pushed scriptVM ptr
    ENDIF
        pop     ebx;                                                Fixup
        pop     ebp;
        add     esp, 34h;
        retn    8;

    _scriptVMSimulateEnd ENDP

    ;##########
    PUBLIC _worldSimulate
    _worldSimulate PROC

        push    ecx;
        push    eax;
        mov     ecx, offset _GlobalEngineHook;
        call    ?_worldSimulate@EngineHook@@QAEXXZ;                 EngineHook::_worldSimulate;
        pop     eax;                                                Don't know if eax will be modified but it's likely
        pop     ecx;
        sub     esp, 3D8h;                                          Fixup
        jmp     _worldSimulateJmpBack;

    _worldSimulate ENDP


    ;##########
    PUBLIC _worldMissionEventStart
    _worldMissionEventStart PROC

        push    ecx;
        push    eax;

        push    eax;                                                _world_OnMissionEventStart argument
        mov     ecx, offset _GlobalEngineHook;
        call    ?_world_OnMissionEventStart@EngineHook@@QAEXI@Z;    EngineHook::_world_OnMissionEventStart;
        pop     eax;                                                Don't know if eax will be modified but it's likely
        pop     ecx;

        push    ebx;                                                Fixup
        mov     ebx, ecx;
        push    esi;
        lea     esi, [eax + eax * 4];
        jmp     _worldMissionEventStartJmpBack;

    _worldMissionEventStart ENDP

    ;##########
    PUBLIC _worldMissionEventEnd
    _worldMissionEventEnd PROC

        push    ecx;
        push    eax;
        mov     ecx, offset _GlobalEngineHook;
        call    ?_world_OnMissionEventEnd@EngineHook@@QAEXXZ;       EngineHook::_world_OnMissionEventEnd;
        pop     eax;                                                Don't know if eax will be modified but it's likely
        pop     ecx;

        pop     edi;                                                Fixup
        pop     esi;
        pop     ebx;
        mov     esp, ebp;
        pop     ebp;
        jmp     _worldMissionEventEndJmpBack;

    _worldMissionEventEnd ENDP


    ;##########
    PUBLIC _onScriptError
    _onScriptError PROC

        push    ecx;
        push    eax;
        push    edx;

        push    ecx;                                                gameState ptr
        mov     ecx, offset _GlobalEngineHook;
        call    ?_onScriptError@EngineHook@@QAEXI@Z;                EngineHook::_world_OnMissionEventEnd;
        
        pop     edx;
        pop     eax;                                                Don't know if eax will be modified but it's likely
        pop     ecx;

        push    ebx;                                                Fixup
        push    esi
        mov     esi, [edx+28h]
        ;push    edi
        ;test    esi, esi
        jmp     _onScriptErrorJmpBack;

    _onScriptError ENDP



    ;##########
    PUBLIC _scriptPreprocessorConstructor
    _scriptPreprocessorConstructor PROC

        push    eax;
        push    edx;

        mov     ecx, _preprocMacroValue;
        push    ecx;
        mov     ecx, _preprocMacroName;
        push    ecx;
        mov     ecx, esi;                                           this*
        mov     eax, _scriptPreprocessorDefineDefine;
        call    eax;

        pop     edx;
        pop     eax;

        mov     al, [edx+4];                                        Fixup
        mov     [esi+0B0h], al
        jmp     _scriptPreprocessorConstructorJmpBack;

    _scriptPreprocessorConstructor ENDP

    ;##########
    PUBLIC _onScriptAssert
    _onScriptAssert PROC

        push    ebx
        push    esi
        mov     esi, [esp+14h]
        push    edi
        mov     ecx, [esi+4]
        test    ecx, ecx
        jz      short _error;
        mov     eax, [ecx]
        mov     eax, [eax+10h]
        call    eax;                                                GameValue::getAsBool
        test    al, al
        jnz     short _return;
    _error:
        push    [esp+10h+4h];                                       GameState*
        mov     ecx, offset _GlobalEngineHook;
        call    ?_onScriptAssert@EngineHook@@QAEXI@Z;               EngineHook::_onScriptAssert;
    _return:
        jmp     _scriptAssertJmpBack;

    _onScriptAssert ENDP

    ;##########
    PUBLIC _onScriptHalt
    _onScriptHalt PROC

        ;gameState on [esp+8]

        


        push    [esp+8];
        mov     ecx, offset _GlobalEngineHook;
        call    ?_onScriptHalt@EngineHook@@QAEXI@Z;                 EngineHook::_onScriptHalt;
    _return:
        mov     ecx, [esp+4];                                       Orig function will create a bool(false) value on ecx and return it
        ;add     esp, 8
        push    0                                                  ;make this 1 to return true
        jmp     _scriptHaltJmpBack;

    _onScriptHalt ENDP

    ;##########
    PUBLIC _onScriptEcho
    _onScriptEcho PROC
        mov     ecx, [esp+12];  
        push    ecx;                                                GameValue*
        mov     ecx, offset _GlobalEngineHook;
        call    ?_onScriptEcho@EngineHook@@QAEXI@Z;                 EngineHook::_onScriptHalt;

        mov     ecx, [esp+12];                                      Fixup
        sub     esp, 8;                                             
        jmp     _scriptEchoJmpBack;

    _onScriptEcho ENDP

_TEXT    ENDS
END
