IFNDEF BP3DVECTORS_INC
BP3DVECTORS_INC equ <1>

; ----- INTERFACE -----

; ----- TYPES -----
Vector2 STRUCT
	X REAL4 0
	Y REAL4 0
Vector2 ENDS

Vector3 STRUCT
	X REAL4 0
	Y REAL4 0
	Z REAL4 0
Vector3 ENDS

Vector4 STRUCT
	X REAL4 0
	Y REAL4 0
	Z REAL4 0
	W REAL4 0
Vector4 ENDS

.CONST
Vector2One	Vector2 <1.0, 1.0>
Vector2Zero	Vector2 <0.0, 0.0>
Vector3One	Vector3 <1.0, 1.0, 1.0>
Vector3Up	Vector3 <0.0, 1.0, 0.0>
Vector3Zero	Vector3 <0.0, 0.0, 0.0>

.CODE

Vector2Set PROTO :BPPtr, :REAL4, :REAL4
Vector3Set PROTO :BPPtr, :REAL4, :REAL4, :REAL4

; ----- Generic VectorN macros -----
VectorAdd MACRO Cnt:REQ, A:REQ, B:REQ
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fadd REAL4 PTR [pcx+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorCopy MACRO Cnt:REQ, To:REQ, From:REQ
	mov pax, From
	PosOff = 0
	REPEAT Cnt
		push REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
	mov pax, To
	PosOff = (Cnt-1) * SIZEOF REAL4
	REPEAT Cnt
		pop REAL4 PTR [pax+PosOff]
		PosOff = PosOff - SIZEOF REAL4
	ENDM
ENDM

VectorClampLength MACRO Cnt:REQ, A:REQ, Len:REQ
	LOCAL ALen
	.DATA?
	ALen REAL4 ?
	
	.CODE
	VectorLength Cnt, A
	mov ALen, eax
	.IF (ALen)
		fcmp Len, ALen
		.IF (Carry?)
			mov pax, A
			PosOff = 0
			REPEAT Cnt
				fld REAL4 PTR [pax+PosOff]
				fdiv ALen
				fmul Len
				fstp REAL4 PTR [pax+PosOff]
				PosOff = PosOff + SIZEOF REAL4
			ENDM
		.ENDIF
	.ENDIF
ENDM

VectorDistanceSqr MACRO Cnt:REQ, A:REQ, B:REQ
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pcx+PosOff]
		fsub REAL4 PTR [pax+PosOff]
		fmul st, st
		PosOff = PosOff + SIZEOF REAL4
	ENDM
	REPEAT Cnt-1
		fadd
	ENDM
	sub esp, 4
	fstp REAL4 PTR [esp]
	pop eax
ENDM

VectorF MACRO Cnt:REQ, A:REQ
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fild DWORD PTR [pax+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorLength MACRO Cnt:REQ, A:REQ
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fmul st, st
		PosOff = PosOff + SIZEOF REAL4
	ENDM
	REPEAT Cnt-1
		fadd
	ENDM
	fsqrt
	sub esp, 4
	fstp REAL4 PTR [esp]
	pop eax
ENDM

VectorLengthSqr MACRO Cnt:REQ, A:REQ
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fmul st, st
		PosOff = PosOff + SIZEOF REAL4
	ENDM
	REPEAT Cnt-1
		fadd
	ENDM
	sub esp, 4
	fstp REAL4 PTR [esp]
	pop eax
ENDM

VectorLerp MACRO Cnt:REQ, A:REQ, B:REQ, T:REQ
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pcx+PosOff]
		fsub REAL4 PTR [pax+PosOff]
		fmul T
		fadd REAL4 PTR [pax+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM	
ENDM

VectorMul MACRO Cnt:REQ, A:REQ, B:REQ
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fmul REAL4 PTR [pcx+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorMulF MACRO Cnt:REQ, A:REQ, B:REQ
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fmul B
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorNormalize MACRO Cnt:REQ, A:REQ
	VectorLengthSqr Cnt, A
	.IF (!eax)
		mov pax, A
		PosOff = 0
		REPEAT Cnt
			mov REAL4 PTR [pax+PosOff], 0
			PosOff = PosOff + SIZEOF REAL4
		ENDM
		ret
	.ENDIF
	push eax
	fld REAL4 PTR [esp]
	fsqrt
	fstp REAL4 PTR [esp]
	
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fdiv REAL4 PTR [esp]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
	add esp, 4
ENDM

VectorRound MACRO Cnt:REQ, A:REQ
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fld DWORD PTR [pax+PosOff]
		frndint
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorRoundInt MACRO Cnt:REQ, A:REQ
	mov pax, A
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fistp DWORD PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorSet MACRO A:REQ, Coords:VARARG
	mov pax, A
	PosOff = 0
	FOR Coord, <Coords>
		push Coord
		pop REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

VectorSub MACRO Cnt:REQ, A:REQ, B:REQ
	mov pax, A
	mov pcx, B
	PosOff = 0
	REPEAT Cnt
		fld REAL4 PTR [pax+PosOff]
		fsub REAL4 PTR [pcx+PosOff]
		fstp REAL4 PTR [pax+PosOff]
		PosOff = PosOff + SIZEOF REAL4
	ENDM
ENDM

; ----- Vector2 -----

Vector2Pop MACRO A:REQ
	pop A.X
	pop A.Y
ENDM

Vector2Print MACRO A:REQ
	print real4$(A.X), 9
	print real4$(A.Y), 13, 10
ENDM

Vector2Push MACRO A:REQ
	push A.Y
	push A.X
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

Vector2ClampLength PROC EXPORT A:BPPtr, Len:REAL4
	VectorClampLength 2, A, Len
	ret
Vector2ClampLength ENDP

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
	pop A.X
	pop A.Y
	pop A.Z
ENDM

Vector3Print MACRO A:REQ
	print real4$(A.X), 9
	print real4$(A.Y), 9
	print real4$(A.Z), 13, 10
ENDM

Vector3Push MACRO A:REQ
	push A.Z
	push A.Y
	push A.X
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
	
	fld REAL4 PTR [pcx+4]
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

Vector3ClampLength PROC EXPORT A:BPPtr, Len:REAL4
	VectorClampLength 3, A, Len
	ret
Vector3ClampLength ENDP

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
	mov pax, A
	
	fld REAL4 PTR [pax]
	fchs
	fstp REAL4 PTR [pax]
	fld REAL4 PTR [pax+4]
	fchs
	fstp REAL4 PTR [pax+4]
	fld REAL4 PTR [pax+8]
	fchs
	fstp REAL4 PTR [pax+8]
	
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

Vector4F PROC EXPORT A:BPPtr
	VectorF 4, A
	ret
Vector4F ENDP

Vector4Lerp PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4
	VectorLerp 4, A, B, T
	ret
Vector4Lerp ENDP

Vector4MulF PROC EXPORT A:BPPtr, B:REAL4
	VectorMulF 4, A, B
	ret
Vector4MulF ENDP

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
Vector3Euler PROC EXPORT A:BPPtr
	mov pcx, A
	invoke flEuler, REAL4 PTR [pcx]
	mov REAL4 PTR [pcx], pax
	invoke flEuler, REAL4 PTR [pcx+4]
	mov REAL4 PTR [pcx+4], pax
	invoke flEuler, REAL4 PTR [pcx+8]
	mov REAL4 PTR [pcx+8], pax
	ret
Vector3Euler ENDP

Vector3LerpAngle PROC EXPORT A:BPPtr, B:BPPtr, T:REAL4	;REDO WITH flLerpAngle
	LOCAL _Ang:REAL4
	mov pdx, A
	mov pcx, B
	
	fld REAL4 PTR [pcx]
	fsub REAL4 PTR [pdx]
	fstp _Ang
	invoke flEuler, _Ang
	mov _Ang, pax
	fld _Ang
	fmul T
	fadd REAL4 PTR [pdx]
	fstp REAL4 PTR [pdx]
	
	fld REAL4 PTR [pcx+4]
	fsub REAL4 PTR [pdx+4]
	fstp _Ang
	invoke flEuler, _Ang
	mov _Ang, pax
	fld _Ang
	fmul T
	fadd REAL4 PTR [pdx+4]
	fstp REAL4 PTR [pdx+4]
	
	fld REAL4 PTR [pcx+8]
	fsub REAL4 PTR [pdx+8]
	fstp _Ang
	invoke flEuler, _Ang
	mov _Ang, pax
	fld _Ang
	fmul T
	fadd REAL4 PTR [pdx+8]
	fstp REAL4 PTR [pdx+8]
	
	ret
Vector3LerpAngle ENDP

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
ENDIF

ELSE
	ECHO BP3D: Duplicate include file BP3DVectors.inc
ENDIF