format pe64 console
include "win64ax.inc"
entry _main

section '.data' data readable writeable
stringfrmt: db "%s",0
TestSuccess: db "[LOADER]-> DLL Successfully finished execution",0
TestFailure: db "[LOADER]-> DLL Execution failed",0
TestString: db "window name here",0
TestDllPath: db "path to dll here",0

section '.text' code executable writeable
_main:
	sub rsp,40
	;(WindowName,DllPath)
	mov rcx,TestString
	mov rdx,TestDllPath
	call [TestFunction]
	;?
	

	mov r15,TestSuccess
	mov r14,TestFailure
	cmp rax,1
	cmove rdx,r15
	cmovne rdx,r14
	mov rcx,stringfrmt
	call [printf]

	add rsp,40
	mov rax,1
	ret


section '.idata' import data readable
library Api,"injector.dll",msvcrt,"msvcrt.dll"
import Api,TestFunction,"Inject"
import msvcrt,printf,"printf"



