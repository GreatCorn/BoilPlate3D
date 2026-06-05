(
	echo LIBRARY BP3D
	echo EXPORTS
	echo bpFormDefault
	echo bpGetAddress
) > BP3DLibrary.def
type BP3D.def >> BP3DLibrary.def
call ..\misc\makeit BP3DLibrary.asm /o "BP3D.dll" /l /b