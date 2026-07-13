# FASM-DynResolve

FASM-DynResolve is a Linux x86-64 dynamic API resolver written in flat assembler. It enters at `_start`, does not use libc startup code, walks the initial process stack to parse `auxv`, finds the dynamic linker debug rendezvous, locates libc in the `link_map`, parses libc's in-memory ELF metadata, resolves `write` by hash, calls it, and exits with a raw syscall.

This is intended as a compact systems-programming example of ELF process introspection. It is not a replacement for `dlsym(3)` or the dynamic linker's full symbol lookup machinery.

## Supported Environment

- Linux x86-64 System V ABI.
- glibc dynamic executables loaded by `ld-linux-x86-64.so.2`.
- PIE (`ET_DYN`) and non-PIE dynamically linked executables (`ET_EXEC`).
- libc objects that expose `DT_STRTAB`, `DT_SYMTAB`, `DT_STRSZ`, `DT_SYMENT`, and either `DT_GNU_HASH` or `DT_HASH`.

Static binaries and musl/Alpine are not supported by this implementation. The resolver intentionally depends on glibc's `DT_DEBUG -> struct r_debug -> link_map` path, which is not a portable libc interface.

## Features

- No libc startup: the program starts directly at `_start` and terminates with `sys_exit`.
- Auxv parsing: extracts `AT_PHDR` and `AT_PHNUM` directly from the initial stack.
- PIE and ET_EXEC support: calculates load bias as `AT_PHDR - PT_PHDR.p_vaddr`.
- glibc link-map discovery: reads `DT_DEBUG`, validates `r_debug.r_version`, and traverses `link_map` to find `libc.so`.
- In-memory libc ELF parsing: validates ELF64 little-endian headers and walks libc program headers to find `PT_DYNAMIC`.
- Bounded dynamic parsing: uses `PT_DYNAMIC.p_memsz` to avoid unbounded dynamic-section scans.
- Bounded symbol search: derives the dynamic symbol count from `DT_GNU_HASH`, with `DT_HASH` as a fallback.
- String bounds checking: verifies `st_name < DT_STRSZ` before hashing a symbol name.
- Symbol filtering: resolves only defined global/weak `STT_FUNC` symbols, with explicit handling for `STT_GNU_IFUNC`.
- Version filtering: skips hidden version entries through `DT_VERSYM` when present.
- Hash-based API selection: uses a 32-bit djb2 hash (`0x10a8b550` for `write`) instead of storing the target API name.

## Build

Prerequisites:

- FASM 1.73 or newer.
- GCC and binutils.
- glibc development/runtime environment.

Build the default PIE executable:

```bash
make
./auxv
```

Build a non-PIE dynamically linked `ET_EXEC` executable:

```bash
make exec
./auxv_static
```

The legacy target name is also kept for compatibility:

```bash
make static
./auxv_static
```

Despite the historical target name, `auxv_static` is not a fully static binary. It is a dynamically linked non-PIE executable. A fully static binary does not provide the same `DT_DEBUG`/`link_map` resolver path.

## How It Works

1. `_start` skips `argc`, `argv`, and `envp` on the initial stack until it reaches `auxv`.
2. The auxv parser records `AT_PHDR` and `AT_PHNUM`.
3. The main executable's load bias is computed from the runtime program-header address and the `PT_PHDR` virtual address.
4. The main executable's `PT_DYNAMIC` segment is scanned within its declared `p_memsz` bound until `DT_DEBUG` is found.
5. `DT_DEBUG` yields glibc's `struct r_debug`; `r_map` is used to traverse the loaded-object `link_map`.
6. The resolver searches for a basename-compatible `libc.so` entry and uses `l_addr` as libc's load base.
7. libc's ELF header and program headers are validated, then libc's `PT_DYNAMIC` segment is parsed.
8. `DT_STRTAB`, `DT_SYMTAB`, `DT_STRSZ`, `DT_SYMENT`, optional `DT_VERSYM`, and `DT_GNU_HASH`/`DT_HASH` are collected.
9. The resolver walks the bounded dynamic symbol table, filters invalid symbols, hashes candidate names with djb2, and compares against `TARGET_HASH`.
10. If the match is a normal function, the resolver calls `libc_base + st_value`. If the match is an IFUNC, it first calls the IFUNC resolver and then calls the returned implementation pointer.
11. The resolved `write` function prints the message, then the program exits via raw `sys_exit`.

## Correctness Notes

The code deliberately treats dynamic-section pointers defensively. For libc, some loaders expose relocated absolute `d_ptr` values in memory, while file metadata displays unrelocated virtual addresses. The resolver accepts both by adding libc's base only when a pointer is below the libc load base.

The resolver does not implement full `ld.so` semantics. In particular, it does not support arbitrary lookup scopes, interposition rules, audit modules, TLS symbols, lazy relocation machinery, or selecting a specific public symbol version such as `GLIBC_2.2.5`. It does skip hidden version entries when `DT_VERSYM` is present.

## Project Layout

- `auxv.asm`: main FASM implementation.
- `Makefile`: PIE and non-PIE dynamic builds.

## License

This project is licensed under the GNU General Public License v2.0 (GPLv2). See `LICENSE` for details.
