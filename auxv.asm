format ELF64 
AT_PHDR     equ 3
AT_PHNUM    equ 5
PT_PHDR     equ 6
PT_DYNAMIC  equ 2
DT_NULL     equ 0
DT_HASH     equ 4
DT_STRTAB   equ 5
DT_SYMTAB   equ 6
DT_STRSZ    equ 10
DT_SYMENT   equ 11
DT_VERSYM   equ 0x6ffffff0
DT_GNU_HASH equ 0x6ffffef5
PHDR_SIZE   equ 56
DYN_SIZE    equ 16
AUXV_SIZE   equ 16
E_PHOFF equ 32
E_PHENTSIZE equ 54
E_PHNUM equ 56
TARGET_HASH equ 0x10a8b550
DT_DEBUG    equ 21
L_ADDR      equ 0
L_NAME      equ 8
L_NEXT      equ 24
public _start
section '.text' executable

_start:
	lea	rbx, [rsp + 8]
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

	xor	r12d, r12d
	xor	r13d, r13d

parse_auxv:
	mov	rax, qword [rbx]
	test	rax, rax
	jz	check_phdr
	cmp	rax, AT_PHDR
	je	found_phdr
	cmp	rax, AT_PHNUM
	je	found_phnum

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
	mov	r8, qword [rcx + 16]
	add 	r8, r14
	mov	rbx, qword [rcx + 40]
	shr	rbx, 4
	test	rbx, rbx
	jz	exit
	
parse_dynamic:
	test	rbx, rbx
	jz	exit
	dec	rbx
	mov	rax, qword [r8]
	cmp	rax, DT_NULL
	jz	exit
	cmp	rax, DT_DEBUG
	je	found_debug
	add	r8, DYN_SIZE
	jmp 	parse_dynamic

found_debug:
	mov	rax, [r8 + 8]
	test	rax, rax
	jz	exit
	cmp	dword [rax], 1
	jne	exit
	mov	r12, [rax + 8]
	test	r12, r12
	jz	exit

scan:
	mov	rdi, [r12 + L_NAME]
	test	rdi, rdi
	jz	.next_link
	mov	rsi, rdi
.loop:
	movzx	eax, byte [rsi]
	test	al, al
	jz	.next_link
	cmp	al, 'l'
	jne	.next_char
	mov	rdx, rsi
	inc	rdx
	mov	al, [rdx]
	test	al, al
	jz	.next_char
	cmp	al, 'i'
	jne	.next_char
	inc	rdx
	mov	al, [rdx]
	test	al, al
	jz	.next_char
	cmp	al, 'b'
	jne	.next_char
	inc	rdx
	mov	al, [rdx]
	test	al, al
	jz	.next_char
	cmp	al, 'c'
	jne	.next_char
	inc	rdx
	mov	al, [rdx]
	test	al, al
	jz	.next_char
	cmp	al, '.'
	jne	.next_char
	inc	rdx
	mov	al, [rdx]
	test	al, al
	jz	.next_char
	cmp	al, 's'
	jne	.next_char
	inc	rdx
	cmp	byte [rdx], 'o'
	jne	.next_char
	inc	rdx
	mov	al, [rdx]
	test	al, al
	jz	.check_basename
	cmp	al, '.'
	jne	.next_char
.check_basename:
	cmp	rsi, rdi
	je	.found_libc
	cmp	byte [rsi - 1], '/'
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
	jmp	verify_libc

verify_libc:
	cmp	dword [r15], 0x464C457F
	jne	exit
	cmp	byte [r15 + 4], 2
	jne	exit
	cmp	byte [r15 + 5], 1
	jne	exit
	cmp	byte [r15 + 6], 1
	jne	exit
	cmp	word [r15 + E_PHENTSIZE], PHDR_SIZE
	jne	exit
	mov	rcx, [r15 + E_PHOFF]
	add	rcx, r15
	movzx	r13, word [r15 + E_PHNUM]
	test	r13, r13
	jz	exit
	           
libc_parse_phdr:
	mov	eax, dword [rcx]
	cmp	eax, PT_DYNAMIC      
	je	libc_found_dynamic
	add	rcx, PHDR_SIZE
	dec	r13
	jnz 	libc_parse_phdr
	jmp	exit    

libc_found_dynamic:
	mov	r8, qword [rcx + 16]
	add 	r8, r15
	mov	r12, qword [rcx + 40]
	shr	r12, 4
	test	r12, r12
	jz	exit
	xor	r9d, r9d
	xor	r10d, r10d
	xor	r11d, r11d
	xor	r13d, r13d
	xor	edi, edi

libc_parse_dynamic:
	test	r12, r12
	jz	exit
	dec	r12
	mov	rax, qword [r8]
	cmp	rax, DT_NULL
	jz	start_resolving
	cmp	rax, DT_HASH
	jz	libc_found_hash
	cmp	rax, DT_STRTAB
	jz	libc_found_strtab
	cmp	rax, DT_SYMTAB
	jz	libc_found_symtab
	cmp	rax, DT_STRSZ
	jz	libc_found_strsz
	cmp	rax, DT_SYMENT
	jz	libc_found_syment
	cmp	rax, DT_VERSYM
	jz	libc_found_versym
	cmp	rax, DT_GNU_HASH
	jz	libc_found_gnuhash
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_strtab:
	mov	r9, qword [r8 + 8]
	cmp	r9, r15
	jae	.strtab_done
	add	r9, r15
.strtab_done:
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_symtab:
	mov	r10, qword [r8 + 8]
	cmp	r10, r15
	jae	.symtab_done
	add	r10, r15
.symtab_done:
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_strsz:
	mov	r11, qword [r8 + 8]
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_syment:
	cmp	qword [r8 + 8], 24
	jne	exit
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_versym:
	mov	rdi, qword [r8 + 8]
	cmp	rdi, r15
	jae	.versym_done
	add	rdi, r15
.versym_done:
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_hash:
	mov	r14, qword [r8 + 8]
	cmp	r14, r15
	jae	.hash_done
	add	r14, r15
.hash_done:
	mov	r13d, dword [r14 + 4]
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

libc_found_gnuhash:
	mov	r14, qword [r8 + 8]
	cmp	r14, r15
	jae	.gnuhash_ptr_done
	add	r14, r15
.gnuhash_ptr_done:
	mov	ecx, dword [r14]
	mov	edx, dword [r14 + 8]
	lea	rbp, [r14 + 16 + rdx * 8]
	lea	rbx, [rbp + rcx * 4]
	xor	r13d, r13d
.bucket_loop:
	test	ecx, ecx
	jz	.gnuhash_done
	mov	edx, dword [rbp]
	test	edx, edx
	jz	.bucket_next
	mov	esi, dword [r14 + 4]
	cmp	edx, esi
	jb	.bucket_next
	mov	eax, edx
	sub	eax, esi
	lea	rax, [rbx + rax * 4]
.chain_loop:
	mov	esi, dword [rax]
	inc	edx
	test	esi, 1
	jnz	.chain_done
	add	rax, 4
	jmp	.chain_loop
.chain_done:
	cmp	edx, r13d
	jbe	.bucket_next
	mov	r13d, edx
.bucket_next:
	add	rbp, 4
	dec	ecx
	jmp	.bucket_loop
.gnuhash_done:
	add	r8, DYN_SIZE
	jmp 	libc_parse_dynamic

hash_string:
	mov	eax, 5381
.loop:
	test	rdx, rdx
	jz	.unterminated
	movzx	ecx, byte [rsi]
	dec	rdx
	test	cl, cl               
	jz	.done
	imul	eax, eax, 33
	add	eax, ecx
	inc	rsi                  
	jmp	.loop
.done:
	ret
.unterminated:
	xor	eax, eax
	ret


start_resolving:
	test	r9, r9
	jz	exit
	test	r10, r10
	jz	exit
	test	r11, r11
	jz	exit
	test	r13, r13
	jz	exit
	mov 	r12, r10
	xor	r14d, r14d
	mov	ebx, TARGET_HASH

resolve:
	test	r13, r13
	jz	exit
	mov	eax, dword [r12]
	test	eax, eax
	jz	.skip
	cmp	rax, r11
	jae	.skip
	cmp	word [r12 + 6], 0
	je	.skip
	test	rdi, rdi
	jz	.version_ok
	movzx	edx, word [rdi + r14 * 2]
	test	edx, 0x8000
	jnz	.skip
.version_ok:
	movzx	edx, byte [r12 + 4]
	mov	ecx, edx
	shr	ecx, 4
	cmp	ecx, 1
	je	.bind_ok
	cmp	ecx, 2
	jne	.skip
.bind_ok:
	and	edx, 0x0f
	cmp	edx, 2
	je	.type_ok
	cmp	edx, 10
	jne	.skip
.type_ok:
	cmp	qword [r12 + 8], 0
	je	.skip
	mov	r8d, edx
	mov	rdx, r11
	sub	rdx, rax
	mov 	rsi, r9
	add	rsi, rax
	call 	hash_string
	cmp	eax, ebx
	jne	.skip
	cmp	r8d, 10
	je	found_ifunc
	jmp	found_api
.skip:
	add	r12, 24
	inc	r14
	dec	r13
	jmp 	resolve

found_api:
	mov	rax, qword [r12 + 8]
	add	rax, r15
	mov	r14, rax
	jmp	call_api

found_ifunc:
	mov	rax, qword [r12 + 8]
	add	rax, r15
	mov	rbp, rsp
	and	rsp, -16
	call	rax
	mov	rsp, rbp
	test	rax, rax
	jz	exit
	mov	r14, rax

call_api:
	mov	rbp, rsp
	and	rsp, -16
	mov	edi, 1
	lea	rsi, [msg]
	mov	edx, 10
	call	r14
	mov	rsp, rbp

exit:
	mov	eax, 60
	xor	edi, edi
	syscall

section '.data' writeable
msg	db 'Syn4psed!', 10
