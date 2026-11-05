;
;   BP3DVectors.inc
;   Version 0.8bc1
;   BP3D common vector (2D, 3D, 4D) functions extension.
;   Is available for independent importing without main BP3D. Importing after
; BP3DMaths provides extended functionality.
;   Most of the functions are generalized in macros, except: VectorAngle,
; VectorCross.
;
;   Copyright (c) 2025-2026 Yevhenii Ionenko (aka GreatCorn).
;   All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_VECTORS_INC
BP3D_VECTORS_INC EQU <1>

IFNDEF BP3D_TYPEDEF_INC
	include BP3DTypedef.inc
ENDIF

IFNDEF BP3D_MATHS_INC
	BP_LERP_UNCLAMPED EQU <1>
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
Vector4One		Vector4 <1.0, 1.0, 1.0, 1.0>
Vector4Zero		Vector4 <0.0, 0.0, 0.0, 0.0>

; ----- IMPLEMENTATION -----
.CODE

Vector2Add				PROTO :BPPtr, :BPPtr
Vector2Angle			PROTO :BPPtr, :BPPtr
Vector2Copy				PROTO :BPPtr, :BPPtr
Vector2Cross			PROTO :BPPtr, :BPPtr
Vector2Dot				PROTO :BPPtr, :BPPtr
Vector2Distance			PROTO :BPPtr, :BPPtr
Vector2DistanceSqr		PROTO :BPPtr, :BPPtr
Vector2F				PROTO :BPPtr
Vector2Length			PROTO :BPPtr
Vector2LengthSqr		PROTO :BPPtr
Vector2Lerp				PROTO :BPPtr, :BPPtr, :REAL4
Vector2Mul				PROTO :BPPtr, :BPPtr
Vector2MulF 			PROTO :BPPtr, :REAL4
Vector2Negate			PROTO :BPPtr
Vector2Normalize		PROTO :BPPtr
Vector2Round			PROTO :BPPtr
Vector2RoundInt			PROTO :BPPtr
Vector2Set				PROTO :BPPtr, :REAL4, :REAL4
Vector2Sub				PROTO :BPPtr, :BPPtr

Vector3Add				PROTO :BPPtr, :BPPtr
Vector3Angle			PROTO :BPPtr, :BPPtr, :BPPtr
Vector3Copy				PROTO :BPPtr, :BPPtr
Vector3Cross			PROTO :BPPtr, :BPPtr, :BPPtr
Vector3Dot				PROTO :BPPtr, :BPPtr
Vector2Distance			PROTO :BPPtr, :BPPtr
Vector3DistanceSqr		PROTO :BPPtr, :BPPtr
Vector3F				PROTO :BPPtr
Vector3Length			PROTO :BPPtr
Vector3LengthSqr		PROTO :BPPtr
Vector3Lerp				PROTO :BPPtr, :BPPtr, :REAL4
Vector3Mul				PROTO :BPPtr, :BPPtr
Vector3MulF 			PROTO :BPPtr, :REAL4
Vector3Negate			PROTO :BPPtr
Vector3Normalize		PROTO :BPPtr
Vector3Round			PROTO :BPPtr
Vector3RoundInt			PROTO :BPPtr
Vector3Set				PROTO :BPPtr, :REAL4, :REAL4, :REAL4
Vector3Sub				PROTO :BPPtr, :BPPtr

Vector32DAdd			PROTO :BPPtr, :BPPtr
Vector32DAngle			PROTO :BPPtr, :BPPtr
Vector32DCopy			PROTO :BPPtr, :BPPtr
Vector32DCross			PROTO :BPPtr, :BPPtr
Vector32DDot			PROTO :BPPtr, :BPPtr
Vector32DDistance		PROTO :BPPtr, :BPPtr
Vector32DDistanceSqr	PROTO :BPPtr, :BPPtr
Vector32DF				PROTO :BPPtr
Vector32DLength			PROTO :BPPtr
Vector32DLengthSqr		PROTO :BPPtr
Vector32DLerp			PROTO :BPPtr, :BPPtr, :REAL4
Vector32DMul			PROTO :BPPtr, :BPPtr
Vector32DMulF 			PROTO :BPPtr, :REAL4
Vector32DNegate			PROTO :BPPtr
Vector32DNormalize		PROTO :BPPtr
Vector32DRound			PROTO :BPPtr
Vector32DRoundInt		PROTO :BPPtr
Vector32DSet			PROTO :BPPtr, :REAL4, :REAL4
Vector32DSub			PROTO :BPPtr, :BPPtr

Vector4Add				PROTO :BPPtr, :BPPtr
Vector4Copy				PROTO :BPPtr, :BPPtr
Vector4Dot				PROTO :BPPtr, :BPPtr
Vector4Distance			PROTO :BPPtr, :BPPtr
Vector4DistanceSqr		PROTO :BPPtr, :BPPtr
Vector4F				PROTO :BPPtr
Vector4Length			PROTO :BPPtr
Vector4LengthSqr		PROTO :BPPtr
Vector4Lerp				PROTO :BPPtr, :BPPtr, :REAL4
Vector4Mul				PROTO :BPPtr, :BPPtr
Vector4MulF 			PROTO :BPPtr, :REAL4
Vector4Negate			PROTO :BPPtr
Vector4Normalize		PROTO :BPPtr
Vector4Round			PROTO :BPPtr
Vector4RoundInt			PROTO :BPPtr
Vector4Set				PROTO :BPPtr, :REAL4, :REAL4, :REAL4, :REAL4
Vector4Sub				PROTO :BPPtr, :BPPtr

IFDEF BP3D_MATHS_INC
Vector2ClampLength		PROTO :BPPtr, :REAL4
Vector2Euler			PROTO :BPPtr
Vector2LerpAngle		PROTO :BPPtr, :BPPtr, :REAL4
Vector2Move				PROTO :BPPtr, :BPPtr, :REAL4
Vector2MoveEach			PROTO :BPPtr, :BPPtr, :REAL4

Vector3ClampLength		PROTO :BPPtr, :REAL4
Vector3Euler			PROTO :BPPtr
Vector3LerpAngle		PROTO :BPPtr, :BPPtr, :REAL4
Vector3Move				PROTO :BPPtr, :BPPtr, :REAL4
Vector3MoveEach			PROTO :BPPtr, :BPPtr, :REAL4

Vector32DClampLength	PROTO :BPPtr, :REAL4
Vector32DEuler			PROTO :BPPtr
Vector32DLerpAngle		PROTO :BPPtr, :BPPtr, :REAL4
Vector32DMove			PROTO :BPPtr, :BPPtr, :REAL4
Vector32DMoveEach		PROTO :BPPtr, :BPPtr, :REAL4

Vector4ClampLength		PROTO :BPPtr, :REAL4
Vector4Euler			PROTO :BPPtr
Vector4LerpAngle		PROTO :BPPtr, :BPPtr, :REAL4
Vector4Move				PROTO :BPPtr, :BPPtr, :REAL4
Vector4MoveEach			PROTO :BPPtr, :BPPtr, :REAL4
ENDIF

;   Internal macro for Vector3 2D. Checks if Cnt is <32D>, if so, sets _bpCntRep
; to 2 and _bpOffSize to REAL4*2 to skip Y.
Vector32DCheck MACRO Cnt:REQ, RetCnt:REQ
	_bpCntTxt TEXTEQU <Cnt>
	IFIDNI _bpCntTxt, <32D>
		_bpCntRep = 2
		_bpOffSize = SIZEOF REAL4*2
	ELSE
		_bpCntRep = Cnt
		_bpOffSize = SIZEOF REAL4
	ENDIF
	IF RetCnt EQ 0
		EXITM %_bpOffSize
	ELSE
		EXITM %_bpCntRep
	ENDIF
ENDM


; ----- Generic VectorN macros -----
;   You can find most of the vector methods here, except the ones explicitly
; mentioned in the header. As the macros use pointer arithmetics rather than
; explicit field name referencing, functions that expect smaller vector
; structures can be used on larger ones (e.g. Vector2* on a Vector3 structure),
; as well as on untyped memory sequences.
;   The generic macro structure is messy, but the gist is that it passes the
; element count (Cnt (=2, 3, 32D, 4)) to Vector32DCheck to get the amount of
; fields to operate on (_bpCntRep) and the offset size (_bpOffSize) to add to
; the current position offset (_bpPosOff) in the repeat macro loops. The latter
; is to allow for Vector32D (X, Z) functionality.
;   A lot of the functions use the first passed VectorN pointer as an out
; parameter to modify directly, rather than having a separate return struct
; passed to them. Some specific cases have functions return a single REAL4 value
; into eax (e.g. VectorLength) and some others have a separate out VectorN 
; argument (e.g. Vector3Angle).

;   Add two vectors.
;   A:BPPtr - out pointer to first VectorN.
;   B:BPPtr - pointer to second VectorN.
VectorAdd MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fadd REAL4 PTR [pcx+_bpPosOff]
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Copy one vector's values to another.
;   To:BPPtr - out pointer to the VectorN to copy to.
;   From:BPPtr - pointer to the VectorN to copy from.
VectorCopy MACRO Cnt:REQ, To:REQ, From:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, From
	_bpPosOff = 0
	REPEAT _bpCntRep
		IFDEF rax
			mov ecx, REAL4 PTR [pax+_bpPosOff]
			push rcx
		ELSE
			push REAL4 PTR [pax+_bpPosOff]
		ENDIF
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	mov pax, To
	_bpPosOff = (_bpCntRep-1) * _bpOffSize
	REPEAT _bpCntRep
		IFDEF rax
			pop rcx
			mov REAL4 PTR [pax+_bpPosOff], ecx
		ELSE
			pop REAL4 PTR [pax+_bpPosOff]
		ENDIF
		_bpPosOff = _bpPosOff - _bpOffSize
	ENDM
ENDM

;   Calculate distance from two vectors and return it in eax. This uses sqrt,
; when distance is needed for comparing, it's better to use VectorDistanceSqr.
;   A:BPPtr - pointer to the first VectorN.
;   B:BPPtr - pointer to the second VectorN.
VectorDistance MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pcx+_bpPosOff]
		fsub REAL4 PTR [pax+_bpPosOff]
		fmul st, st
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	REPEAT _bpCntRep-1
		fadd
	ENDM
	fsqrt
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

;   Calculate squared distance from two vectors and return it in eax.
;   A:BPPtr - pointer to the first VectorN.
;   B:BPPtr - pointer to the second VectorN.
VectorDistanceSqr MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pcx+_bpPosOff]
		fsub REAL4 PTR [pax+_bpPosOff]
		fmul st, st
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	REPEAT _bpCntRep-1
		fadd
	ENDM
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

;   Calculate dot product between two vectors and return it in eax.
;   A:BPPtr - pointer to the first VectorN.
;   B:BPPtr - pointer to the second VectorN.
VectorDot MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fmul REAL4 PTR [pcx+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	REPEAT _bpCntRep-1
		fadd
	ENDM
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

;   Convert the vector's fields from integers (SDWORD) into floats (REAL4).
;   A:BPPtr - out pointer to the VectorN to convert.
VectorF MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fild SDWORD PTR [pax+_bpPosOff]
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Calculate a vector's length (magnitude) and return it in eax. This uses
; sqrt, when length is needed for comparing, it's better to use VectorLengthSqr.
;   A:BPPtr - pointer to the VectorN.
VectorLength MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fmul st, st
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	REPEAT _bpCntRep-1
		fadd
	ENDM
	fsqrt
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

;   Calculate a vector's squared length (magnitude) and returns it in eax.
;   A:BPPtr - pointer to the VectorN.
VectorLengthSqr MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fmul st, st
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	REPEAT _bpCntRep-1
		fadd
	ENDM
	sub psp, SIZEOF BPPtr
	fstp REAL4 PTR [psp]
	pop pax
ENDM

;   Do linear interpolation from one vector towards another by T. If
; BP3DMaths.inc is included before this module, clamps T by default (see
; BP3DMaths.inc -> BP_LERP_UNCLAMPED).
;   A:BPPtr - out pointer to the starting VectorN.
;   B:BPPtr - pointer to the destination VectorN.
;   T:REAL4 - interpolation value between the two.
VectorLerp MACRO Cnt:REQ, A:REQ, B:REQ, T:REQ
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			VectorCopy Cnt, A, B
			ret
		.ENDIF
	ENDIF
	
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pcx+_bpPosOff]
		fsub REAL4 PTR [pax+_bpPosOff]
		fmul T
		fadd REAL4 PTR [pax+_bpPosOff]
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM	
ENDM

;   Multiply two vectors.
;   A:BPPtr - out pointer to first VectorN.
;   B:BPPtr - pointer to second VectorN.
VectorMul MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fmul REAL4 PTR [pcx+_bpPosOff]
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Multiply each field of a vector by a common value.
;   A:BPPtr - out pointer to VectorN.
;   B:REAL4 - multiplication value.
VectorMulF MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fmul B
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Negate a vector (*-1).
;   A:BPPtr - out pointer to the VectorN to negate.
VectorNegate MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		xor REAL4 PTR [pax+_bpPosOff], 80000000h
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Normalize a vector (scale to unit length).
;   A:BPPtr - out pointer to the VectorN to normalize.
VectorNormalize MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	VectorLengthSqr Cnt, A
	.IF (!eax)
		mov pax, A
		_bpPosOff = 0
		REPEAT _bpCntRep
			mov REAL4 PTR [pax+_bpPosOff], 0
			_bpPosOff = _bpPosOff + _bpOffSize
		ENDM
		ret
	.ENDIF
	push pax
	fld REAL4 PTR [psp]
	fsqrt
	fstp REAL4 PTR [psp]
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fdiv REAL4 PTR [psp]
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	add psp, SIZEOF BPPtr
ENDM

;   Round a vector without converting to integer (uses current FPU rounding
; mode).
;   A:BPPtr - out pointer to the VectorN to round.
VectorRound MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		frndint
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Round a vector with converting to integer (uses current FPU rounding mode).
;   A:BPPtr - out pointer to the VectorN to round.
VectorRoundInt MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fistp SDWORD PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Set the vector's fields.
;   A:BPPtr - out pointer to the VectorN.
;   Coords[N]:REAL4 - field values (X, Y, Z, W).
VectorSet MACRO A:REQ, Coords:VARARG
	mov pax, A
	_bpPosOff = 0
	FOR Coord, <Coords>
		IFDEF rax
			mov ecx, Coord
			mov REAL4 PTR [pax+_bpPosOff], ecx
		ELSE
			push Coord
			pop REAL4 PTR [pax+_bpPosOff]
		ENDIF
		_bpPosOff = _bpPosOff + SIZEOF REAL4
	ENDM
ENDM

;   Subtract one vector from another.
;   A:BPPtr - out pointer to first VectorN to subtract from.
;   B:BPPtr - pointer to second VectorN.
VectorSub MACRO Cnt:REQ, A:REQ, B:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pax, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pax+_bpPosOff]
		fsub REAL4 PTR [pcx+_bpPosOff]
		fstp REAL4 PTR [pax+_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
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

Vector2Add BPPROC A:BPPtr, B:BPPtr
	VectorAdd 2, A, B
	ret
Vector2Add ENDP

;   Find angle (in radians) from one Vector2 to another and return it in eax.
;   From:BPPtr - pointer to first Vector2.
;   To:BPPtr - pointer to second Vector2.
Vector2Angle BPPROC From:BPPtr, To:BPPtr
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

Vector2Copy BPPROC To:BPPtr, From:BPPtr
	VectorCopy 2, To, From
	ret
Vector2Copy ENDP

;   Calculate cross product between two Vector2 and return it in eax.
;   A:BPPtr - pointer to first Vector2.
;   B:BPPtr - pointer to second Vector2.
Vector2Cross BPPROC A:BPPtr, B:BPPtr
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

Vector2Dot BPPROC A:BPPtr, B:BPPtr
	VectorDot 2, A, B
	ret
Vector2Dot ENDP

Vector2Distance BPPROC A:BPPtr, B:BPPtr
	VectorDistance 2, A, B
	ret
Vector2Distance ENDP

Vector2DistanceSqr BPPROC A:BPPtr, B:BPPtr
	VectorDistanceSqr 2, A, B
	ret
Vector2DistanceSqr ENDP

Vector2F BPPROC A:BPPtr
	VectorF 2, A
	ret
Vector2F ENDP

Vector2Length BPPROC A:BPPtr
	VectorLength 2, A
	ret
Vector2Length ENDP

Vector2LengthSqr BPPROC A:BPPtr
	VectorLengthSqr 2, A
	ret
Vector2LengthSqr ENDP

Vector2Lerp BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 2, A, B, T
	ret
Vector2Lerp ENDP

Vector2Mul BPPROC A:BPPtr, B:BPPtr
	VectorMul 2, A, B
	ret
Vector2Mul ENDP

Vector2MulF BPPROC A:BPPtr, B:REAL4
	VectorMulF 2, A, B
	ret
Vector2MulF ENDP

Vector2Negate BPPROC A:BPPtr
	VectorNegate 2, A
	ret
Vector2Negate ENDP

Vector2Normalize BPPROC A:BPPtr
	VectorNormalize 2, A
	ret
Vector2Normalize ENDP

Vector2Round BPPROC A:BPPtr
	VectorRound 2, A
	ret
Vector2Round ENDP

Vector2RoundInt BPPROC A:BPPtr
	VectorRoundInt 2, A
	ret
Vector2RoundInt ENDP

Vector2Set BPPROC A:BPPtr, X:REAL4, Y:REAL4
	VectorSet A, X, Y
	ret
Vector2Set ENDP

Vector2Sub BPPROC A:BPPtr, B:BPPtr
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

Vector3Add BPPROC A:BPPtr, B:BPPtr
	VectorAdd 3, A, B
	ret
Vector3Add ENDP

;   Find angles (in radians) from one Vector3 to another and return it in Angle.
;   From:BPPtr - pointer to first Vector3.
;   To:BPPtr - pointer to second Vector3.
;   Angle:BPPtr - out pointer to a Vector2 struct to store the rotation.
Vector3Angle BPPROC From:BPPtr, To:BPPtr, Angle:BPPtr
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
	
	fld REAL4 PTR [pax+4]	; delta height
	fsub REAL4 PTR [pcx+4]
	;fchs
	fld d2d.X				; distance
	fmul st, st
	fld d2d.Y
	fmul st, st
	fadd
	fsqrt
	fpatan
	
	fstp REAL4 PTR [pdx]
	fstp REAL4 PTR [pdx+4]
	ret
Vector3Angle ENDP

Vector3Copy BPPROC To:BPPtr, From:BPPtr
	VectorCopy 3, To, From
	ret
Vector3Copy ENDP

;   Calculate cross product between two Vector3 and return it in Product.
;   A:BPPtr - pointer to first Vector3.
;   B:BPPtr - pointer to second Vector3.
;   Product:BPPtr - out pointer to a Vector3 structure to store the cross 
; product.
Vector3Cross BPPROC A:BPPtr, B:BPPtr, Product:BPPtr
	mov pax, A
	mov pcx, B
	mov pdx, Product
	
	fld REAL4 PTR [pax+4]	; A.Y * B.Z
	fmul REAL4 PTR [pcx+8]
	fld REAL4 PTR [pax+8]	; A.Z * B.Y
	fmul REAL4 PTR [pcx+4]
	fsub					; A.Y * B.Z - A.Z * B.Y
	
	fld REAL4 PTR [pax+8]	; A.Z * B.X
	fmul REAL4 PTR [pcx]
	fld REAL4 PTR [pax]		; A.X * B.Z
	fmul REAL4 PTR [pcx+8]
	fsub					; A.Z * B.X - A.X * B.Z
	
	fld REAL4 PTR [pax]		; A.X * B.Y
	fmul REAL4 PTR [pcx+4]
	fld REAL4 PTR [pax+4]	; A.Y * B.X
	fmul REAL4 PTR [pcx]
	fsub					; A.X * B.Y - A.Y * B.X
	
	fstp REAL4 PTR [pdx+8]	; into Product.Z
	fstp REAL4 PTR [pdx+4]	; into Product.Y
	fstp REAL4 PTR [pdx]	; into Product.X
	
	ret
Vector3Cross ENDP

Vector3Distance BPPROC A:BPPtr, B:BPPtr
	VectorDistance 3, A, B
	ret
Vector3Distance ENDP

Vector3DistanceSqr BPPROC A:BPPtr, B:BPPtr
	VectorDistanceSqr 3, A, B
	ret
Vector3DistanceSqr ENDP

Vector3Dot BPPROC A:BPPtr, B:BPPtr
	VectorDot 3, A, B
	ret
Vector3Dot ENDP

Vector3F BPPROC A:BPPtr
	VectorF 3, A
	ret
Vector3F ENDP

Vector3Length BPPROC A:BPPtr
	VectorLength 3, A
	ret
Vector3Length ENDP

Vector3LengthSqr BPPROC A:BPPtr
	VectorLengthSqr 3, A
	ret
Vector3LengthSqr ENDP

Vector3Lerp BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 3, A, B, T
	ret
Vector3Lerp ENDP

Vector3Mul BPPROC A:BPPtr, B:BPPtr
	VectorMul 3, A, B
	ret
Vector3Mul ENDP

Vector3MulF BPPROC A:BPPtr, B:REAL4
	VectorMulF 3, A, B
	ret
Vector3MulF ENDP

Vector3Negate BPPROC A:BPPtr
	VectorNegate 3, A
	ret
Vector3Negate ENDP

Vector3Normalize BPPROC A:BPPtr
	VectorNormalize 3, A
	ret
Vector3Normalize ENDP

Vector3Round BPPROC A:BPPtr
	VectorRound 3, A
	ret
Vector3Round ENDP

Vector3RoundInt BPPROC A:BPPtr
	VectorRoundInt 3, A
	ret
Vector3RoundInt ENDP

Vector3Set BPPROC A:BPPtr, X:REAL4, Y:REAL4, Z:REAL4
	VectorSet A, X, Y, Z
	ret
Vector3Set ENDP

Vector3Sub BPPROC A:BPPtr, B:BPPtr
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

;   Find angle (in radians) from one Vector32D to another and return it in eax.
;   From:BPPtr - pointer to first Vector3.
;   To:BPPtr - pointer to second Vector3.
Vector32DAngle BPPROC From:BPPtr, To:BPPtr
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

Vector32DAdd BPPROC A:BPPtr, B:BPPtr
	VectorAdd 32D, A, B
	ret
Vector32DAdd ENDP

Vector32DCopy BPPROC To:BPPtr, From:BPPtr
	VectorCopy 32D, To, From
	ret
Vector32DCopy ENDP

;   Calculate cross product between two Vector32D and return it in eax.
;   A:BPPtr - pointer to first Vector3.
;   B:BPPtr - pointer to second Vector3.
Vector32DCross BPPROC A:BPPtr, B:BPPtr
	LOCAL Val:REAL4
	mov pax, A
	mov pcx, B
	
	fld REAL4 PTR [pax]
	fmul REAL4 PTR [pcx+8]
	fld REAL4 PTR [pax+8]
	fmul REAL4 PTR [pcx]
	fsub
	fstp Val
	mov eax, Val
	ret
Vector32DCross ENDP

Vector32DDistance BPPROC A:BPPtr, B:BPPtr
	VectorDistance 32D, A, B
	ret
Vector32DDistance ENDP

Vector32DDistanceSqr BPPROC A:BPPtr, B:BPPtr
	VectorDistanceSqr 32D, A, B
	ret
Vector32DDistanceSqr ENDP

Vector32DDot BPPROC A:BPPtr, B:BPPtr
	VectorDot 32D, A, B
	ret
Vector32DDot ENDP

Vector32DF BPPROC A:BPPtr
	VectorF 32D, A
	ret
Vector32DF ENDP

Vector32DLength BPPROC A:BPPtr
	VectorLength 32D, A
	ret
Vector32DLength ENDP

Vector32DLengthSqr BPPROC A:BPPtr
	VectorLengthSqr 32D, A
	ret
Vector32DLengthSqr ENDP

Vector32DLerp BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 32D, A, B, T
	ret
Vector32DLerp ENDP

Vector32DMul BPPROC A:BPPtr, B:BPPtr
	VectorMul 32D, A, B
	ret
Vector32DMul ENDP

Vector32DMulF BPPROC A:BPPtr, B:REAL4
	VectorMulF 32D, A, B
	ret
Vector32DMulF ENDP

Vector32DNegate BPPROC A:BPPtr
	VectorNegate 32D, A
	ret
Vector32DNegate ENDP

Vector32DNormalize BPPROC A:BPPtr
	VectorNormalize 32D, A
	ret
Vector32DNormalize ENDP

Vector32DRound BPPROC A:BPPtr
	VectorRound 32D, A
	ret
Vector32DRound ENDP

Vector32DRoundInt BPPROC A:BPPtr
	VectorRoundInt 32D, A
	ret
Vector32DRoundInt ENDP

;   Set the Vector3 X and Z fields.
;   A:BPPtr - out pointer to the Vector3.
;   X,Z:REAL4 - field values.
Vector32DSet BPPROC A:BPPtr, X:REAL4, Z:REAL4
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

Vector32DSub BPPROC A:BPPtr, B:BPPtr
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

Vector4Add BPPROC A:BPPtr, B:BPPtr
	VectorAdd 4, A, B
	ret
Vector4Add ENDP

Vector4Copy BPPROC To:BPPtr, From:BPPtr
	VectorCopy 4, To, From
	ret
Vector4Copy ENDP

Vector4Distance BPPROC A:BPPtr, B:BPPtr
	VectorDistance 4, A, B
	ret
Vector4Distance ENDP

Vector4DistanceSqr BPPROC A:BPPtr, B:BPPtr
	VectorDistanceSqr 4, A, B
	ret
Vector4DistanceSqr ENDP

Vector4Dot BPPROC A:BPPtr, B:BPPtr
	VectorDot 4, A, B
	ret
Vector4Dot ENDP

Vector4F BPPROC A:BPPtr
	VectorF 4, A
	ret
Vector4F ENDP

Vector4Length BPPROC A:BPPtr
	VectorLength 4, A
	ret
Vector4Length ENDP

Vector4LengthSqr BPPROC A:BPPtr
	VectorLengthSqr 4, A
	ret
Vector4LengthSqr ENDP

Vector4Lerp BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 4, A, B, T
	ret
Vector4Lerp ENDP

Vector4Mul BPPROC A:BPPtr, B:BPPtr
	VectorMul 4, A, B
	ret
Vector4Mul ENDP

Vector4MulF BPPROC A:BPPtr, B:REAL4
	VectorMulF 4, A, B
	ret
Vector4MulF ENDP

Vector4Negate BPPROC A:BPPtr
	VectorNegate 4, A
	ret
Vector4Negate ENDP

Vector4Normalize BPPROC A:BPPtr
	VectorNormalize 4, A
	ret
Vector4Normalize ENDP

Vector4Round BPPROC A:BPPtr
	VectorRound 4, A
	ret
Vector4Round ENDP

Vector4RoundInt BPPROC A:BPPtr
	VectorRoundInt 4, A
	ret
Vector4RoundInt ENDP

Vector4Set BPPROC A:BPPtr, X:REAL4, Y:REAL4, Z:REAL4, W:REAL4
	VectorSet A, X, Y, Z, W
	ret
Vector4Set ENDP

Vector4Sub BPPROC A:BPPtr, B:BPPtr
	VectorSub 4, A, B
	ret
Vector4Sub ENDP


IFDEF BP3D_MATHS_INC
;   Extended vector functions that use float comparison and functions from 
; BP3DMaths.


; ----- Generic VectorN macros -----

;   Clamp a vector's length (magnitude) to Len.
;   A:BPPtr - out pointer to the VectorN.
;   Len:REAL4 - the maximum length to clamp to.
VectorClampLength MACRO Cnt:REQ, A:REQ, Len:REQ	
	VectorLength Cnt, A
	
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	push pax
	.IF (REAL4 PTR [psp])
		fcmp Len, REAL4 PTR [psp]
		.IF (Carry?)
			mov pax, A
			_bpPosOff = 0
			REPEAT _bpCntRep
				fld REAL4 PTR [pax+_bpPosOff]
				fdiv REAL4 PTR [psp]
				fmul Len
				fstp REAL4 PTR [pax+_bpPosOff]
				_bpPosOff = _bpPosOff + _bpOffSize
			ENDM
		.ENDIF
	.ENDIF
	pop pax
ENDM

;   Wrap a rotation vector's angles (-PI - PI, in radians). Useful for angle 
; interpolation.
;   A:BPPtr - out pointer to the VectorN to wrap.
VectorEuler MACRO Cnt:REQ, A:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pcx, A
	_bpPosOff = 0
	REPEAT _bpCntRep
		invoke flAngle, REAL4 PTR [pcx+_bpPosOff]
		mov REAL4 PTR [pcx+_bpPosOff], eax
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Do linear interpolation from one vector towards another by T with proper
; angle wrapping (in radians). If BP3DMaths.inc is included before this module,
; clamps T by default (see BP3DMaths.inc -> BP_LERP_UNCLAMPED).
;   A:BPPtr - out pointer to the starting VectorN.
;   B:BPPtr - pointer to the destination VectorN.
;   T:REAL4 - interpolation value between the two.
VectorLerpAngle MACRO Cnt:REQ, A:REQ, B:REQ, T:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pdx, A
	mov pcx, B
	_bpPosOff = 0
	REPEAT _bpCntRep
		invoke flLerpAngle, REAL4 PTR [pdx+_bpPosOff], REAL4 PTR [pcx+_bpPosOff], T
		mov REAL4 PTR [pdx+_bpPosOff], eax
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM

;   Move one vector towards another by T with clamping movement length. This
; is slower than VectorMoveEach, but preserves the same speed upon movement on
; more than one axis (e.g. diagonal).
;   A:BPPtr - out pointer to the starting VectorN.
;   B:BPPtr - pointer to the destination VectorN.
;   T:REAL4 - movement speed.
VectorMove MACRO Cnt:REQ, From:REQ, To:REQ, T:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	LOCAL dir[_bpCntRep]:REAL4
	
	VectorDistanceSqr Cnt, From, To
	fld T
	fmul st, st
	fstp dir[0]
	fcmp eax, dir[0]
	.IF (Carry?)
		VectorCopy Cnt, From, To
		ret
	.ENDIF
	
	mov pdx, From
	mov pcx, To
	_bpPosOff = 0
	REPEAT _bpCntRep
		fld REAL4 PTR [pcx+_bpPosOff]
		fsub REAL4 PTR [pdx+_bpPosOff]
		fstp dir[_bpPosOff]
		invoke flSign, dir[_bpPosOff]
		mov dir[_bpPosOff], eax
		fld dir[_bpPosOff]
		fmul T
		fstp dir[_bpPosOff]
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
	lea pcx, dir
	VectorClampLength Cnt, pcx, T
	VectorAdd Cnt, From, pcx
ENDM

;   Move one vector towards another by T without clamping movement length. This
; is slower than VectorMove, but overall movement speed will be faster than T
; when moving more than one axis (e.g. diagonal).
;   A:BPPtr - out pointer to the starting VectorN.
;   B:BPPtr - pointer to the destination VectorN.
;   T:REAL4 - movement speed.
VectorMoveEach MACRO Cnt:REQ, From:REQ, To:REQ, T:REQ
	_bpCntRep = Vector32DCheck(Cnt, 1)
	_bpOffSize = Vector32DCheck(Cnt, 0)
	
	mov pdx, From
	mov pcx, To
	_bpPosOff = 0
	REPEAT _bpCntRep
		invoke flMove, REAL4 PTR [pdx+_bpPosOff], REAL4 PTR [pcx+_bpPosOff], T
		mov REAL4 PTR [pdx+_bpPosOff], eax
		_bpPosOff = _bpPosOff + _bpOffSize
	ENDM
ENDM


; ----- Vector2 -----
Vector2ClampLength BPPROC A:BPPtr, Len:REAL4
	VectorClampLength 2, A, Len
	ret
Vector2ClampLength ENDP

Vector2Euler BPPROC A:BPPtr
	VectorEuler 2, A
	ret
Vector2Euler ENDP

Vector2LerpAngle BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerpAngle 2, A, B, T
	ret
Vector2LerpAngle ENDP

Vector2Move BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMove 2, From, To, T
	ret
Vector2Move ENDP

Vector2MoveEach BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMoveEach 2, From, To, T
	ret
Vector2MoveEach ENDP


; ----- Vector3 -----
Vector3ClampLength BPPROC A:BPPtr, Len:REAL4
	VectorClampLength 3, A, Len
	ret
Vector3ClampLength ENDP

Vector3Euler BPPROC A:BPPtr
	VectorEuler 3, A
	ret
Vector3Euler ENDP

Vector3LerpAngle BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerpAngle 3, A, B, T
	ret
Vector3LerpAngle ENDP

Vector3Move BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMove 3, From, To, T
	ret
Vector3Move ENDP

Vector3MoveEach BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMoveEach 3, From, To, T
	ret
Vector3MoveEach ENDP


; ----- Vector3 2D (X, Z) -----
Vector32DClampLength BPPROC A:BPPtr, Len:REAL4
	VectorClampLength 32D, A, Len
	ret
Vector32DClampLength ENDP

Vector32DEuler BPPROC A:BPPtr
	VectorEuler 32D, A
	ret
Vector32DEuler ENDP

Vector32DLerpAngle BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerpAngle 32D, A, B, T
	ret
Vector32DLerpAngle ENDP

Vector32DMove BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMove 32D, From, To, T
	ret
Vector32DMove ENDP

Vector32DMoveEach BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMoveEach 32D, From, To, T
	ret
Vector32DMoveEach ENDP


; ----- Vector4 -----
Vector4ClampLength BPPROC A:BPPtr, Len:REAL4
	VectorClampLength 4, A, Len
	ret
Vector4ClampLength ENDP

Vector4Euler BPPROC A:BPPtr
	VectorEuler 4, A
	ret
Vector4Euler ENDP

Vector4LerpAngle BPPROC A:BPPtr, B:BPPtr, T:REAL4
	VectorLerpAngle 4, A, B, T
	ret
Vector4LerpAngle ENDP

Vector4Move BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMove 4, From, To, T
	ret
Vector4Move ENDP

Vector4MoveEach BPPROC From:BPPtr, To:BPPtr, T:REAL4
	VectorMoveEach 4, From, To, T
	ret
Vector4MoveEach ENDP

ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DVectors.inc
ENDIF