;
;   BP3D DirectX 9 Demo
;
;   Demonstrates the usage of the DirectX 9 rendering API with BP3D.
;   32-bit only (as per WinInc\include\float.inc).
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

.386
.model flat, stdcall
option casemap:none

BP_COMPATIBILITY_W9X	EQU <1>	; Exclude unsupported APIs
IFNDEF BP_WININC
	BP_WININC EQU <1>
ENDIF

; BP3D includes
include ..\..\src\BP3D.asm
include ..\..\src\BP3DMaths.inc

; WinInc includes
include include\d3d9.inc
;   D3D9.LIB must also be generated. WinInc doesn't seem to come with a DEF file
; for D3D9, so you will have to make one manually. The only export used in this
; demo is "_Direct3DCreate9@4", anything else is class methods
includelib d3d9.lib

CUSTOMVERTEX STRUCT
	X		REAL4 ?
	Y		REAL4 ?
	Z		REAL4 ?
	Color	DWORD ?
CUSTOMVERTEX ENDS

.CONST
AppName DB "BP3D DirectX 9 Demo", 0	; Caption

Vertices CUSTOMVERTEX \
<0.0, 1.0, 0.0, D3DCOLOR_XRGB(0, 0, 255)>, \
<1.0, -1.0, 0.0, D3DCOLOR_XRGB(0, 255, 0)>, \
<-1.0, -1.0, 0.0, D3DCOLOR_XRGB(255, 0, 0)>

D3DFVF_CUSTOMVERTEX EQU D3DFVF_XYZ or D3DFVF_DIFFUSE

.DATA
FMain	BPForm <>

PD3DBuf		LPDIRECT3DVERTEXBUFFER9 0

D3DParams	D3DPRESENT_PARAMETERS < \
	0, \
	0, \
	D3DFMT_UNKNOWN, \
	0, \
	0, \
	0, \
	D3DSWAPEFFECT_DISCARD, \
	0, \
	TRUE, \
	0, \
	0, \
	0, \
	0, \
	0 \
>

;   Simple MASM SADD replacement. Declares a string and returns its ADDR in pax.
;   qStr:String - quoted string.
s MACRO qStr:REQ
	LOCAL strDb
	.DATA
		strDb DB qStr,0
	.CODE
	EXITM <ADDR strDb>
ENDM


.CODE
InitVertexBuffer PROC
	LOCAL pVertices:BPPtr
	
	invoke vf(FMain.DeviceContext, IDirect3DDevice9, CreateVertexBuffer), \
	3 * SIZEOF CUSTOMVERTEX, 0, D3DFVF_CUSTOMVERTEX, D3DPOOL_DEFAULT, \
	OFFSET PD3DBuf, NULL
	.IF (pax != D3D_OK)
		invoke bpError, s("Failed to create vertex buffer."), 0
	.ENDIF
	
	invoke vf(PD3DBuf, IDirect3DVertexBuffer9, Lock_), 0, \
	3 * SIZEOF CUSTOMVERTEX, ADDR pVertices, 0
	.IF (pax != D3D_OK)
		invoke bpError, s("Failed to lock vertex buffer."), 0
	.ENDIF
	invoke RtlMoveMemory, pVertices, ADDR Vertices, 3 * SIZEOF CUSTOMVERTEX
	invoke vf(PD3DBuf, IDirect3DVertexBuffer9, Unlock)
	
	invoke vf(FMain.DeviceContext, IDirect3DDevice9, SetRenderState), \
	D3DRS_LIGHTING, FALSE
	ret
InitVertexBuffer ENDP

SetDeviceParams PROC
	bpMEM32 D3DParams.BackBufferWidth, FMain.ScreenSize.x
	bpMEM32 D3DParams.BackBufferHeight, FMain.ScreenSize.y
	bpMPM D3DParams.hDeviceWindow, FMain.Handle
	ret
SetDeviceParams ENDP

; FMain bindings
OnCreate PROC EXPORT	
	;   It's probably best to create separate pointers for IDirect3D objects, 
	; but hey let's use the BP3D API where it doesn't make much sense to
	
	; Initalize Direct3D object
	mov FMain.GraphicsContext, bpR(Direct3DCreate9, D3D_SDK_VERSION)
	.IF !(pax)
		invoke bpError, s("Failed to create Direct3D object."), 0
	.ENDIF
	
	; Setup parameters and initialize Direct3D device
	invoke SetDeviceParams
	
	invoke vf(FMain.GraphicsContext, IDirect3D9, CreateDevice), D3DADAPTER_DEFAULT, \
	D3DDEVTYPE_HAL, FMain.Handle, D3DCREATE_SOFTWARE_VERTEXPROCESSING, \
	ADDR D3DParams, OFFSET FMain.DeviceContext
	.IF (pax != D3D_OK)
		invoke bpError, s("Failed to create Direct3D device."), 0
	.ENDIF
	
	; Create a vertex buffer
	invoke InitVertexBuffer
	ret
OnCreate ENDP

OnDestroy PROC EXPORT
	.IF (PD3DBuf)
		invoke vf(PD3DBuf, IDirect3DVertexBuffer9, Release)
	.ENDIF
	.IF (FMain.DeviceContext)
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, Release)
	.ENDIF
	.IF (FMain.GraphicsContext)
		invoke vf(FMain.GraphicsContext, IDirect3D9, Release)
	.ENDIF
	ret
OnDestroy ENDP

OnInput PROC EXPORT BPInType:BPEnum, BPInStruct:BPPtr	
	mov pbx, BPInStruct
	.IF (BPInType == BP_INPUT_KEY)
		ASSUME pbx:PTR BPInKey
		
		.IF ([pbx].Pressed)
			.IF ([pbx].Keycode == 'F')
				.IF (FMain.WindowMode == BP_WINDOW_MODE_FULLSCREEN)
					invoke bpSetWindowMode, ADDR FMain, BP_WINDOW_MODE_WINDOWED
				.ELSE
					invoke bpSetWindowMode, ADDR FMain,BP_WINDOW_MODE_FULLSCREEN
				.ENDIF
			.ENDIF
		.ENDIF
	.ENDIF
	
	ASSUME pbx:nothing
	ret
OnInput ENDP

OnRender PROC EXPORT
	invoke vf(FMain.DeviceContext, IDirect3DDevice9, Clear), 0, NULL, \
	D3DCLEAR_TARGET, D3DCOLOR_XRGB(0, 0, 0), f(1.0), 0
	
	invoke vf(FMain.DeviceContext, IDirect3DDevice9, BeginScene)
	.IF (pax == D3D_OK)
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, SetStreamSource), 0, \
		PD3DBuf, 0, SIZEOF CUSTOMVERTEX
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, SetFVF), \
		D3DFVF_CUSTOMVERTEX
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, DrawPrimitive), \
		D3DPT_TRIANGLELIST, 0, 1
		
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, EndScene)
	.ENDIF

	invoke vf(FMain.DeviceContext, IDirect3DDevice9, Present), NULL, NULL, \
	NULL, NULL
	ret
OnRender ENDP

OnResize PROC EXPORT
	LOCAL d3dView:D3DVIEWPORT9
	
	; Resize the viewport and device (DirectX why must you be like this)
	invoke RtlZeroMemory, ADDR d3dView, SIZEOF D3DVIEWPORT9
	bpMEM32 d3dView.Width_, FMain.ScreenSize.x
	bpMEM32 d3dView.Height, FMain.ScreenSize.y
	bpMEM32 d3dView.MaxZ, f(1.0)
	
	.IF (FMain.DeviceContext) && (FMain.ScreenSize.x) && (FMain.ScreenSize.y)
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, SetViewport), \
		ADDR d3dView
		
		.IF (PD3DBuf)
			invoke vf(PD3DBuf, IDirect3DVertexBuffer9, Release)
		.ENDIF
		invoke SetDeviceParams
		invoke vf(FMain.DeviceContext, IDirect3DDevice9, Reset), ADDR D3DParams
		invoke InitVertexBuffer
	.ENDIF
	ret
OnResize ENDP

start:
	mov FMain.Caption,	OFFSET AppName
	
	mov FMain.OnCreate,		OFFSET OnCreate
	mov FMain.OnDestroy,	OFFSET OnDestroy
	mov FMain.OnInput,		OFFSET OnInput
	mov FMain.OnRender,		OFFSET OnRender
	mov FMain.OnResize,		OFFSET OnResize
	
	invoke bpCreateForm, ADDR FMain

	; This code is reached when form's execution is done
	invoke TerminateProcess, bpR(GetCurrentProcess), 0
end start