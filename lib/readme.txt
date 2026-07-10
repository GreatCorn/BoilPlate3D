Here is an attempt to structure BoilPlate3D into a Dynamic-Link Library; however, the best approach to this is still under question, as BP3D poses itself as a modular framework. There are a couple of ideas for solutions, which include:
 - dynamic .DEF generation and a versatile compile batch script to allow choosing the desired components, apart from the base include;
 - either the full combined library, or separate ones for each module;
 - rethinking the base philosophies behind BoilPlate3D and rewriting it for more natural versatility outside of MASM.
It would also be nice to generate the .DEF files automatically, based on the source code, regardless of the approach, but delving that deep into Batch coding isn't something I envisioned doing when starting this project. On the other hand, a custom-suited binary seems like overkill.

For now, what is present in this folder is merely a test of the first solution. ./makedll.bat generates a .DEF file for the resulting library, which at the moment includes only the base BP3D.asm.