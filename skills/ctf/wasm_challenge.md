# CTF WebAssembly (WASM) Challenges

WASM CTF = binary running in browser or server (wasmtime/wasmer) → reverse the logic → find/forge flag.
All CLI with wabt toolchain, wasm2c, and Python scripting.

## Install

```bash
# wabt — WebAssembly Binary Toolkit (wasm2wat, wat2wasm, wasm-objdump, wasm-interp)
sudo apt-get install -y wabt
# OR latest: https://github.com/WebAssembly/wabt/releases

# wasmtime — WASM runtime (CLI execution)
curl https://wasmtime.dev/install.sh -sSf | bash
# OR: wget https://github.com/bytecodealliance/wasmtime/releases/latest/download/wasmtime-v*-x86_64-linux.tar.xz

# wasmer — alternative runtime
curl https://get.wasmer.io -sSfL | sh

# wasm-pack / wasm-decompile:
sudo apt-get install -y wasm-decompile   # part of wabt in newer versions

# Python wasm analysis:
pip install pywebassembly --break-system-packages
```

---

## Phase 1: Initial Analysis

```bash
# Identify the file:
file challenge.wasm    # WebAssembly (wasm) binary module

# Check magic bytes (should be: 00 61 73 6D):
xxd challenge.wasm | head -3
# 00000000: 0061 736d 0100 0000  .asm....

# Get high-level overview (sections, imports, exports):
wasm-objdump -h challenge.wasm    # section headers
wasm-objdump -x challenge.wasm    # full dump (imports, exports, functions, tables, memory)
wasm-objdump -d challenge.wasm    # disassemble all functions

# List exports (entry points the challenge exposes):
wasm-objdump -x challenge.wasm | grep "Export"

# List imports (host functions it calls: console.log, etc.):
wasm-objdump -x challenge.wasm | grep "Import"
```

---

## Phase 2: Decompile to WAT (Text Format)

```bash
# Convert binary WASM → human-readable WAT:
wasm2wat challenge.wasm -o challenge.wat
cat challenge.wat

# WAT basics to understand:
# (module ...)           — top level
# (func $name ...)       — function definition
# (param i32 i64 f32)    — parameters
# (result i32)           — return type
# (local i32)            — local variable
# i32.load, i32.store    — memory operations
# call $func_name        — function call
# i32.eq, i32.ne         — comparisons
# br_if, if/else/end     — control flow

# Search for flag-related patterns:
grep -n "call\|export\|import" challenge.wat | head -30
grep -n "i32.eq\|i32.ne\|i32.lt\|br_if" challenge.wat   # comparison logic
grep -n "0x66 0x6c 0x61 0x67\|flag\|CTF" challenge.wat   # string literals (hex encoded)
```

---

## Phase 3: Decompile to C-like Pseudo-code

```bash
# wasm-decompile (more readable than WAT):
wasm-decompile challenge.wasm -o challenge.dcmp
cat challenge.dcmp

# wasm2c — convert to C source (compilable):
wasm2c challenge.wasm -o challenge.c
# This creates challenge.c + challenge.h — compile and run natively

# Compile wasm2c output (add wasm-rt-impl.c from wabt):
gcc challenge.c /usr/share/wabt/wasm-rt-impl.c -I/usr/share/wabt/ -o challenge_native -lm
./challenge_native   # run as native binary

# Now you can use standard binary analysis on challenge_native:
gdb ./challenge_native
ltrace ./challenge_native
strace ./challenge_native
```

---

## Phase 4: Execute and Test

```bash
# Run with wasmtime (WASI support):
wasmtime challenge.wasm                          # direct run
wasmtime challenge.wasm -- arg1 arg2             # with arguments
echo "test_input" | wasmtime challenge.wasm      # stdin input

# Run with wasmer:
wasmer challenge.wasm
wasmer run challenge.wasm -- --flag "test"

# Run with wasm-interp (wabt interpreter):
wasm-interp challenge.wasm --run-all-exports     # call all exported functions
wasm-interp challenge.wasm --call check_flag     # call specific function

# Node.js runner (browser-like environment):
node -e "
const fs = require('fs');
const buf = fs.readFileSync('challenge.wasm');
WebAssembly.instantiate(buf, {
  env: {
    memory: new WebAssembly.Memory({initial: 256}),
    console_log: (ptr, len) => {
      const view = new Uint8Array(instance.exports.memory.buffer, ptr, len);
      console.log('[WASM]', Buffer.from(view).toString('utf8'));
    }
  }
}).then(({instance}) => {
  console.log('Exports:', Object.keys(instance.exports));
  // Call check function:
  const result = instance.exports.check_flag(/* ptr_to_input */);
  console.log('Result:', result);
});
"
```

---

## Phase 5: Memory Analysis

```bash
# WASM memory is linear — single contiguous buffer
# Strings are stored as UTF-8 at specific offsets

# Find strings in data section:
wasm-objdump -x challenge.wasm | grep -A5 "Data"
# Shows: data segment offsets and content

# Dump data section as strings:
python3 -c "
import struct

with open('challenge.wasm', 'rb') as f:
    data = f.read()

# Find data section (id=11):
i = 8  # skip magic + version
while i < len(data):
    section_id = data[i]
    i += 1
    size, n = decode_leb128(data, i)
    i += n
    if section_id == 11:  # data section
        print('[Data section at offset', hex(i), ']')
        print(data[i:i+size])
        break
    i += size

def decode_leb128(data, pos):
    result = 0; shift = 0
    while True:
        b = data[pos]; pos += 1
        result |= (b & 0x7f) << shift
        if not (b & 0x80): break
        shift += 7
    return result, pos - pos
"

# Simpler: just strings:
strings challenge.wasm | grep -i "flag\|CTF\|correct\|wrong\|password"
```

---

## Phase 6: Patching WASM

```bash
# Method 1: Edit WAT and recompile
wasm2wat challenge.wasm -o challenge.wat
# Edit challenge.wat — change comparison logic:
# (i32.ne) → (drop) (i32.const 0)  — make check always pass
nano challenge.wat
wat2wasm challenge.wat -o challenge_patched.wasm
wasmtime challenge_patched.wasm

# Method 2: Binary patch
python3 -c "
data = open('challenge.wasm', 'rb').read()
# Find the instruction bytes for 'i32.ne' (0x47) at known offset
# Replace with 'i32.const 0' (0x41 0x00) + 'drop' (0x1a) if needed
# Or replace conditional br_if with unreachable (0x00) to skip check
offset = 0x<known_offset>
data = data[:offset] + b'\x41\x01' + data[offset+2:]   # i32.const 1 (true)
open('patched.wasm', 'wb').write(data)
"
wasmtime patched.wasm

# Method 3: JavaScript wrapper (browser context)
# Intercept the WASM module import and patch exports:
# Use browser devtools → Sources → WASM → breakpoint + patch memory
```

---

## Phase 7: Common CTF WASM Patterns

```bash
# Pattern 1: Flag check in exported function
wasm-objdump -x challenge.wasm | grep Export
# → find function like "check", "verify", "validate"
# Call directly with candidate flags

# Pattern 2: Flag stored in data section
wasm-objdump -d challenge.wasm | grep -B5 "i32.load8_s\|i32.load"
# Memory loads suggest reading from hardcoded offset
# Dump data section → extract at that offset

# Pattern 3: XOR obfuscation
# Look for i32.xor in WAT output near loop:
grep -n "i32.xor\|loop\|br_if" challenge.wat
# → extract encrypted bytes + key from data section → XOR manually

# Pattern 4: Character-by-character comparison
grep -n "i32.eq\|i32.ne\|br_if" challenge.wat
# → likely comparing input[i] with expected[i] in loop
# → ltrace on wasm2c output OR step through with wasm-interp

# Pattern 5: Hash comparison
grep -n "call" challenge.wat | head -20
# → find hash function call → identify algorithm → reverse
```

---

## Phase 8: wasm2c Native Analysis Workflow

```bash
# Full workflow: wasm → C → native binary → standard pwn tools
wasm2c challenge.wasm -o challenge.c

# Find wasm-rt-impl.c:
find /usr -name "wasm-rt-impl.c" 2>/dev/null
# Usually: /usr/share/wabt/wasm-rt-impl.c

# Compile:
gcc -O0 -g challenge.c /usr/share/wabt/wasm-rt-impl.c \
  -I/usr/include/wabt/ -I/usr/share/wabt/ \
  -o challenge_native -lm

# Now use full toolchain:
ltrace ./challenge_native <<< "CTF{test_flag}"
gdb ./challenge_native
# break at w2c_check_flag or w2c_main
objdump -d ./challenge_native | grep -A20 "w2c_check"
```

---

## Pro Tips

1. **wasm2wat first** — always start with text format; 80% of WASM CTF solvable from WAT reading
2. **strings command** — many challenges have flag validation string hardcoded in data section
3. **wasm2c** → `ltrace` — the fastest path: convert to C, compile, run with ltrace → strcmp reveals flag
4. **Find exports** — `wasm-objdump -x` shows callable entry points to test directly
5. **Data section offsets** — memory loads like `i32.load offset=0x1234` point directly to flag storage
6. **i32.eq in loop** — classic character-by-character flag check pattern
7. **Node.js** for web challenges — WASM challenge from browser context often has JS wrapper; read wrapper for helper functions

## Summary

WASM CTF flow: `wasm-objdump -x` → `wasm2wat` → `grep flag/compare` in WAT → `wasm2c` → compile → `ltrace ./native <<< "input"` → if strcmp appears, that's the flag → if encrypted, extract data section + XOR key → decrypt → verify with `wasmtime challenge.wasm`.
