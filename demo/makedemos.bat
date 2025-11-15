@echo off

cd brown
echo Building .\brown
call ..\makeit main.asm /o "BP3D Brown Demo.exe" /b /q
cd ..

cd directx
echo Building .\directx
call ..\makeit main.asm /o "BP3D DirectX 9 Demo.exe" /b /w /q
cd ..

cd forms
echo Building .\forms
call ..\makeit main.asm /o "BP3D Forms Demo.exe" /b /q
cd ..

cd softbody
echo Building .\softbody
call ..\makeit main.asm /o "BP3D Softbody Demo.exe" /b /q
cd ..