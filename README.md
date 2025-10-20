# BoilPlate3D
BP3D (short for BoilPlate3D) is a MASM-compatible (which means ideally targeting other MASM-compatible assemblers) scripted framework that aims to reduce the amount of redundant boilerplate code by providing a generalized but flexible Win32 form API.

BP3D implements a somewhat OOP-like form API to easily and quickly create and manage windows, oriented for developing 3D graphics with OpenGL. It supports automatic keyboard and mouse (+raw) and joystick input configuration. The forms also provide multiple display device functionality. BP3D started with the OpenGL fixed-function pipeline for game development, but can be set up for use with other graphics APIs.

BP3D aims to support various WinAPI clients, which include (tested):
- Windows 2000 - 10
- ReactOS
- Wine (Linux, BSD)

BP3D is built with future x64 support in mind, though it now remains untested and not fully configured for it. Right now, BP3D is tested for compileability with: MASM32, ASMC (32-bit), and UASM (32-bit; 64-bit compile only, can't link). POASM and TASM support might be considered in the future. BP3D supports MASM32 and WinInc Windows headers.

***

Copyright © 2025 Yevhenii Ionenko (aka GreatCorn). All rights reserved.

Licensed under the terms of the MIT license (see LICENSE.txt).

https://greatcorn.github.io/me/
