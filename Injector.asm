format pe64 dll
include "win64ax.inc"
entry _DllMain

section '.data' data readable writeable


; SETUP begin
Version: db "[VERSION]-> v2",10,0
LoadSuccess: db "[SETUP]-> Load success",10,0
StackSuccess: db "[SETUP]-> Stack verified",10,0
InitialVEHSetup: db "[SETUP]-> Adding exception handler",10,0
AddVEHSuccess: db "[SETUP]-> Successfully added exception handler",10,0
; SETUP end


; INJECTION begin
GWTPIDSuccess: db "[INJECTION]-> Successfully got window thread's process ID",10,0
FindWindowASuccess: db "[INJECTION]-> Found window",10,0
OpenProcessSuccess: db "[INJECTION]-> Successfully opened a handle",10,0
VirtualAllocSuccess: db "[INJECTION]-> Successfully allocated memory",10,0
WPMSuccess: db "[INJECTION]-> Successfully wrote string to memory",10,0
CRTSuccess: db "[INJECTION]-> Successfully created remote thread",10,0
InjectionSuccess: db "[INJECTION]-> Successfully injected",10,0
; INJECTION end



; ERROR begin
GWTPIDFailure: db "[ERROR]-> Failed to get window thread's process ID",10,0
FindWindowAFailure: db "[ERROR]-> Failed to find window",10,0
OpenProcessFailure: db "[ERROR]-> Failed to open a handle",10,0
VirtualAllocFailure: db "[ERROR]-> Failed to allocate memory",10,0
AddVEHFailure: db "[ERROR]-> Failed to add VEH",10,0
WPMFailure: db "[ERROR]-> Failed to write string to memory",10,0
CRTFailure: db "[ERROR]-> Failed to create remote thread",10,0
ExceptionOccured: db "[ERROR]-> Exception occured {%x}",10,0
; ERROR end


;others
strlength: dq ? ;feel free to define this as a byte, i just didnt bother so i can simplify the code
hObject: dq ?
StringFRMT: db "%s",0
ProcessHandle: dq ?
BPSave: dq ?
WindowName: dq ?
DllPathPointer: dq ?
ProcID: dq ?
AllocPointer: dq ?

section '.txt' code executable writeable
_DllMain:
	mov [hObject],rcx
	mov rax,1
	ret


_ExceptionHandler:
	mov rcx,[rcx] ;EXCEPTION_RECORD*
	mov rdx,[rcx] ;*EXCEPTION_RECORD* (ExceptionCode)
	mov rcx,ExceptionOccured
	call [printf]


	mov rbp,[BPSave]
	mov rsp,rbp
	pop rbp

	mov rax,0
	ret




;bool _Inject(const char* WindowName,const char* DllPath);
_Inject:
	push rbp
	mov rbp,rsp
	mov [BPSave],rbp ;i dont know why RBP dies when exec flow goes to handler, so here is my workaround :)
	;so the idea is
	;rcx = WindowName
	;rdx = PathToDll
	;??
	mov [WindowName],rcx
	mov [DllPathPointer],rdx
	mov r15,FindWindowAFailure

	sub rsp,56
		mov rcx,StringFRMT
		mov rdx,Version
		call [printf]
		
		mov rcx,StringFRMT
		mov rdx,LoadSuccess
		call [printf]

		mov rcx,StringFRMT
		mov rdx,StackSuccess ;check if i aligned the stack correctly (pretty useless but i just left it in)
		call [printf]





		mov rcx,StringFRMT
		mov rdx,InitialVEHSetup
		call [printf]
		
		mov rcx,1
		mov rdx,_ExceptionHandler
		call [AddVEH] ;add VEH for exception handling, just added so that debugging becomes easier
		cmp rax,0
		je _Exit
		
		mov rcx,StringFRMT
		mov rdx,AddVEHSuccess
		call [printf]
		
		;find the window
		mov rdx,[WindowName]
		mov rcx,0
		call [FindWindowA]
		cmp rax,0 ;check if the function crashed
		mov rcx,StringFRMT ;you will be seeing this kind of error checking in almost every function, i know its ugly but ehh
		cmove rdx,r15 ;if function failed, mov error to rdx, then call printf and exit
		je _Exit
		mov rdx,FindWindowASuccess
		mov r14,rax
		call [printf]
		

		;get the window thread's PID
		mov rcx,r14
		mov rdx,ProcID
		call [GWTPID]
		cmp rax,0
		mov r15,GWTPIDFailure
		mov rcx,StringFRMT ;look at windowname for every function
		cmove rdx,r15
		je _Exit
		mov rdx,GWTPIDSuccess
		call [printf]
		
		;open a process_all_access handle
		mov rcx,PROCESS_ALL_ACCESS
		mov rdx,0
		mov r8,[ProcID]
		call [OpenProcess]
		cmp rax,-1
		mov r15,OpenProcessFailure
		mov rcx,StringFRMT
		cmove rdx,r15
		je _Exit
		mov rdx,OpenProcessSuccess
		mov [ProcessHandle],rax
		call [printf]
		


		mov rcx,[DllPathPointer]
		call [strlen]
		inc rax
	        mov [strlength],rax ;no need for error checking here, you can add it if you want but im too lazy
		
		mov rcx,[ProcessHandle] ;allocate a memory page to write the string to
		mov rdx,0
		mov r8,[strlength]
		mov r9, 0x3000 ; MEM_COMMIT | MEM_RESERVE
		mov dword [rsp+32],PAGE_EXECUTE_READWRITE ;doesnt work if it doesnt get formatted as a dword
		call [VirtualAllocEx]
		cmp rax,0
		mov r15,VirtualAllocFailure ;again failure checking 
		mov rcx,StringFRMT
		cmove rdx,r15	
		je _Exit
		mov rdx,VirtualAllocSuccess
		mov [AllocPointer],rax
		call [printf]
			
		mov rcx,[ProcessHandle]
		mov rdx,[AllocPointer]
		mov r8,[DllPathPointer]
		mov r9,[strlength]
		push 0
		call [WPM] ;write DllPath to process memory
		cmp rax,0
		mov r15,WPMFailure
		mov rcx,StringFRMT
		cmove rdx,r15 ;again
		je _Exit
		mov rdx,WPMSuccess
		call [printf]
		
		;create a remote thread that calls LoadLibraryA using the string we wrote to memory
		mov rcx,[ProcessHandle]
		mov rdx,0
		mov r8,0
		mov r9,[LoadLibraryA]
		mov rax,[AllocPointer]
		mov qword [rsp+32],rax
		mov qword [rsp+40],0 	;now here is some stack shenanigans, after r9 you have to pass the arguments in reverse order (top of stack gets popped first) 
		mov qword [rsp+48],0	
		call [CRT]
		
		cmp rax,0
		mov r15,CRTFailure
		mov rcx,StringFRMT
		cmove rdx,r15
		je _Exit
		mov rdx,CRTSuccess
		call [printf]
		mov rcx,StringFRMT
		mov rdx,InjectionSuccess
		call [printf]

		;mov rcx,0	
		;mov rcx,[rcx] ;simulate 0xC00005 (to check the VEH)


	
	add rsp,56
	add rsp,8 ; <- no clue what happened here, something fucked up our stack, this is needed to get return address to be on top of the stack
	pop rbp 
	mov rax,1
	ret

_Exit:
	call [printf]
	mov rsp,rbp
	pop rbp
	mov rax,0
	ret

section '.idata' import data readable
library msvcrt,"msvcrt.dll",krnl32,"kernel32.dll",usr32,"User32.dll"
import usr32,FindWindowA,"FindWindowA",GWTPID,"GetWindowThreadProcessId"
import msvcrt,printf,"printf",strlen,"strlen"
import krnl32,WPM,"WriteProcessMemory",VirtualAllocEx,"VirtualAllocEx",CRT,"CreateRemoteThread",OpenProcess,"OpenProcess",AddVEH,"AddVectoredExceptionHandler",FreeLibraryAndExitThread,"FreeLibraryAndExitThread",LoadLibraryA,"LoadLibraryA"


section '.edata' export data readable
export "injector_v2.dll",_Inject,"Inject" ;export _Inject as "inject" 


section '.relocs' fixups data readable
if $=$$
	dd 8,0
end if
