# FASM-DynResolve

A pure x86-64 assembly implementation (FASM) for stealthily resolving dynamic libraries (`libc.so`) and `vDSO` base addresses without relying on standard library functions. 

This project manually parses the ELF auxiliary vector (`auxv`), program headers (`PT_PHDR`, `PT_DYNAMIC`), and `.dynamic` sections to perform dynamic API resolution. It robustly calculates the load bias, making it universally compatible with both Position-Independent Executables (PIE / `ET_DYN`) and standard static executables (`ET_EXEC`).

## Features

- **Zero Dependencies**: Pure FASM assembly, no need for `libc` startup code or standard library functions.
- **Universal Load Bias Calculation**: Correctly calculates the load bias for both `ET_EXEC` and `ET_DYN` by inspecting the `PT_PHDR` segment.
- **vDSO Parsing**: Extracts the `vDSO` base address from `AT_SYSINFO_EHDR` in the auxiliary vector and parses its dynamic section.
- **Stealth libc Discovery**: Locates the `libc.so` base address by traversing the `DT_DEBUG` `r_debug` link map instead of relying on predictable memory layouts.
- **Hash-based API Resolution**: Resolves APIs by hashing their names and comparing them against the target hash, eliminating the need to store plain-text API names in the binary.

## Build Instructions

You can build this project using FASM and GCC (for the linker phase). 

### Prerequisites
- FASM (flat assembler)
- GCC

### Build as PIE (Position-Independent Executable)
This is the recommended approach for modern Linux systems.
```bash
make
# or manually:
# fasm auxv.asm
# gcc -nostartfiles auxv.o -o auxv
```

### Build as Static Executable (ET_EXEC)
If you want to build it as a classic non-PIE executable:
```bash
make static
# or manually:
# fasm auxv.asm
# gcc -no-pie -nostartfiles auxv.o -o auxv
```

## How It Works

1. **Auxiliary Vector Parsing**: The entry point skips `argc`, `argv`, and `envp` to reach `auxv`. It searches for `AT_PHDR`, `AT_PHNUM`, and `AT_SYSINFO_EHDR` (vDSO).
2. **Base Address Calculation**: The load bias is calculated dynamically: `load_bias = AT_PHDR - p_vaddr(PT_PHDR)`.
3. **Dynamic Section Parsing**: Locates the `PT_DYNAMIC` segment and iterates through its tags to find `DT_STRTAB`, `DT_SYMTAB`, and `DT_DEBUG`.
4. **Library Discovery**: Extracts the link map from `DT_DEBUG` and traverses it to find the base address of `libc.so`.
5. **API Resolution**: Calculates the hash of each exported symbol and compares it against a predefined target hash (e.g., `0x6e43a318`) to locate the desired function.

## License

This project is licensed under the GNU General Public License v2.0 (GPLv2) - see the [LICENSE](LICENSE) file for details. Just like the Linux kernel.
