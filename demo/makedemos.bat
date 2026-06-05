@echo off

cd brown
echo Building .\brown
call ..\..\misc\makeit main.asm /o "BP3D Brown Demo.exe" /b /q
cd ..

cd directx
echo Building .\directx
call ..\..\misc\makeit main.asm /o "BP3D DirectX 9 Demo.exe" /b /w /q
cd ..

cd forms
echo Building .\forms
call ..\..\misc\makeit main.asm /o "BP3D Forms Demo.exe" /b /q
cd ..

cd softbody
echo Building .\softbody
call ..\..\misc\makeit main.asm /o "BP3D Softbody Demo.exe" /b /q
cd ..

cd software
echo Building .\software
call ..\..\misc\makeit main.asm /o "BP3D Software Demo.exe" /b /q
cd ..

cd transparent
echo Building .\transparent
call ..\..\misc\makeit main.asm /o "BP3D Transparent Demo.exe" /b /q
cd ..