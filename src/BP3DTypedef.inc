;
;   BP3DTypedef.inc
;   Version 0.9bc1
;   BP3D generic types (for parity between BP3D and independently imported 
; modules).
;
;   Copyright (c) 2025-2026 Yevhenii Ionenko (aka GreatCorn).
;   All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

; -----	INTERFACE -----
;   Available compile-time symbolic macros to define (EQU) before including 
; BP3D, for additional or alternative functionality in the build:
;
;   BP_DOUBLE_PRECISION - export BPFloat as REAL8, instead of REAL4 (currently
; BPFloat remains unused).
;
;   BP_EXPORT_NAMES - export PROC names to executable via BPPROC TEXTEQU.
;

IFNDEF BP3D_TYPEDEF_INC
BP3D_TYPEDEF_INC EQU <1>

IFDEF BP_64	; Cross-architecture compatibility (deprecated)
	BPSPtr		TYPEDEF SQWORD	; Signed pointer type
	BPPtrShift	EQU 3			; Byte shift amount (to use instead of mul/div)
	
	; Pointer registers
	pax	EQU rax	
	pbx	EQU rbx
	pcx	EQU rcx
	pdx	EQU rdx
	pbp	EQU rbp
	psp	EQU rsp
ELSE
	BPSPtr		TYPEDEF SDWORD	; Signed pointer type
	BPPtrShift	EQU 2			; Byte shift amount (to use instead of mul/div)
	
	; Pointer registers
	pax	EQU eax
	pbx	EQU ebx
	pcx	EQU ecx
	pdx	EQU edx
	pbp	EQU ebp
	psp	EQU esp
ENDIF

;   Miscellaneous types for argument generalization
BPBool	TYPEDEF BYTE		; Boolean type
BPEnum	TYPEDEF BYTE		; Enumerator type
BPPtr	TYPEDEF PTR			; Pointer type

IFDEF BP_DOUBLE_PRECISION	; Floating-point type (currently unused)
	BPFloat	TYPEDEF REAL8
ELSE
	BPFloat	TYPEDEF REAL4
ENDIF

; Export BP3D PROC names
IFDEF BP_EXPORT_NAMES
	BPPROC	TEXTEQU <PROC EXPORT>
	COMMENT * ENDP ENDP *	; Notepad++ you wonderful idiot
ELSE
	BPPROC	TEXTEQU <PROC>
	COMMENT * ENDP ENDP *
ENDIF

IFNDEF FALSE
	FALSE EQU 0
ENDIF
IFNDEF TRUE
	TRUE EQU 1
ENDIF

;   @Cpu exclusive demystification flags
;   Version bits (generally all add up, except for 586)
BP_CPU_8086			EQU 0000001b
BP_CPU_186			EQU 0000010b
BP_CPU_286			EQU 0000100b
BP_CPU_386			EQU 0001000b
BP_CPU_486			EQU 0010000b
BP_CPU_586			EQU 0100000b	; 686 doesn't have this bit
BP_CPU_686			EQU 1000000b
;   Higher privilege level instructions (like .286P, .386P, etc)
BP_CPU_PRIVILEGE	EQU 1 shl 7
;   Math coprocessor instruction sets
BP_FPU_8087			EQU 0001b shl 8
BP_FPU_287			EQU 0100b shl 8	; Bit 9 is skipped
BP_FPU_387			EQU 1000b shl 8

;   Malloc macros for memory tracing, requires main BP3D, here only for symbolic
; equivalence. See BP3D.asm for documentation
IFDEF BP_TRACEABLE_HEAP
	bpFree		TEXTEQU <bpFreeProc>
	bpMalloc	TEXTEQU <bpMallocProc>
	bpReAlloc	TEXTEQU <bpReAllocProc>
ELSE
	bpFree		TEXTEQU <HeapFree>
	bpMalloc	TEXTEQU <HeapAlloc>
	bpReAlloc	TEXTEQU <HeapReAlloc>
ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DTypedef.inc
ENDIF