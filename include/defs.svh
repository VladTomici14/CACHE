`ifndef __DEFS_SVH__
`define __DEFS_SVH__

// 32 KiB 4-way set-associative cache, 8-word blocks, 32-bit words
// Main memory: 8 MiB, word-addressable
`define BLOCK_SIZE      256
`define ADDRESS_WIDTH   21
`define INDEX_WIDTH     8
`define TAG_WIDTH       10
`define OFFSET_WIDTH    3
`define WORD_SIZE       32
`define NSETS           256
`define WAYS            4
`define MEM_ADDR_WIDTH  18

`endif // __DEFS_SVH__
