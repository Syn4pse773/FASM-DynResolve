format ELF64 
AT_PHDR     equ 3
AT_PHNUM    equ 5
PT_PHDR     equ 6
PT_DYNAMIC  equ 2
DT_NULL     equ 0
DT_STRTAB   equ 5
DT_SYMTAB   equ 6
PHDR_SIZE   equ 56
DYN_SIZE    equ 16
AUXV_SIZE   equ 16
AT_SYSINFO_EHDR equ 33
E_PHOFF equ 32
E_PHNUM equ 56
TARGET_HASH equ 0x6e43a318
DT_DEBUG    equ 21
L_ADDR      equ 0
L_NAME      equ 8
L_NEXT      equ 24
public _start
section '.text' executable

_start:
	mov	rbx, rsp
	add	rbx, 8
@@:
	mov	rax, qword [rbx]
	add	rbx, 8
	test	rax, rax
	jnz	@b

skip_envp:
	mov	rax, qword [rbx]
	add 	rbx, 8
	test	rax, rax
	jnz	skip_envp

	xor	r12, r12 
	xor	r13, r13 

parse_auxv:
	mov	rax, qword [rbx]
	test	rax, rax
	jz	check_phdr
	cmp	rax,  AT_PHDR  
	je	found_phdr
	cmp	rax, AT_PHNUM     
	je	found_phnum
	cmp	rax, AT_SYSINFO_EHDR
	je	found_vdso
	jmp 	next_auxv

found_vdso:
	mov	r11, [rbx + 8]
	

next_auxv:
	add	rbx, AUXV_SIZE
	jmp 	parse_auxv

found_phdr:
	mov	r12, [rbx + 8]
	jmp	next_auxv

found_phnum:
	mov	r13, [rbx + 8]
	jmp	next_auxv

check_phdr:
	test	r12, r12
	jz	exit
	test	r13, r13
	jz	exit
	mov	rcx, r12
	mov	r15, r13

find_base:
	mov	eax, dword [rcx]
	cmp	eax, PT_PHDR
	je	found_pt_phdr
	add 	rcx, PHDR_SIZE
	dec 	r15
	jnz 	find_base
	jmp	exit

found_pt_phdr:
	mov	rax, qword [rcx + 16]
	mov	r14, r12
	sub	r14, rax
	
	mov	rcx, r12
	mov	r15, r13

parse_phdr:
	mov	eax, dword [rcx]
	cmp	eax, PT_DYNAMIC      
	je	found_dynamic
	add	rcx, PHDR_SIZE
	dec	r15
	jnz 	parse_phdr
	jmp	exit        

found_dynamic:
	mov	rdx, qword [rcx + 16]
	add 	rdx, r14
	mov	r8, rdx
	
parse_dynamic:
	mov	rax, qword [r8]
	cmp	rax, DT_NULL
	jz	verify_vdso
	cmp	rax, DT_STRTAB
	jz	found_strtab
	cmp	rax, DT_SYMTAB
	jz	found_symtab
	cmp	rax, DT_DEBUG
	je	found_debug
	add	r8, DYN_SIZE
	jmp 	parse_dynamic

found_debug:
	mov	rax, [r8 + 8]
	mov	r12, [rax + 8]

scan:
	mov	rsi, [r12 + L_NAME]
	test	rsi, rsi
	jz	.next_link
.loop:
	movzx	eax, byte [rsi]
	test	al, al
	jz	.next_link
	cmp	al, 'c'
	jne	.next_char
	cmp	byte [rsi + 1], '.'
	jne	.next_char
	cmp	byte [rsi + 2], 's'
	je	.found_libc
.next_char:
	inc	rsi
	jmp	.loop

.next_link:
	mov	r12, [r12 + L_NEXT]
	test	r12, r12
	jz	exit
	jmp	scan

.found_libc:
	mov	r15, [r12 + L_ADDR]
	jmp	verify_vdso

found_strtab:
	mov	r9, qword [r8 + 8]
	add	r9, r14
	add	r8, DYN_SIZE
	jmp 	parse_dynamic

found_symtab:
	mov	r10, qword [r8 + 8]
	add	r10, r14
	add	r8, DYN_SIZE
	jmp 	parse_dynamic

verify_vdso:
	cmp	dword [r11], 0x464C457F   
	jne	exit  
	mov	rcx, [r11 + E_PHOFF]
	add	rcx, r11
	movzx	r13, word [r11 + E_PHNUM] 
	           
vdso_parse_phdr:
	mov	eax, dword [rcx]
	cmp	eax, PT_DYNAMIC      
	je	vdso_found_dynamic
	add	rcx, PHDR_SIZE
	dec	r13
	jnz 	vdso_parse_phdr
	jmp	exit    

vdso_found_dynamic:
	mov	rdx, qword [rcx + 16]     
	add 	rdx, r11                
	mov	r8, rdx

vdso_parse_dynamic:
	mov	rax, qword [r8]
	cmp	rax, DT_NULL
	jz	start_resolving
	cmp	rax, DT_STRTAB
	jz	vdso_found_strtab
	cmp	rax, DT_SYMTAB
	jz	vdso_found_symtab
	add	r8, DYN_SIZE
	jmp 	vdso_parse_dynamic

vdso_found_strtab:
	mov	r9, qword [r8 + 8]
	add	r9, r11                   
	add	r8, DYN_SIZE
	jmp 	vdso_parse_dynamic

vdso_found_symtab:
	mov	r10, qword [r8 + 8]
	add	r10, r11                  
	add	r8, DYN_SIZE
	jmp 	vdso_parse_dynamic

hash_string:
	mov	rax, 5381             
.loop:
	movzx	rcx, byte [rsi]      
	test	cl, cl               
	jz	.done
	imul	rax, rax, 33        
	add	rax, rcx         
	inc	rsi                  
	jmp	.loop
.done:
	and	eax, 0xFFFFFFFF     
	ret


start_resolving:
	mov 	r12, r10
	mov	r13, 30
	mov	r15, TARGET_HASH

resolve:
	mov	eax, dword [r12]
	test	eax, eax
	jz	.next
	mov 	rsi, r9
	add	rsi, rax
	call 	hash_string
	cmp	rax, r15
	je	found_api
	add	r12, 24
	dec	r13
	jnz 	resolve
	jmp	exit
.next:
	add 	r12, 24
	dec 	r13
	jnz 	resolve
found_api:
	mov	rax, qword [r12 + 8]
	add	rax, r11
	mov	r14, rax
exit:
	mov	rax, 60
	xor	rdi, rdi
	syscall
