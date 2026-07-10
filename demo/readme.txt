The demos for BoilPlate3D aim to be optimized to support both MASM and UASM, with the only exception being the DirectX demo (as it is only a proof-of-concept).

./makedemos.bat compiles all demos using /misc/makeit.bat, which requires the preferred assembler and linker to be in PATH. makeit.bat is still in a haphazard state and needs better structuring, but will aim to support the assemblers listed in /README.md.
For help with makeit.bat run it with the /help argument.

Each demo's description can be found in the header of its main.asm.