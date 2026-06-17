# Cache Project

Design and simulation of a **32 KiB 4-way set-associative cache** with 8-word blocks and 32-bit words. Main memory is 8 MiB with word-addressable addressing. The cache uses **write-back**, **write-allocate**, and **LRU** replacement.

## Project structure

```
.
├── src/                 # RTL source files
├── tb/                  # Testbenches and memory data
├── sim/                 # Simulation outputs (logs, VCD)
├── build/               # Compiled simulation binaries
├── include/             # Shared definitions
├── Makefile             # Build and simulation control
├── Dockerfile           # Ubuntu 20.04 simulation environment
└── Readme.md
```

## Cache parameters

32 KiB cache with 8 words per block (4 bytes per word):

$$\text{cache words} = \frac{2^5 \times 2^{10}}{2^2} = 2^{13} \text{ words}$$

$$\text{blocks} = \frac{2^{13}}{2^3} = 2^{10} \text{ blocks}$$

4-way set associative → **256 sets** ($2^{10} / 4 = 2^8$)

| Field          | Bits  | Range     |
|----------------|-------|-----------|
| Tag            | 10    | [20:11]   |
| Index          | 8     | [10:3]    |
| Block Offset   | 3     | [2:0]     |

### Main memory

8 MiB = $2^{23}$ bytes → $2^{21}$ words → **21-bit** word addresses.

Memory block address (tag + index): **18 bits**.

### Controller parameters

```systemverilog
parameter BLOCK_SIZE    = 256;   // bits (8 words × 32 bits)
parameter ADDRESS_WIDTH = 21;    // bits
parameter INDEX_WIDTH   = 8;     // bits
parameter TAG_WIDTH     = 10;    // bits
parameter OFFSET_WIDTH  = 3;     // bits
parameter WORD_SIZE     = 32;    // bits
parameter NSETS         = 256;   // sets
parameter WAYS          = 4;     // associativity
```

## Policies

| Policy           | Implementation                                      |
|------------------|-----------------------------------------------------|
| Write-back       | Dirty bit per cache line; memory write on eviction  |
| Write-allocate   | Write miss fetches block, then writes to cache      |
| LRU replacement  | 2-bit counter per way; 0 = LRU victim, 3 = MRU     |

## Requirements

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`iverilog`, `vvp`)
- GNU Make
- Python 3 (for generating memory test data)

## Build and run

```bash
# Generate memory contents and run simulation
make data
make all

# View simulation log
cat sim/cache_controller_tb.log
```

## Docker

```bash
docker build -t cache-sim .
docker run --rm cache-sim
```

Or using the Makefile shortcut:

```bash
make docker
```

The Docker image is based on **Ubuntu 20.04** and installs Icarus Verilog, Make, and Python 3.

## Simulation outputs

- `sim/cache_controller_tb.log` — test results and `$display` output
- `sim/cache_controller_tb.vcd` — waveform dump (view with GTKWave)

## Implementation Details

This project extends the professor's sample with a **4-way set-associative** architecture:

### Parameter Comparison

| Parameter | Your Design | Direct-Mapped (Sample) | Notes |
|-----------|-------------|------------------------|-------|
| Associativity | 4-way | 1-way | 256 sets × 4 ways = 1024 blocks |
| Index | 8 bits [10:3] | 10 bits | Reduced due to set structure |
| Tag | 10 bits [20:11] | 8 bits | Increased due to reduced index |
| Block offset | 3 bits [2:0] | 3 bits | 8 words per block |
| Address width | 21 bits | 21 bits | 8 MiB word-addressable memory |

### Policies Implemented

| Policy | Implementation |
|--------|----------------|
| **Write-back** | Dirty bit per cache line; memory write only on eviction |
| **Write-allocate** | Write miss fetches the block, then writes to cache |
| **LRU replacement** | 2-bit counter per way (0 = victim, 3 = MRU); invalid ways preferred on miss |

## Project Organization

```
CACHE/
├── src/cache_controller.sv   # 4-way cache FSM + LRU logic
├── src/memory.sv             # 8 MiB main memory model
├── tb/cache_controller_tb.sv # 7 automated test cases
├── tb/generate_data.py       # Memory initialization script
├── include/defs.svh          # Shared SystemVerilog parameters
├── Makefile                  # Build and simulation control
├── Dockerfile                # Ubuntu 20.04 + Icarus Verilog v12
├── .gitignore
└── Readme.md
```

### Reference Implementation

The `project-sample/` folder contains your professor's direct-mapped cache reference implementation. Your design differs in:
- **4-way set-associative structure** instead of direct-mapped
- **LRU replacement logic** with per-way 2-bit counters
- **Write-allocate behavior** for write misses

## Test Coverage

All 7 automated tests pass:
- Cold miss (empty cache, tag 0)
- Cache hit (subsequent access to same address)
- LRU eviction (4 ways full, 5th access replaces LRU victim)
- Write-back behavior (dirty line evicted, memory updated)
- Write-allocate behavior (write miss fetches block first)
- Tag and index address field extraction
- Block offset alignment

## Icarus Verilog v12 Requirement

Ubuntu 20.04 ships with Icarus Verilog 10.x, which has incomplete SystemVerilog support. The **Dockerfile builds v12 from source** for full compatibility:

```bash
docker build -t cache-sim .
docker run --rm cache-sim
```

Or use the Make shortcut:

```bash
make docker
```

## Clean

```bash
make clean
```
