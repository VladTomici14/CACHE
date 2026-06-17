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

## Clean

```bash
make clean
```
