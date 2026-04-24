; Set CPU mode to whatever necessary 
.686
.model flat, stdcall
option casemap:none

; Set path to where BoilPlate3D is located (or use text macros)
include ..\src\BP3D.asm

.DATA
FMain BPForm <>

.CODE
OnCreate PROC EXPORT
	; Code to be executed at form creation goes here
	invoke bpInitGLContext, ADDR FMain	; Initialize OpenGL context
	ret
OnCreate ENDP

OnInput PROC EXPORT BPInType:BYTE, BPInStruct:BPPtr
	; Code for receiving input of types BP_INPUT_* goes here
	
	mov pbx, BPInStruct
	.IF (BPInType == BP_INPUT_MOUSE_MOVE)
		ASSUME pbx:PTR BPInMouseMove
		; Process mouse movement input here
		
	.ELSEIF (BPInType == BP_INPUT_KEY) || (BPInType == BP_INPUT_MOUSE_BUTTON)
		ASSUME pbx:PTR BPInKey
		; Process key / mouse button input here
		
	.ENDIF
	ret
OnInput ENDP

OnRender PROC EXPORT
	; Code for rendering goes here
	
	ret
OnRender ENDP

start:
	mov FMain.OnCreate, OFFSET OnCreate
	mov FMain.OnInput, OFFSET OnInput
	mov FMain.OnRender, OFFSET OnRender
	mov FMain.ScreenSize.x, 800
	mov FMain.ScreenSize.y, 600
	invoke bpCreateForm, ADDR FMain
	
	; Form processing exited, safely terminate process
	call GetCurrentProcess
	invoke TerminateProcess, pax, 0
end start