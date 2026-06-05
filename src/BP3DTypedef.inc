;
;   BP3DTypedef.inc
;   Version 0.8ac1
;   BP3D generic types (for parity between BP3D and independently imported 
; modules).
;
;   Copyright (c) 2025-2026 Yevhenii Ionenko (aka GreatCorn).
;   All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_TYPEDEF_INC
BP3D_TYPEDEF_INC EQU <1>

IFDEF BP_64	; Cross-architecture compatibility (WIP)
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

IFDEF BP_DOUBLE_PRECISION	; Floating-point type
	BPFloat	TYPEDEF REAL8
ELSE
	BPFloat	TYPEDEF REAL4
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
BP_FPU_8087			EQU 0001 shl 8
BP_FPU_287			EQU 0100 shl 8	; Bit 9 is skipped
BP_FPU_387			EQU 1000 shl 8

ELSE
	ECHO BP3D: Duplicate include file BP3DTypedef.inc
ENDIF