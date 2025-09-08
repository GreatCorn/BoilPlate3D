IFNDEF BP3DMATHS_INC
BP3DMATHS_INC equ <1>

; -----	INTERFACE -----

FPU_TRUNC	EQU 0000110000000000b
FPU_CEIL	EQU 0000100000000000b
FPU_FLOOR	EQU 0000010000000000b
FPU_ROUND	EQU 0000000000000000b
FLT_INF		EQU 7F800000h
FLT_INFN	EQU 0FF800000h
FLT_NEG		EQU 80000000h

.CONST
D2R		REAL4	0.0174532	; Degrees to radians multiplier
R2D		REAL4	57.29578	; Radians to degrees multiplier
R2I		REAL4	0.6366197	; Radians to integer
PI		REAL4	3.141592653
PIN		REAL4	-3.141592653
PIHalf	REAL4	1.570796326
PIHalfN	REAL4	-1.570796326
PIQuarter	REAL4	0.765398163
PIQuarterN	REAL4	-0.765398163
PI2		REAL4	6.283185307
flInf	DWORD	FLT_INF
flInfN	DWORD	FLT_INFN

fl0 REAL4 0.0			; Generic floats (REAL4) to use with FPU and other
flThousandth	REAL4	0.001
flHundredth		REAL4	0.01
flHundredthN	REAL4	-0.01
flTenth		REAL4	0.1
flTenthN	REAL4	-0.1
flFifth		REAL4	0.2
flFifthN	REAL4	-0.2
flQuarter	REAL4	0.25
fl03		REAL4	0.3
fl03N		REAL4	-0.3
flThird		REAL4	0.333
flThirdN	REAL4	-0.333
fl04		REAL4	0.4
flHalf		REAL4	0.5
flHalfN		REAL4	-0.5
fl06		REAL4	0.6
fl066		REAL4	0.666
fl07		REAL4	0.7
fl07N		REAL4	-0.7
fl075		REAL4	0.75
fl088		REAL4	0.88
fl09		REAL4	0.9
fl1		REAL4	1.0
fl1N	REAL4	-1.0
fl1n01	REAL4	1.01
fl1n1	REAL4	1.1
fl1n2	REAL4	1.2
fl1n5	REAL4	1.5
fl2		REAL4	2.0
fl2N	REAL4	-2.0
fl2n5	REAL4	2.5
fl3		REAL4	3.0
fl3N	REAL4	-3.0
fl4		REAL4	4.0
fl4N	REAL4	-4.0
fl5		REAL4	5.0
fl6		REAL4	6.0
fl7		REAL4	7.0
fl8		REAL4	8.0
fl8N	REAL4	-8.0
fl9		REAL4	9.0
fl10	REAL4	10.0
fl12	REAL4	12.0
fl12N	REAL4	-12.0
fl13	REAL4	13.0
fl13N	REAL4	-13.0
fl14	REAL4	14.0
fl15	REAL4	15.0
fl16	REAL4	16.0
fl18	REAL4	18.0
fl20	REAL4	20.0
fl20N	REAL4	-20.0
fl24	REAL4	24.0
fl32	REAL4	32.0
fl48	REAL4	48.0
fl64	REAL4	64.0
fl75	REAL4	75.0
fl90	REAL4	90.0
fl90N	REAL4	-90.0
fl96	REAL4	96.0
fl100	REAL4	100.0
fl128	REAL4	128.0
fl180	REAL4	180.0
fl255	REAL4	255.0
fl256	REAL4	256.0
fl360	REAL4	360.0
fl1000	REAL4	1000.0
fl2000	REAL4	2000.0
fl10000	REAL4	10000.0
fl32768	REAL4	32768.0

flFastATan_1 REAL4 0.2447
flFastATan_2 REAL4 0.0663

.DATA?
FPUCW WORD ?
nRandSeed DWORD ?

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

.CODE
flSign PROTO :REAL4
nRand PROTO :DWORD

fcmpP PROC EXPORT
	fcompp
	fstsw ax
	
	push pax
	and ax, 4000h
	xor ax, 4000h
	
	test ax, ax
	pop pax
	
	bt ax, 8
	ret
fcmpP ENDP

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

flDistance PROC EXPORT From:REAL4, To:REAL4
	fld From
	fsub To
	fabs
	fstp From
	mov eax, From
	ret
flDistance ENDP

flEuler PROC EXPORT Val:REAL4
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
flEuler ENDP

flFastATan PROC EXPORT Val:REAL4
	fld Val
	fabs
	fld st
	fsub fl1
	fxch
	fmul flFastATan_2
	fadd flFastATan_1
	fmul
	fmul Val
	fld Val
	fmul PIQuarter
	fsubr
	fstp Val
	mov eax, Val
	ret
flFastATan ENDP

flFastATan2 PROC EXPORT Y:REAL4, X:REAL4
	.IF (X & FLT_NEG)		; x <= 0
		.IF (Y & FLT_NEG)	; y <= 0
			xor Y, FLT_NEG
			fcmp Y, X
			.IF (Carry?)		; -y < x ; -PI/4 .. 0
				xor Y, FLT_NEG
				fld Y
				fdiv X
				fstp X
				invoke flFastATan, X
				ret
			.ELSE
				xor Y, FLT_NEG
				fld X
				fdiv Y
				fstp X
				mov X, rv(flFastATan, X)
				fld X
				fsubr PIHalfN
				fstp X
				mov eax, X
				ret
			.ENDIF
		.ELSE
			fcmp Y, X
			.IF (Carry?)		; y < x ; -PI/4 .. 0
				fld Y
				fdiv X
				fstp X
				invoke flFastATan, X
				ret
			.ELSE
				fld X
				fdiv Y
				fstp X
				mov X, rv(flFastATan, X)
				fld X
				fsubr PIHalf
				fstp X
				mov eax, X
				ret
			.ENDIF
		.ENDIF
	.ELSE
		.IF (Y & FLT_NEG)	; y <= 0
			xor X, FLT_NEG
			xor Y, FLT_NEG
			fcmp Y, X
			.IF (Carry?)		; -y < -x
				xor X, FLT_NEG
				xor Y, FLT_NEG
				fld Y
				fdiv X
				fstp X
				mov X, rv(flFastATan, X)
				fld X
				fsub PI
				fstp X
				mov eax, X
				ret
			.ELSE
				xor X, FLT_NEG
				xor Y, FLT_NEG
				fld X
				fdiv Y
				fstp X
				mov X, rv(flFastATan, X)
				fld X
				fsubr PIHalfN
				fstp X
				mov eax, X
				ret
			.ENDIF
		.ELSE
			xor X, FLT_NEG
			fcmp Y, X
			.IF (Carry?)		; y < -x 
				xor X, FLT_NEG
				fld Y
				fdiv X
				fstp X
				mov X, rv(flFastATan, X)
				fld X
				fadd PI
				fstp X
				mov eax, X
				ret
			.ELSE
				xor X, FLT_NEG
				fld X
				fdiv Y
				fstp X
				mov X, rv(flFastATan, X)
				fld X
				fsubr PIHalf
				fstp X
				mov eax, X
				ret
			.ENDIF
		.ENDIF
	
	.ENDIF
	ret
flFastATan2 ENDP

flFrac PROC EXPORT Val:REAL4
	fstcw FPUCW
	or FPUCW, FPU_FLOOR
	fldcw FPUCW
	
	fld Val
	fld st
	frndint
	fsub
	fstp Val
	
	xor FPUCW, FPU_FLOOR
	fldcw FPUCW
	
	mov eax, Val
	ret
flFrac ENDP

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

flLerp PROC EXPORT A:REAL4, B:REAL4, T:REAL4
	fld B
	fsub A
	fmul T
	fadd A
	fstp A
	
	mov eax, A
	ret
flLerp ENDP

flLerpAngle PROC EXPORT A:REAL4, B:REAL4, T:REAL4
	LOCAL _Ang:REAL4
	fld B
	fsub A
	fstp _Ang
	invoke flEuler, _Ang
	mov _Ang, pax
	fld _Ang
	fmul T
	fadd A
	fstp A
	
	mov eax, A
	ret
flLerpAngle ENDP

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

flMin PROC EXPORT A:REAL4, B:REAL4
	fcmp A, B
	.IF (Carry?)
		mov eax, A
	.ELSE
		mov eax, B
	.ENDIF
	ret
flMin ENDP

; Returns a random REAL4 in range [0.0, 1.0]
flRand PROC EXPORT
	LOCAL _Val:REAL4
	
	invoke nRand, 100
	mov _Val, eax
	fild _Val
	fmul flHundredth
	fstp _Val
	mov eax, _Val
	ret
flRand ENDP

flRandRange PROC EXPORT Min:REAL4, Max:REAL4
	LOCAL _Val:REAL4
	
	invoke nRand, 1000
	mov _Val, eax
	fld Max
	fsub Min
	fild _Val
	fmul flThousandth
	fmul
	fadd Min
	fstp _Val
	mov eax, _Val
	ret
flRandRange ENDP

flRepeat PROC EXPORT Val:REAL4, Max:REAL4
	fstcw FPUCW
	or FPUCW, FPU_FLOOR
	fldcw FPUCW
	
	fld Val
	fdiv Max
	frndint
	fsubr Val
	fmul Max
	fstp Val
	
	xor FPUCW, FPU_FLOOR
	fldcw FPUCW
	
	invoke flClamp, Val, 0, Max
	ret
flRepeat ENDP

flSqrt PROC EXPORT
	fld st			; st(1) = number		(y)
	fmul flHalf		; st(0) = number * 0.5	(x2)
	fxch			; st(0) = y; st(1) = x2
	
	sub esp, 4
	fstp REAL4 PTR [esp]	; st(0) = x2
	pop eax			; i = * (long *) &y;
	
	shr eax, 1
	mov ecx, 5f3759dfh
	sub ecx, eax	; 0x5f3759df - (i >> 1)
	
	push ecx
	fld REAL4 PTR [esp]	; st(0) = y; st(1) = x2
	fld st	; st(0) = y; st(1) = y; st(2) = x2		| esp = y
	fmul	; st(0) = y*y; st(1) = x2
	fmul
	fsubr fl1n5
	fmul REAL4 PTR [esp]
	add esp, 4
	fdivr fl1
	
	ret
flSqrt ENDP

flSign PROC EXPORT Val:REAL4
	.IF (Val & FLT_NEG)
		mov eax, fl1N
		ret
	.ELSE
		mov eax, fl1
	.ENDIF
	ret
	fcmp Val
	.IF (Carry?)
		mov eax, fl1N	; -1.0
		ret
	.ENDIF
	fcmp Val
	.IF (!Carry?)
		mov eax, fl1	; 1.0
		ret
	.ELSE
		xor eax, eax	; 0.0
	.ENDIF
	ret
flSign ENDP

intAbs PROC EXPORT Val:SDWORD
	mov eax, Val
	cmp eax, 0
	jge intAbsNeg
		neg eax
	intAbsNeg:
	ret
intAbs ENDP

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

intDistance PROC EXPORT From:SDWORD, To:SDWORD
	mov eax, From
	sub eax, To
	invoke intAbs, eax
	ret
intDistance ENDP

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

intRandRange PROC EXPORT Min:SDWORD, Max:SDWORD
	mov eax, Max
	sub eax, Min
	invoke nRand, eax
	add eax, Min
	ret
intRandRange ENDP

;   MASM32 Park Miller random number algorithm implementation (nrandom), written
; by Jaymeson Trudgen (NaN), optimized by Rickey Bowers Jr. (bitRAKE).
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

ELSE
	ECHO BP3D: Duplicate include file BP3DMaths.inc
ENDIF
