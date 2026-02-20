;
;   BP3DVectors.inc
;   Version 0.8ac1
;   BP3D common vector (2D, 3D, 4D) functions extension.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_VECTORS_INC
BP3D_VECTORS_INC EQU <1>

IFNDEF BP3D_TYPEDEF_INC
	include BP3DTypedef.inc
ENDIF

; ----- INTERFACE -----

; ----- TYPES -----
Vector2 STRUCT
	X REAL4 0.0
	Y REAL4 0.0
Vector2 ENDS

Vector3 STRUCT
	X REAL4 0.0
	Y REAL4 0.0
	Z REAL4 0.0
Vector3 ENDS

Vector4 STRUCT
	X REAL4 0.0
	Y REAL4 0.0
	Z REAL4 0.0
	W REAL4 0.0
Vector4 ENDS

; ----- CONSTANTS -----
.CONST
Vector2One		Vector2 <1.0, 1.0>
Vector2Zero		Vector2 <0.0, 0.0>
Vector3Forward	Vector3 <0.0, 0.0, 1.0>
Vector3One		Vector3 <1.0, 1.0, 1.0>
Vector3Up		Vector3 <0.0, 1.0, 0.0>
Vector3Zero		Vector3 <0.0, 0.0, 0.0>

; ----- IMPLEMENTATION -----
.CODE

Vector2Set PROTO :BPPtr, :REAL4, :REAL4
Vector3Set PROTO :BPPtr, :REAL4, :REAL4, :REAL4

;   Internal macro for Vector3 2D. Checks if Cnt is <32D>, if so, sets CntRep to
; 2 and OffSize to REAL4*2 to skip Y.
Vector32DCheck MACRO Cnt:REQ, RetCnt:REQ
	CntTxt TEXTEQU <Cnt>
	IFIDNI CntTxt, <32D>
		CntRep = 2
		OffSize = SIZEOF REAL4*2
	ELSE
		CntRep = Cnt
		OffSize = SIZEOF REAL4
	ENDIF
	IF RetCnt EQ 0
		EXITM <OffSize>
	ELSE
		EXITM <CntRep>
	ENDIF
ENDM
; ----- Generic VectorN macros -----
VectorAdd MACRO Cnt:REQ, A:REQ, B:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fadd REAL4 PTR [pcx+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorCopy MACRO Cnt:REQ, To:REQ, From:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, From
	PosOff = 0
	REPEAT CntRep
		IFDEF rax
			mov ecx, REAL4 PTR [pax+PosOff]
			push rcx
		ELSE
			push REAL4 PTR [pax+PosOff]
		ENDIF
		PosOff = PosOff + OffSize
	ENDM
	mov pax, To
	PosOff = (CntRep-1) * OffSize
	REPEAT CntRep
		IFDEF rax
			pop rcx
			mov REAL4 PTR [pax+PosOff], ecx
		ELSE
			pop REAL4 PTR [pax+PosOff]
		ENDIF
		PosOff = PosOff - OffSize
	ENDM
ENDM

VectorDistanceSqr MACRO Cnt:REQ, A:REQ, B:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pcx+PosOff]
		fsub REAL4 PTR [pax+PosOff]
		fmul st, st
		PosOff = PosOff + OffSize
	ENDM
	REPEAT CntRep-1
		fadd
	ENDM
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

VectorF MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fild DWORD PTR [pax+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorLength MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fmul st, st
		PosOff = PosOff + OffSize
	ENDM
	REPEAT CntRep-1
		fadd
	ENDM
	fsqrt
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

VectorLengthSqr MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fmul st, st
		PosOff = PosOff + OffSize
	ENDM
	REPEAT CntRep-1
		fadd
	ENDM
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

VectorLerp MACRO Cnt:REQ, A:REQ, B:REQ, T:REQ
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			VectorCopy Cnt, A, B
			ret
		.ENDIF
	ENDIF
	
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pcx+PosOff]
		fsub REAL4 PTR [pax+PosOff]
		fmul T
		fadd REAL4 PTR [pax+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM	
ENDM

VectorMul MACRO Cnt:REQ, A:REQ, B:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fmul REAL4 PTR [pcx+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorMulF MACRO Cnt:REQ, A:REQ, B:REQ
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fmul B
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorNegate MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		xor REAL4 PTR [pax+PosOff], 80000000h
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorNormalize MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	VectorLengthSqr Cnt, A
	.IF (!eax)
		mov pax, A
		PosOff = 0
		REPEAT CntRep
			mov REAL4 PTR [pax+PosOff], 0
			PosOff = PosOff + OffSize
		ENDM
		ret
	.ENDIF
	push pax
	fld REAL4 PTR [psp]
	fsqrt
	fstp REAL4 PTR [psp]
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fdiv REAL4 PTR [psp]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
	add psp, SIZEOF BPPtr
ENDM

VectorRound MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fld DWORD PTR [pax+PosOff]
		frndint
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorRoundInt MACRO Cnt:REQ, A:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fistp DWORD PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

VectorSet MACRO A:REQ, Coords:VARARG
	mov pax, A
	PosOff = 0
	FOR Coord, <Coords>
		IFDEF rax
			mov ecx, Coord
			mov REAL4 PTR [pax+PosOff], ecx
		ELSE
			push Coord
			pop REAL4 PTR [pax+PosOff]
		ENDIF
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorSub MACRO Cnt:REQ, A:REQ, B:REQ
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT CntRep
		fld REAL4 PTR [pax+PosOff]
		fsub REAL4 PTR [pcx+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + OffSize
	ENDM
ENDM

; ----- Vector2 -----
Vector2Pop MACRO A:REQ
	bpPop32 A.X
	bpPop32 A.Y
ENDM

Vector2Print MACRO A:REQ
	print real4$(A.X), 9
	print real4$(A.Y), 13, 10
ENDM

Vector2Push MACRO A:REQ
	bpPush32 A.Y
	bpPush32 A.X
ENDM

Vector2Add PROC EXPORT A:BPPtr, B:BPPtr
	VectorAdd 2, A, B
	ret
Vector2Add ENDP

Vector2Angle PROC EXPORT From:BPPtr, To:BPPtr
	LOCAL Val:REAL4
	mov pax, From
	mov pcx, To
	
	fld REAL4 PTR [pcx+4]
	fsub REAL4 PTR [pax+4]
	fld REAL4 PTR [pcx]
	fsub REAL4 PTR [pax]
	fpatan
	fstp Val
	
	mov eax, Val
	ret
Vector2Angle ENDP

Vector2Copy PROC EXPORT To:BPPtr, From:BPPtr
	VectorCopy 2, To, From
	ret
Vector2Copy ENDP

Vector2Cross PROC EXPORT A:BPPtr, B:BPPtr
	LOCAL Val:REAL4
	mov pax, A
	mov pcx, B
	
	fld REAL4 PTR [pax]
	fmul REAL4 PTR [pcx+4]
	fld REAL4 PTR [pax+4]
	fmul REAL4 PTR [pcx]
	fsub
	fstp Val
	mov eax, Val
	ret
Vector2Cross ENDP

Vector2Dot PROC EXPORT A:BPPtr, B:BPPtr
	LOCAL Val:REAL4
	mov pax, A
	mov pcx, B
	
	fld REAL4 PTR [pax]
	fmul REAL4 PTR [pcx]
	fld REAL4 PTR [pax+4]
	fmul REAL4 PTR [pcx+4]
	fadd
	fstp Val
	mov eax, Val
	ret
Vector2Dot ENDP

Vector2DistanceSqr PROC EXPORT A:BPPtr, B:BPPtr
	VectorDistanceSqr 2, A, B
	ret
Vector2DistanceSqr ENDP

Vector2F PROC EXPORT A:BPPtr
	VectorF 2, A
	ret
Vector2F ENDP

Vector2LengthSqr PROC EXPORT A:BPPtr
	VectorLengthSqr 2, A
	ret
Vector2LengthSqr ENDP

Vector2Lerp PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 2, A, B, T
	ret
Vector2Lerp ENDP

Vector2Mul PROC EXPORT A:BPPtr, B:BPPtr
	VectorMul 2, A, B
	ret
Vector2Mul ENDP

Vector2MulF PROC EXPORT A:BPPtr, B:REAL4
	VectorMulF 2, A, B
	ret
Vector2MulF ENDP

Vector2Negate PROC EXPORT A:BPPtr
	VectorNegate 2, A
	ret
Vector2Negate ENDP

Vector2Normalize PROC EXPORT A:BPPtr
	VectorNormalize 2, A
	ret
Vector2Normalize ENDP

Vector2RoundInt PROC EXPORT A:BPPtr
	VectorRoundInt 2, A
	ret
Vector2RoundInt ENDP

Vector2Set PROC EXPORT A:BPPtr, X:REAL4, Y:REAL4
	VectorSet A, X, Y
	ret
Vector2Set ENDP

Vector2Sub PROC EXPORT A:BPPtr, B:BPPtr
	VectorSub 2, A, B
	ret
Vector2Sub ENDP

; ----- Vector3 -----
Vector3Pop MACRO A:REQ
	bpPop32 A.X
	bpPop32 A.Y
	bpPop32 A.Z
ENDM

Vector3Print MACRO A:REQ
	print real4$(A.X), 9
	print real4$(A.Y), 9
	print real4$(A.Z), 13, 10
ENDM

Vector3Push MACRO A:REQ
	bpPush32 A.Z
	bpPush32 A.Y
	bpPush32 A.X
ENDM

Vector3Add PROC EXPORT A:BPPtr, B:BPPtr
	VectorAdd 3, A, B
	ret
Vector3Add ENDP

Vector3Angle PROC EXPORT From:BPPtr, To:BPPtr, Angle:BPPtr
	LOCAL d2d:Vector2
	mov pax, From
	mov pcx, To
	mov pdx, Angle
	
	fld REAL4 PTR [pcx]
	fsub REAL4 PTR [pax]
	fst d2d.X
	fld REAL4 PTR [pcx+8]
	fsub REAL4 PTR [pax+8]
	fst d2d.Y
	fpatan
	fstp REAL4 PTR [pdx+4]
	
	fld REAL4 PTR [pcx+4]	; ????????
	fsub REAL4 PTR [pax+4]
	fchs
	fld d2d.X
	fmul st, st
	fld d2d.Y
	fmul st, st
	fadd
	fsqrt
	fpatan
	fstp REAL4 PTR [pdx]
	ret
Vector3Angle ENDP

Vector3Copy PROC EXPORT To:BPPtr, From:BPPtr
	VectorCopy 3, To, From
	ret
Vector3Copy ENDP

Vector3Cross PROC EXPORT A:BPPtr, B:BPPtr, Product:BPPtr
	mov pax, A
	mov pcx, B
	mov pdx, Product
	
	fld REAL4 PTR [pax+4]	; A.Y * B.Z
	fmul REAL4 PTR [pcx+8]
	fld REAL4 PTR [pax+8]	; A.Z * B.Y
	fmul REAL4 PTR [pcx+4]
	fsub					; A.Y * B.Z - A.Z * B.Y
	fstp REAL4 PTR [pdx]	; into Product.X
	
	fld REAL4 PTR [pax+8]	; A.Z * B.X
	fmul REAL4 PTR [pcx]
	fld REAL4 PTR [pax]		; A.X * B.Z
	fmul REAL4 PTR [pcx+8]
	fsub					; A.Z * B.X - A.X * B.Z
	fstp REAL4 PTR [pdx+4]	; into Product.Y
	
	fld REAL4 PTR [pax]		; A.X * B.Y
	fmul REAL4 PTR [pcx+4]
	fld REAL4 PTR [pax+4]	; A.Y * B.X
	fmul REAL4 PTR [pcx]
	fsub					; A.X * B.Y - A.Y * B.X
	fstp REAL4 PTR [pdx+8]	; into Product.Z
	
	ret
Vector3Cross ENDP

Vector3DistanceSqr PROC EXPORT A:BPPtr, B:BPPtr
	VectorDistanceSqr 3, A, B
	ret
Vector3DistanceSqr ENDP

Vector3F PROC EXPORT A:BPPtr
	VectorF 3, A
	ret
Vector3F ENDP

Vector3Length PROC EXPORT A:BPPtr
	VectorLength 3, A
	ret
Vector3Length ENDP

Vector3LengthSqr PROC EXPORT A:BPPtr
	VectorLengthSqr 3, A
	ret
Vector3LengthSqr ENDP

Vector3Lerp PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 3, A, B, T
	ret
Vector3Lerp ENDP

Vector3Mul PROC EXPORT A:BPPtr, B:BPPtr
	VectorMul 3, A, B
	ret
Vector3Mul ENDP

Vector3MulF PROC EXPORT A:BPPtr, B:REAL4
	VectorMulF 3, A, B
	ret
Vector3MulF ENDP

Vector3Negate PROC EXPORT A:BPPtr
	VectorNegate 3, A
	ret
Vector3Negate ENDP

Vector3Normalize PROC EXPORT A:BPPtr
	VectorNormalize 3, A
	ret
Vector3Normalize ENDP

Vector3Round PROC EXPORT A:BPPtr
	VectorRound 3, A
	ret
Vector3Round ENDP

Vector3RoundInt PROC EXPORT A:BPPtr
	VectorRoundInt 3, A
	ret
Vector3RoundInt ENDP

Vector3Set PROC EXPORT A:BPPtr, X:REAL4, Y:REAL4, Z:REAL4
	VectorSet A, X, Y, Z
	ret
Vector3Set ENDP

Vector3Sub PROC EXPORT A:BPPtr, B:BPPtr
	VectorSub 3, A, B
	ret
Vector3Sub ENDP

; ----- Vector3 2D (X, Z) -----
Vector32DPop MACRO A:REQ
	bpPop32 A.X
	bpPop32 A.Z
ENDM

Vector32DPrint MACRO A:REQ
	print real4$(A.X), 9
	print real4$(A.Z), 13, 10
ENDM

Vector32DPush MACRO A:REQ
	bpPush32 A.Z
	bpPush32 A.X
ENDM

Vector32DAngle PROC EXPORT From:BPPtr, To:BPPtr
	LOCAL Val:REAL4
	
	mov pax, From
	mov pcx, To
	
	fld REAL4 PTR [pcx]
	fsub REAL4 PTR [pax]
	fld REAL4 PTR [pcx+8]
	fsub REAL4 PTR [pax+8]
	fpatan
	fstp Val
	
	mov eax, Val
	ret
Vector32DAngle ENDP

Vector32DAdd PROC EXPORT A:BPPtr, B:BPPtr
	VectorAdd 32D, A, B
	ret
Vector32DAdd ENDP

Vector32DCopy PROC EXPORT To:BPPtr, From:BPPtr
	VectorCopy 32D, To, From
	ret
Vector32DCopy ENDP

Vector32DDistanceSqr PROC EXPORT A:BPPtr, B:BPPtr
	VectorDistanceSqr 32D, A, B
	ret
Vector32DDistanceSqr ENDP

Vector32DF PROC EXPORT A:BPPtr
	VectorF 32D, A
	ret
Vector32DF ENDP

Vector32DLength PROC EXPORT A:BPPtr
	VectorLength 32D, A
	ret
Vector32DLength ENDP

Vector32DLengthSqr PROC EXPORT A:BPPtr
	VectorLengthSqr 32D, A
	ret
Vector32DLengthSqr ENDP

Vector32DLerp PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 32D, A, B, T
	ret
Vector32DLerp ENDP

Vector32DMul PROC EXPORT A:BPPtr, B:BPPtr
	VectorMul 32D, A, B
	ret
Vector32DMul ENDP

Vector32DMulF PROC EXPORT A:BPPtr, B:REAL4
	VectorMulF 32D, A, B
	ret
Vector32DMulF ENDP

Vector32DNegate PROC EXPORT A:BPPtr
	VectorNegate 32D, A
	ret
Vector32DNegate ENDP

Vector32DNormalize PROC EXPORT A:BPPtr
	VectorNormalize 32D, A
	ret
Vector32DNormalize ENDP

Vector32DRound PROC EXPORT A:BPPtr
	VectorRound 32D, A
	ret
Vector32DRound ENDP

Vector32DRoundInt PROC EXPORT A:BPPtr
	VectorRoundInt 32D, A
	ret
Vector32DRoundInt ENDP

Vector32DSet PROC EXPORT A:BPPtr, X:REAL4, Z:REAL4
	mov pax, A
	IFDEF rax
		mov ecx, X
		mov REAL4 PTR [pax], ecx
		mov ecx, Z
		mov REAL4 PTR [pax+8], ecx
	ELSE
		push X
		pop REAL4 PTR [pax]
		push Z
		pop REAL4 PTR [pax+8]
	ENDIF
	ret
Vector32DSet ENDP

Vector32DSub PROC EXPORT A:BPPtr, B:BPPtr
	VectorSub 32D, A, B
	ret
Vector32DSub ENDP


; ----- Vector4 -----
Vector4Print MACRO A:REQ
	print real4$(A.X), 9
	print real4$(A.Y), 9
	print real4$(A.Z), 9
	print real4$(A.W), 13, 10
ENDM

Vector4Add PROC EXPORT A:BPPtr, B:BPPtr
	VectorAdd 4, A, B
	ret
Vector4Add ENDP

Vector4Copy PROC EXPORT To:BPPtr, From:BPPtr
	VectorCopy 4, To, From
	ret
Vector4Copy ENDP

Vector4DistanceSqr PROC EXPORT A:BPPtr, B:BPPtr
	VectorDistanceSqr 4, A, B
	ret
Vector4DistanceSqr ENDP

Vector4F PROC EXPORT A:BPPtr
	VectorF 4, A
	ret
Vector4F ENDP

Vector4Length PROC EXPORT A:BPPtr
	VectorLength 4, A
	ret
Vector4Length ENDP

Vector4LengthSqr PROC EXPORT A:BPPtr
	VectorLengthSqr 4, A
	ret
Vector4LengthSqr ENDP

Vector4Lerp PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 4, A, B, T
	ret
Vector4Lerp ENDP

Vector4Mul PROC EXPORT A:BPPtr, B:BPPtr
	VectorMul 4, A, B
	ret
Vector4Mul ENDP

Vector4MulF PROC EXPORT A:BPPtr, B:REAL4
	VectorMulF 4, A, B
	ret
Vector4MulF ENDP

Vector4Negate PROC EXPORT A:BPPtr
	VectorNegate 4, A
	ret
Vector4Negate ENDP

Vector4Normalize PROC EXPORT A:BPPtr
	VectorNormalize 4, A
	ret
Vector4Normalize ENDP

Vector4RoundInt PROC EXPORT A:BPPtr
	VectorRoundInt 4, A
	ret
Vector4RoundInt ENDP

Vector4Set PROC EXPORT A:BPPtr, X:REAL4, Y:REAL4, Z:REAL4, W:REAL4
	VectorSet A, X, Y, Z, W
	ret
Vector4Set ENDP

Vector4Sub PROC EXPORT A:BPPtr, B:BPPtr
	VectorSub 4, A, B
	ret
Vector4Sub ENDP

IFDEF BP3D_MATHS_INC
VectorClampLength MACRO Cnt:REQ, A:REQ, Len:REQ	
	VectorLength Cnt, A
	
	CntRep = Vector32DCheck(Cnt, 1)
	OffSize = Vector32DCheck(Cnt, 0)
	
	push pax
	.IF (REAL4 PTR [psp])
		fcmp Len, REAL4 PTR [psp]
		.IF (Carry?)
			mov pax, A
			PosOff = 0
			REPEAT CntRep
				fld REAL4 PTR [pax+PosOff]
				fdiv REAL4 PTR [psp]
				fmul Len
				fstp REAL4 PTR [pax+PosOff]
				PosOff = PosOff + OffSize
			ENDM
		.ENDIF
	.ENDIF
	pop pax
ENDM

Vector2ClampLength PROC EXPORT A:BPPtr, Len:REAL4
	VectorClampLength 2, A, Len
	ret
Vector2ClampLength ENDP

Vector3ClampLength PROC EXPORT A:BPPtr, Len:REAL4
	VectorClampLength 3, A, Len
	ret
Vector3ClampLength ENDP

Vector32DClampLength PROC EXPORT A:BPPtr, Len:REAL4
	VectorClampLength 32D, A, Len
	ret
Vector32DClampLength ENDP

Vector4ClampLength PROC EXPORT A:BPPtr, Len:REAL4
	VectorClampLength 4, A, Len
	ret
Vector4ClampLength ENDP

Vector2LerpAngle PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			invoke Vector2Copy, A, B
			ret
		.ENDIF
	ENDIF
	
	mov pdx, A
	mov pcx, B
	
	invoke flLerpAngle, REAL4 PTR [pdx], REAL4 PTR [pcx], T
	mov REAL4 PTR [pdx], eax
	invoke flLerpAngle, REAL4 PTR [pdx+4], REAL4 PTR [pcx+4], T
	mov REAL4 PTR [pdx+4], eax
		
	ret
Vector2LerpAngle ENDP

Vector3LerpAngle PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			invoke Vector3Copy, A, B
			ret
		.ENDIF
	ENDIF
	
	mov pdx, A
	mov pcx, B
	
	invoke flLerpAngle, REAL4 PTR [pdx], REAL4 PTR [pcx], T
	mov REAL4 PTR [pdx], eax
	invoke flLerpAngle, REAL4 PTR [pdx+4], REAL4 PTR [pcx+4], T
	mov REAL4 PTR [pdx+4], eax
	invoke flLerpAngle, REAL4 PTR [pdx+8], REAL4 PTR [pcx+8], T
	mov REAL4 PTR [pdx+8], eax
		
	ret
Vector3LerpAngle ENDP

Vector32DLerpAngle PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			invoke Vector32DCopy, A, B
			ret
		.ENDIF
	ENDIF
	mov pdx, A
	mov pcx, B
	
	invoke flLerpAngle, REAL4 PTR [pdx], REAL4 PTR [pcx], T
	mov REAL4 PTR [pdx], eax
	invoke flLerpAngle, REAL4 PTR [pdx+8], REAL4 PTR [pcx+8], T
	mov REAL4 PTR [pdx+8], eax
	ret
Vector32DLerpAngle ENDP

Vector3Euler PROC EXPORT A:BPPtr
	mov pcx, A
	invoke flAngle, REAL4 PTR [pcx]
	mov REAL4 PTR [pcx], eax
	invoke flAngle, REAL4 PTR [pcx+4]
	mov REAL4 PTR [pcx+4], eax
	invoke flAngle, REAL4 PTR [pcx+8]
	mov REAL4 PTR [pcx+8], eax
	ret
Vector3Euler ENDP

Vector3Move PROC EXPORT From:BPPtr, To:BPPtr, T:REAL4
	mov pdx, From
	mov pcx, To
	invoke flMove, REAL4 PTR [pdx], REAL4 PTR [pcx], T
	mov REAL4 PTR [pdx], eax
	invoke flMove, REAL4 PTR [pdx+4], REAL4 PTR [pcx+4], T
	mov REAL4 PTR [pdx+4], eax
	invoke flMove, REAL4 PTR [pdx+8], REAL4 PTR [pcx+8], T
	mov REAL4 PTR [pdx+8], eax
	ret
Vector3Move ENDP

Vector32DMove PROC EXPORT From:BPPtr, To:BPPtr, T:REAL4
	mov pdx, From
	mov pcx, To
	invoke flMove, REAL4 PTR [pdx], REAL4 PTR [pcx], T
	mov REAL4 PTR [pdx], eax
	invoke flMove, REAL4 PTR [pdx+8], REAL4 PTR [pcx+8], T
	mov REAL4 PTR [pdx+8], eax
	ret
Vector32DMove ENDP

ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DVectors.inc
ENDIF