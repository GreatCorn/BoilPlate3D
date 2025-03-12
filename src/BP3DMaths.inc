IFNDEF BP3DMATHS_INC
BP3DMATHS_INC equ <1>

; -----	INTERFACE -----

FPU_TRUNC	EQU 0000110000000000b
FPU_CEIL	EQU 0000100000000000b
FPU_FLOOR	EQU 0000010000000000b
FPU_ROUND	EQU 0000000000000000b

.CONST
D2R		REAL4	0.0174532	; Degrees to radians multiplier
R2D		REAL4	57.29578	; Radians to degrees multiplier
R2I		REAL4	0.6366197	; Radians to integer
PI		REAL4	3.1415927
PIN		REAL4	-3.1415927
PIHalf	REAL4	1.5707
PIHalfN	REAL4	-1.5707
PI2		REAL4	6.2831

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
fl10	REAL4	10.0
fl12	REAL4	12.0
fl12N	REAL4	-12.0
fl13	REAL4	13.0
fl13N	REAL4	-13.0
fl14	REAL4	14.0
fl15	REAL4	15.0
fl16	REAL4	16.0
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

.DATA?
nRandSeed DWORD ?

; Floating point comparison macro and PROC by jj2007
fcmp MACRO cmp1:REQ, cmp2
	LOCAL oa
	ffree st(7)
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
	ffree st(7)
	fld cmp1
	call fcmpP
ENDM

.CODE
flSign PROTO :REAL4
nRand PROTO :DWORD

fcmpP PROC
	push edx
	xor edx, edx	; Clear the flag register
	fcompp			; Compare ST(0) with ST(1) and pop twice
	fstsw ax		; Move FPU flags C1 etc to ax
	test ah, 64		; C3 is set if ST=0 (bt eax, 14)
	jne @F			; Equal, edx=0
	test ah, 1		; C0 (bt eax, 8)
	je fcPos
	dec edx			; Negative (-2+1=-1)
	@@:		dec edx	; Zero (0-1+1=0)
	fcPos:	inc edx	; Positive
		pop edx
		ret
fcmpP ENDP

flClamp PROC Val:REAL4, Min:REAL4, Max:REAL4
	fcmp Val, Max
	.IF !Sign? && !Zero?		; X > X1
		fld Max
		fstp Val
	.ELSE
		fcmp Val, Min
		.IF Sign? && !Zero?		; X < X1
			fld Min
			fstp Val
		.ENDIF
	.ENDIF
	
	mov eax, Val
	ret
flClamp ENDP

flDistance PROC From:REAL4, To:REAL4
	fld From
	fsub To
	fabs
	fstp From
	mov eax, From
	ret
flDistance ENDP

flEuler PROC Val:REAL4
	fcmp Val, PI
	.IF !Sign? && !Zero?	; Val > PI
		fld Val
		fsub PI2
		fstp Val
	.ENDIF
	fcmp Val, PIN
	.IF Sign? && !Zero?		; Val < -PI
		fld Val
		fadd PI2
		fstp Val
	.ENDIF
	
	mov eax, Val
	ret
flEuler ENDP

flFrac PROC Val:REAL4
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

flLerp PROC A:REAL4, B:REAL4, T:REAL4
	fld B
	fsub A
	fmul T
	fadd A
	fstp A
	
	mov eax, A
	ret
flLerp ENDP

flLerpAngle PROC A:REAL4, B:REAL4, T:REAL4
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

flMove PROC From:REAL4, To:REAL4, T:REAL4
	LOCAL Dist:REAL4	
	invoke flDistance, From, To
	mov Dist, eax
	fcmp Dist, T
	.IF Sign?
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

flMin PROC A:REAL4, B:REAL4
	fcmp A, B
	.IF (Sign?)
		mov eax, A
	.ELSE
		mov eax, B
	.ENDIF
	ret
flMin ENDP

; Returns a random REAL4 in range [0.0, 1.0]
flRand PROC
	LOCAL _Val:REAL4
	
	invoke nRand, 100
	mov _Val, eax
	fild _Val
	fmul flHundredth
	fstp _Val
	mov eax, _Val
	ret
flRand ENDP

flRandRange PROC Min:REAL4, Max:REAL4
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

flRepeat PROC Val:REAL4, Max:REAL4
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

flSign PROC Val:REAL4
	fcmp Val
	.IF (Sign? && !Zero?)
		mov eax, fl1N	; -1.0
		ret
	.ENDIF
	fcmp Val
	.IF (!Sign? && !Zero?)
		mov eax, fl1	; 1.0
		ret
	.ELSE
		xor eax, eax	; 0.0
	.ENDIF
	ret
flSign ENDP

intAbs PROC Val:SDWORD
	mov eax, Val
	cmp eax, 0
	jge intAbsNeg
		neg eax
	intAbsNeg:
	ret
intAbs ENDP

intClamp PROC Val:SDWORD, Min:SDWORD, Max:SDWORD
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

intDistance PROC From:SDWORD, To:SDWORD
	mov eax, From
	sub eax, To
	invoke intAbs, eax
	ret
intDistance ENDP

intInRange PROC Val:SDWORD, Min:SDWORD, Max:SDWORD
	mov eax, Val
	cmp eax, Min
	jl intInRangeFalse
	cmp eax, Max
	jg intInRangeFalse
	mov al, TRUE
	ret
	intInRangeFalse:
	mov al, FALSE
	ret
intInRange ENDP

intRandRange PROC Min:SDWORD, Max:SDWORD
	mov eax, Max
	sub eax, Min
	invoke nRand, eax
	add eax, Min
	ret
intRandRange ENDP

;   MASM32 Park Miller random number algorithm implementation (nrandom), written
; by Jaymeson Trudgen (NaN), optimized by Rickey Bowers Jr. (bitRAKE).
nRand PROC Base:DWORD
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
