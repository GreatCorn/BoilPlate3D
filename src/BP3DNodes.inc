;
;   BP3DNodes.inc
;   Version 0.6
;   BP3D experimental OOP-like nodes extension, intended for building game
; engine-like functionality on top of it.
;   Is available for independed importing without main BP3D.
;
;   Copyright (c) 2025-2026 Yevhenii Ionenko (aka GreatCorn
;   All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_NODES_INC
BP3D_NODES_INC EQU <1>

IFNDEF BP3D_TYPEDEF_INC
	include BP3DTypedef.inc
ENDIF

BPNode STRUCT		; Basic node structure
	Tag			BYTE 32 DUP (0)	; String name/tag (displayed with bpPrintTree)
	
	ChildCount	DWORD 0			; Amount of children added to the node
	Children	BPPtr 0			; Children array pointer
	Parent		BPPtr 0			; Parent node pointer
BPNode ENDS

BPObject STRUCT		; Basic event-driven object node structure
	BPNode <>			; Transparent inheritance at 0 OFFSET
	
	;   Event procedures are more of a suggestion, but generally follow BPForm
	; events to be called from them via bpPropagateSignal (supplying BPInStruct
	; in OnInput).
	
	;   OnCreate	PROC STDCALL
	;   Gets called after the form has just been created (bpCreateForm).
	OnCreate	BPPtr 0
	
	;   OnDestroy	PROC STDCALL
	;   Gets called after the form has just been destroyed (WM_DESTROY).
	OnDestroy	BPPtr 0
	
	;   Gets called in a separate asynchronous thread every bpFixedInterval 
	; seconds (default 0.01666666 s = 60 times/s).
	OnFixed		BPPtr 0
	
	;   OnInput		PROC STDCALL BPInStruct:BPPtr
	;   Gets called whenever captured input gets sent to the form (see 
	; InputFlags).
	;   BPInStruct:BPPtr - pointer to a BPIn* struct corresponding to InType,
	; located at its offset 0 as a BPEnum.
	OnInput		BPPtr 0
	
	;   OnRender	PROC STDCALL
	;   Gets called whenever the form is drawn (WM_PAINT). If DefaultFlag is on,
	; doesn't send DefWindowProc to maintain a loop. For frame-independence
	; deltaTime should be used.
	OnRender	BPPtr 0
	
	;   OnStart		PROC STDCALL
	;   Gets called on the first frame after form creation.
	OnStart		BPPtr 0
BPObject ENDS

bpRemoveChild PROTO :BPPtr, :BPPtr

.DATA
bpPrintTreeIndent	DWORD -1

.CODE
bpAddChild PROC EXPORT USES pbx BPNodePtr:BPPtr, ChildPtr:BPPtr
	ASSUME pbx:PTR BPNode
	; Make the child an orphan and reparent
	mov pbx, ChildPtr
	.IF ([pbx].Parent)
		invoke bpRemoveChild, [pbx].Parent, pbx
	.ENDIF
	bpMPM [pbx].Parent, BPNodePtr
	
	; Add to children on node
	mov pbx, BPNodePtr
	
	mov pax, [pbx].ChildCount
	shl pax, BPPtrShift
	push pax
	.IF ([pbx].Children)
		add eax, SIZEOF BPPtr
		invoke bpReAlloc, bpDefHeap, 0, [pbx].Children, eax
	.ELSE
		invoke bpMalloc, bpDefHeap, 0, SIZEOF BPPtr
	.ENDIF
	mov [pbx].Children, pax
	inc [pbx].ChildCount
	pop pax
	add pax, [pbx].Children
	bpMPM BPPtr PTR [pax], ChildPtr
	
	ASSUME pbx:nothing
	ret
bpAddChild ENDP

IFDEF print
bpPrintTree PROC EXPORT USES pbx BPNodePtr:BPPtr
	LOCAL EndAddr:DWORD
	inc bpPrintTreeIndent
	xor pbx, pbx
	.WHILE (pbx < bpPrintTreeIndent)
		print "	"
		inc pbx
	.ENDW
	ASSUME pbx:PTR BPNode
	mov pbx, BPNodePtr
	print pbx, 9
	print str$(pbx), 9
	print str$([pbx].ChildCount), 13, 10
	.IF ([pbx].Children)
		invoke HeapSize, bpDefHeap, 0, [pbx].Children
		add pax, [pbx].Children
		mov EndAddr, pax
		mov pcx, [pbx].Children
		.WHILE (pcx < EndAddr)
			push pcx
			invoke bpPrintTree, BPPtr PTR [pcx]
			pop pcx
			add pcx, SIZEOF BPPtr
		.ENDW
	.ENDIF
	ASSUME pbx:nothing
	dec bpPrintTreeIndent
	ret
bpPrintTree ENDP
ENDIF

bpPropagateSignal PROC EXPORT USES pbx BPNodePtr:BPPtr, EventOffset:BPPtr, \
EventArg:BPPtr
	LOCAL EndAddr:DWORD
	
	ASSUME pbx:PTR BPNode
	mov pbx, BPNodePtr
	; Signal own
	.IF (BPPtr PTR [pbx+EventOffset])
		.IF (EventArg)
			push EventArg
		.ENDIF
		call BPPtr PTR [pbx+EventOffset]
	.ENDIF
	; Propagate to children
	.IF ([pbx].Children)
		mov pax, [pbx].ChildCount
		shl pax, BPPtrShift
		add pax, [pbx].Children
		mov EndAddr, pax
		mov pcx, [pbx].Children
		.WHILE (pcx < EndAddr)
			push pcx
			invoke bpPropagateSignal, BPPtr PTR [pcx], EventOffset, EventArg
			pop pcx
			add pcx, SIZEOF BPPtr
		.ENDW
	.ENDIF
	ASSUME pbx:nothing
	ret
bpPropagateSignal ENDP

bpRemoveChild PROC EXPORT USES pbx BPNodePtr:BPPtr, ChildPtr:BPPtr
	ASSUME pbx:PTR BPNode
	
	; Search for address in children
	mov pbx, BPNodePtr
	mov pdx, [pbx].Children
	xor pcx, pcx
	.WHILE (pcx < [pbx].ChildCount)
		mov pax, BPPtr PTR [pdx+pcx*SIZEOF BPPtr]
		.IF (pax == ChildPtr)
			dec [pbx].ChildCount
			
			; Move children after the removed one
			.IF (pcx != [pbx].ChildCount)
				mov pax, [pbx].ChildCount
				sub pax, pcx
				shl pax, BPPtrShift
				shl pcx, BPPtrShift
				add pdx, pcx
				mov pcx, pdx
				add pcx, SIZEOF BPPtr
				invoke RtlMoveMemory, pdx, pcx, pax
			.ENDIF
			
			.IF ([pbx].ChildCount)
				mov pax, [pbx].ChildCount
				shl pax, BPPtrShift
				invoke bpReAlloc, bpDefHeap, 0, [pbx].Children, pax
				mov [pbx].Children, pax
			.ELSE
				invoke bpFree, bpDefHeap, 0, [pbx].Children
				mov [pbx].Children, 0
			.ENDIF
			
			mov pbx, ChildPtr
			mov [pbx].Parent, 0
			
			ret
		.ENDIF
		inc pcx
	.ENDW
	ASSUME pbx:nothing
	ret
bpRemoveChild ENDP

ELSE
	ECHO BP3D: Duplicate include file BP3DNodes.inc
ENDIF