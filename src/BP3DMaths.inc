;
;   BP3DMaths.inc
;   Version 0.8ac1
;   BP3D common math (REAL4 (x87 FPU) & SDWORD) functions extension.
;
;   Copyright (c) 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.
;   Licensed under the terms of the MIT license (see ..\LICENSE.txt).
;

IFNDEF BP3D_MATHS_INC
BP3D_MATHS_INC EQU <1>

IFNDEF BP3D_TYPEDEF_INC
	include BP3DTypedef.inc
ENDIF

; -----	INTERFACE -----

; ----- CONSTANTS -----
; FPU codeword interrupt mask field flags
FPU_EXCEPTION_PRECISION		EQU 0000000000100000b	; Precision mask
FPU_EXCEPTION_UNDERFLOW		EQU 0000000000010000b	; Underflow mask
FPU_EXCEPTION_OVERFLOW		EQU 0000000000001000b	; Overflow mask
FPU_EXCEPTION_ZERO_DIVIDE	EQU 0000000000000100b	; Zero divide mask
FPU_EXCEPTION_DENORMALIZED	EQU 0000000000000010b	; Denormalized operand mask
FPU_EXCEPTION_INVALID		EQU 0000000000000001b	; Invalid operation mask

; FPU codeword precision control field values
FPU_PRECISION_REAL4		EQU 0000000000000000b	; REAL4 (24 bits)
FPU_PRECISION_REAL8		EQU 0000001000000000b	; REAL8 (53 bits)
FPU_PRECISION_REAL10	EQU 0000001100000000b	; REAL10 (64 bits) 

; FPU codeword rounding control field values
FPU_ROUND_TRUNC	EQU 0000110000000000b	; Truncate (toward 0)
FPU_ROUND_CEIL	EQU 0000100000000000b	; Round up (toward +infinity)
FPU_ROUND_FLOOR	EQU 0000010000000000b	; Round down (toward -infinity)
FPU_ROUND_ROUND	EQU 0000000000000000b	; Round to nearest (default)

; IEEE 754 float constants
FLT_INF		EQU 7F800000h	; +Infinity
FLT_INFN	EQU 0FF800000h	; -Infinity
FLT_NEG		EQU 80000000h	; -0 (negative flag, useful for cmp without FPU)

.CONST
D2R			REAL4	0.0174532		; Degrees to radians multiplier
R2D			REAL4	57.29578		; Radians to degrees multiplier
R2I			REAL4	0.6366197		; Radians to integer
PI			REAL4	3.141592653		; Pi	(180 deg)
PIN			REAL4	-3.141592653	; -Pi	(-180 deg)
PIHalf		REAL4	1.570796326		; Pi/2	(90 deg)
PIHalfN		REAL4	-1.570796326	; -Pi/2	(-90 deg)
PIQuarter	REAL4	0.765398163		; Pi/4	(45 deg)
PIQuarterN	REAL4	-0.765398163	; -Pi/4	(-45 deg)
PI2			REAL4	6.283185307		; Pi*2	(360 deg)
flInf		DWORD	FLT_INF			; Data field of FLT_INF
flInfN		DWORD	FLT_INFN		; Data field of FLT_INFN

; ----- DATA FIELDS -----
.DATA?
nRandSeed DWORD ?

; ----- IMPLEMENTATION -----
.CODE

; Prototype procedure declarations (for potential forward usage in unit)
fcmpP			PROTO
flAcos			PROTO :REAL4
flAsin			PROTO :REAL4
flAngle			PROTO :REAL4
flClamp			PROTO :REAL4, :REAL4, :REAL4
flDistance		PROTO :REAL4, :REAL4
flFrac			PROTO :REAL4
flInRange		PROTO :REAL4, :REAL4, :REAL4
flLerp			PROTO :REAL4, :REAL4, :REAL4
flLerpAngle		PROTO :REAL4, :REAL4, :REAL4
flMax			PROTO :REAL4, :REAL4
flMin			PROTO :REAL4, :REAL4
flMove			PROTO :REAL4, :REAL4, :REAL4
flRand			PROTO
flRandRange		PROTO :REAL4, :REAL4
flRepeat		PROTO :REAL4, :REAL4
flSign			PROTO :REAL4
fpuGetException	PROTO
fpuGetStackTop	PROTO
fpuSetInterrupt	PROTO :WORD
fpuSetPrecision	PROTO :WORD
fpuSetRounding	PROTO :WORD
nRand			PROTO :DWORD
intAbs 			PROTO :SDWORD
intClamp 		PROTO :SDWORD, :SDWORD, :SDWORD
intDistance 	PROTO :SDWORD, :SDWORD
intInRange	 	PROTO :SDWORD, :SDWORD, :SDWORD
intRandRange 	PROTO :SDWORD, :SDWORD
intSign 		PROTO :SDWORD
nRand 			PROTO :DWORD
nRandomize 		PROTO

;   Immediate REAL4 to reusable data field (format fl+int+n+frac(+N)).
f MACRO val
	LOCAL min,dot,num,frac,sym,txt
	min INSTR <val>,<->	
	dot INSTR <val>,<.>
	IF dot
		num SUBSTR <val>,min+1,dot-min-1
		frac SUBSTR <val>,dot+1
	ELSE
		num SUBSTR <val>,min+1
		frac EQU <0>
	ENDIF
	
	IF min
		sym CATSTR <fl>,num,<n>,frac,<N>
	ELSE
		sym CATSTR <fl>,num,<n>,frac
	ENDIF
	
	%IFNDEF sym
		;%ECHO Declaring REAL4 variable with name sym
		.DATA
		IF dot
			sym REAL4 val
		ELSE
			sym REAL4 val&.0
		ENDIF
		.CODE
	ENDIF
	
	EXITM <sym>
ENDM

;   Float comparison macro. Carry? is cmp1<cmp2. Zero? is cmp==cmp2. If cmp2 is
; empty, compare against 0. 'Inspired' by jj2007's macro.
fcmp MACRO cmp1:REQ, cmp2
	LOCAL oa
	IF @Cpu GE 3423	; .686 has fcomip
		IFB <cmp2>
			fldz
		ELSE
			fld cmp2
		ENDIF
		fld cmp1
		fcomip st, st(1)
		fstp st
	ELSE
		;ffree st(7)
		ifb <cmp2>
			fldz	; No second arg; compare against zero
		else
			oa = (opattr cmp2) and 127
			if (oa eq 36) or (oa eq 48)
				push cmp2
				fild DWORD PTR [esp]	; Integer or reg32 on stack, then on FPU
				pop eax
			else
				fld cmp2	; Real on FPU
			endif
		endif
		;ffree st(7)
		fld cmp1
		call fcmpP
	ENDIF
ENDM

;   Compares FPU st(0) with st(1). Is called if CPU is < 686 by fcmp. See fcmp
; for flag results.
fcmpP PROC EXPORT
	fcompp
	fnstsw ax
	
	push pax
	and ax, 4000h
	xor ax, 4000h
	
	test ax, ax
	pop pax
	
	bt ax, 8
	ret
fcmpP ENDP

;   Return the absolute of Val in eax.
;   Val:REAL4 - value to get the absolute of.
flAbs PROC EXPORT Val:REAL4
	mov eax, Val
	and eax, not FLT_NEG
	ret
flAbs ENDP

;   Calculate arccosine of Val.
;   Val:REAL4 - angle to find the arccosine of.
flAcos PROC EXPORT Val:REAL4
	fld Val
	fld1
	fld st(1)
	fmul st, st
	fsub
	fsqrt
	fxch
	fpatan
	fstp Val
	mov eax, Val
	ret
flAcos ENDP

;   Calculate arcsine of Val.
;   Val:REAL4 - angle to find the arcsine of.
flAsin PROC EXPORT Val:REAL4
	fld Val
	fld1
	fld st(1)
	fmul st, st
	fsub
	fsqrt
	fpatan
	fstp Val
	mov eax, Val
	ret
flAsin ENDP

;   Wrap an angle (-PI - PI, in radians) and return in eax. Useful for angle 
; interpolation.
;   Val:REAL4 - angle (in radians) to wrap.
flAngle PROC EXPORT Val:REAL4
	fcmp Val, PI
	.IF (!Carry?)	; Val > PI
		fld Val
		fsub PI2
		fstp Val
	.ENDIF
	fcmp Val, PIN
	.IF (Carry?)	; Val < -PI
		fld Val
		fadd PI2
		fstp Val
	.ENDIF
	
	mov eax, Val
	ret
flAngle ENDP

;   Clamp Val to range of [Min - Max] and return result in eax.
;   Val:REAL4 - value to clamp.
;   Min:REAL4 - minimum clamp range value.
;   Max:REAL4 - maximum clamp range value.
flClamp PROC EXPORT Val:REAL4, Min:REAL4, Max:REAL4
	fcmp Val, Max
	.IF (!Carry?)		; X > X1
		fld Max
		fstp Val
	.ELSE
		fcmp Val, Min
		.IF (Carry?)	; X < X1
			fld Min
			fstp Val
		.ENDIF
	.ENDIF
	
	mov eax, Val
	ret
flClamp ENDP

;   Calculate scalar distance between From and To and return result in eax.
;   From:REAL4 - the first point, to calculate the distance from.
;   To:REAL4 - the second point, to calculate the distance to.
flDistance PROC EXPORT From:REAL4, To:REAL4
	fld From
	fsub To
	fabs
	fstp From
	mov eax, From
	ret
flDistance ENDP

;   Separate the fractional part of a value and return in eax.
;   Val:REAL4 - value to take the fractional part from.
flFrac PROC EXPORT Val:REAL4
	LOCAL cw:WORD
	
	fnstcw cw
	push cw
	or cw, FPU_ROUND_FLOOR
	fldcw cw
	
	fld Val
	fld st
	frndint
	fsub
	fstp Val
	
	pop cw
	fldcw cw
	
	mov eax, Val
	ret
flFrac ENDP

;   Check if Val is in the range of [Min - Max] and return result in pax (TRUE /
; FALSE).
;   Val:REAL4 - value to check.
;   Min:REAL4 - minimum range value.
;   Max:REAL4 - maximum range value.
flInRange PROC EXPORT Val:REAL4, Min:REAL4, Max:REAL4
	fcmp Val, Min
	.IF (!Carry?)
		fcmp Val, Max
		.IF (Carry?)
			mov pax, TRUE
			ret
		.ENDIF
	.ENDIF
	mov pax, FALSE
	ret
flInRange ENDP

;   Linearly interpolate between A and B by T and return result in eax.
;   A:REAL4 - starting value.
;   B:REAL4 - destination value.
;   T:REAL4 - interpolation value between the two.
flLerp PROC EXPORT A:REAL4, B:REAL4, T:REAL4
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			mov eax, B
			ret
		.ENDIF
	ENDIF
	
	fld B
	fsub A
	fmul T
	fadd A
	fstp A
	
	mov eax, A
	ret
flLerp ENDP

;   Linearly interpolate between A and B by T with proper angle wrapping (in
; radians) and return result in eax.
;   A:REAL4 - starting value.
;   B:REAL4 - destination value.
;   T:REAL4 - interpolation value between the two.
flLerpAngle PROC EXPORT A:REAL4, B:REAL4, T:REAL4
	LOCAL _Ang:REAL4
	IFNDEF BP_LERP_UNCLAMPED
		fcmp T, f(1)
		.IF (!Carry?) || (Zero?)
			mov eax, B
			ret
		.ENDIF
	ENDIF
	
	fld B
	fsub A
	fstp _Ang
	invoke flAngle, _Ang
	mov _Ang, eax
	fld _Ang
	fmul T
	fadd A
	fstp A
	
	mov eax, A
	ret
flLerpAngle ENDP

;   Return the maximum of the A and B values in eax.
;   A:REAL4 - first value.
;   B:REAL4 - second value.
flMax PROC EXPORT A:REAL4, B:REAL4
	fcmp A, B
	.IF (Carry?)
		mov eax, B
	.ELSE
		mov eax, A
	.ENDIF
	ret
flMax ENDP

;   Return the minimum of the A and B values in eax.
;   A:REAL4 - first value.
;   B:REAL4 - second value.
flMin PROC EXPORT A:REAL4, B:REAL4
	fcmp A, B
	.IF (Carry?)
		mov eax, A
	.ELSE
		mov eax, B
	.ENDIF
	ret
flMin ENDP

;   Move From toward To by T and return result in eax.
;   From:REAL4 - starting value.
;   To:REAL4 - destination value.
;   T:REAL4 - the amount to move by.
flMove PROC EXPORT From:REAL4, To:REAL4, T:REAL4
	LOCAL Dist:REAL4	
	invoke flDistance, From, To
	mov Dist, eax
	fcmp Dist, T
	.IF (Carry?)	; Dist < T
		mov eax, To
		ret
	.ENDIF

	fld To
	fsub From
	fstp Dist
	invoke flSign, Dist
	mov Dist, eax
	fld Dist
	fmul T
	fadd From
	fstp Dist
	
	mov eax, Dist
	ret
flMove ENDP

;   Returns a random REAL4 in range [0.0 - 1.0] (thousandth precision) in eax.
flRand PROC EXPORT
	LOCAL _Val:REAL4
	
	invoke nRand, 1000
	mov _Val, eax
	fild _Val
	fmul f(0.001)
	fstp _Val
	mov eax, _Val
	ret
flRand ENDP

;   Returns a random REAL4 in range [Min - Max] in eax.
;   Min:REAL4 - minimum random range value.
;   Max:REAL4 - maximum random range value.
flRandRange PROC EXPORT Min:REAL4, Max:REAL4
	LOCAL _Val:REAL4
	
	invoke nRand, 1000
	mov _Val, eax	; Val * (Max - Min) + Min
	fld Max
	fsub Min
	fild _Val
	fmul f(0.001)
	fmul
	fadd Min
	fstp _Val
	mov eax, _Val
	ret
flRandRange ENDP

;   Repeat Val through the range of [0.0 - Max] and return result in eax.
;   Val:REAL4 - value to be repeated.
;   Max:REAL4 - maximum range value.
flRepeat PROC EXPORT Val:REAL4, Max:REAL4
	LOCAL cw:WORD
	fnstcw cw
	push cw
	or cw, FPU_ROUND_FLOOR
	fldcw cw
	
	fld Val
	fdiv Max
	frndint
	fsubr Val
	fmul Max
	fstp Val
	
	pop cw
	fldcw cw
	
	invoke flClamp, Val, 0, Max
	ret
flRepeat ENDP

;   Return the sign (-1.0 | 0.0 | 1.0) of Val in eax.
;   Val:REAL4 - value to get the sign of.
flSign PROC EXPORT Val:REAL4
	.IF (Val == FLT_NEG) || !(Val)
		xor eax, eax
		ret
	.ENDIF
	.IF (Val & FLT_NEG)
		mov eax, f(-1.0)
	.ELSE
		mov eax, f(1.0)
	.ENDIF
	ret
flSign ENDP

;   Return the FPU exceptions status (FPU_EXCEPTION_* flags bitmask) in eax.
fpuGetException PROC EXPORT
	xor eax, eax
	fnstsw ax
	and ax, 0000000000111111b
	ret
fpuGetException ENDP

;   Return the FPU stack top register (st) index in eax.
fpuGetStackTop PROC EXPORT
	xor eax, eax
	fnstsw ax
	and ax, 0011100000000000b
	shr ax, 11
	ret
fpuGetStackTop ENDP

;   Set the FPU interrupt masks (from FPU_EXCEPTION_*).
;   IM:WORD - bitmask of ORed FPU_EXCEPTION_* flags, gets inverted before FLDCW.
fpuSetInterrupt PROC EXPORT IM:WORD
	LOCAL cw:WORD
	fnstcw cw
	and cw, 1111111111100000b
	mov ax, IM
	not ax
	and ax, 0000000000011111b
	or cw, ax
	fldcw cw
	ret
fpuSetInterrupt ENDP

;   Set the FPU precision mode (from FPU_PRECISION_*).
;   PC:WORD - the FPU precision mode.
fpuSetPrecision PROC EXPORT PC:WORD
	LOCAL cw:WORD
	fnstcw cw
	and cw, 1111110011111111b
	mov ax, PC
	or cw, ax
	fldcw cw
	ret
fpuSetPrecision ENDP

;   Set the FPU rounding mode (from FPU_ROUND_*).
;   RC:WORD - the FPU rounding mode.
fpuSetRounding PROC EXPORT RC:WORD
	LOCAL cw:WORD
	fnstcw cw
	and cw, 1111001111111111b
	mov ax, RC
	or cw, ax
	fldcw cw
	ret
fpuSetRounding ENDP

;   Return the absolute of Val in eax.
;   Val:SDWORD - value to get the absolute of.
intAbs PROC EXPORT Val:SDWORD
	mov eax, Val
	cmp eax, 0
	jge intAbsNeg
		neg eax
	intAbsNeg:
	ret
intAbs ENDP

;   Clamp Val to range of [Min - Max] and return result in eax.
;   Val:SDWORD - value to clamp.
;   Min:SDWORD - minimum clamp range value.
;   Max:SDWORD - maximum clamp range value.
intClamp PROC EXPORT Val:SDWORD, Min:SDWORD, Max:SDWORD
	mov eax, Val
	cmp eax, Min
	jge intClampSetMin
		mov eax, Min
	intClampSetMin:
	cmp eax, Max
	jle intClampSetMax
		mov eax, Max
	intClampSetMax:
	ret
intClamp ENDP

;   Calculate distance between From and To and return result in eax.
;   From:SDWORD - the first point, to calculate the distance from.
;   To:SDWORD - the second point, to calculate the distance to.
intDistance PROC EXPORT From:SDWORD, To:SDWORD
	mov eax, From
	sub eax, To
	invoke intAbs, eax
	ret
intDistance ENDP

;   Check if Val is in the range of [Min - Max] and return result in pax (TRUE /
; FALSE).
;   Val:SDWORD - value to check.
;   Min:SDWORD - minimum range value.
;   Max:SDWORD - maximum range value.
intInRange PROC EXPORT Val:SDWORD, Min:SDWORD, Max:SDWORD
	mov eax, Val
	cmp eax, Min
	jl intInRangeFalse
	cmp eax, Max
	jg intInRangeFalse
	mov pax, TRUE
	ret
	intInRangeFalse:
	mov pax, FALSE
	ret
intInRange ENDP

;   Returns a random SDWORD in range [Min - Max] in eax.
;   Min:SDWORD - minimum random range value.
;   Max:SDWORD - maximum random range value.
intRandRange PROC EXPORT Min:SDWORD, Max:SDWORD
	mov eax, Max
	sub eax, Min
	invoke nRand, eax
	add eax, Min
	ret
intRandRange ENDP

;   Return the sign (-1 | 0 | 1) of Val in eax.
;   Val:SDWORD - value to get the sign of.
intSign PROC EXPORT Val:SDWORD
	mov eax, Val
	cmp eax, 0
	jg intSignG
		mov eax, 1
		ret
	intSignG:
	jl intSignS
		mov eax, -1
		ret
	intSignS:
	xor eax, eax
	ret
intSign ENDP

;   MASM32 Park Miller random number algorithm implementation (nrandom), written
; by Jaymeson Trudgen (NaN), optimized by Rickey Bowers Jr. (bitRAKE). Returns
; a random number in the range of [0 - Base). Uses nRandSeed value as seed.
;   Base:DWORD - random algorithm base, the maximum exclusive range.
nRand PROC EXPORT Base:DWORD
	mov eax, nRandSeed

	test eax, 80000000h
	jz @F
	add eax, 7fffffffh

	@@:   
	xor edx, edx
	mov ecx, 127773
	div ecx
	mov ecx, eax
	mov eax, 16807
	mul edx
	mov edx, ecx
	mov ecx, eax
	mov eax, 2836
	mul edx
	sub ecx, eax
	xor edx, edx
	mov eax, ecx
	mov nRandSeed, ecx
	div Base

	mov eax, edx
	ret
nRand ENDP

;   Randomize the nRandSeed for nRand (set nRandSeed to current tick count).
nRandomize PROC EXPORT
	IFDEF GetTickCount
		call GetTickCount
	ELSEIF @Cpu GE 3359	; >= .486
		rdtsc
	ENDIF
	mov nRandSeed, eax
	ret
nRandomize ENDP

ELSE
	ECHO BP3D: Duplicate include file BP3DMaths.inc
ENDIF
