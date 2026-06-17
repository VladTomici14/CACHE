`include "defs.svh"
`timescale 1ns/1ps

module cache_controller_tb;

    localparam BLOCK_SIZE    = `BLOCK_SIZE;
    localparam ADDRESS_WIDTH = `ADDRESS_WIDTH;
    localparam INDEX_WIDTH   = `INDEX_WIDTH;
    localparam TAG_WIDTH     = `TAG_WIDTH;
    localparam OFFSET_WIDTH  = `OFFSET_WIDTH;
    localparam WORD_SIZE     = `WORD_SIZE;
    localparam NSETS         = `NSETS;
    localparam WAYS          = `WAYS;
    localparam string MEM_FILE = "tb/mem_data.txt";

    localparam int CLK_PERIOD_NS       = 200;
    localparam int MISS_LATENCY_CYCLES = 6;
    localparam int HIT_LATENCY_CYCLES  = 2;

    // Addresses mapping to set 0 with different tags (index bits [10:3] = 0)
    localparam logic [ADDRESS_WIDTH - 1:0] ADDR_TAG0 = 21'h00000;
    localparam logic [ADDRESS_WIDTH - 1:0] ADDR_TAG1 = 21'h00800;
    localparam logic [ADDRESS_WIDTH - 1:0] ADDR_TAG2 = 21'h01000;
    localparam logic [ADDRESS_WIDTH - 1:0] ADDR_TAG3 = 21'h01800;
    localparam logic [ADDRESS_WIDTH - 1:0] ADDR_TAG4 = 21'h02000;
    // Set 1, tag 0 — used for write-allocate test on a cold set
    localparam logic [ADDRESS_WIDTH - 1:0] ADDR_SET1 = 21'h00008;

    logic      clock;
    logic      rst_n;

    logic [ADDRESS_WIDTH - 1:0]            caddress;
    logic [WORD_SIZE - 1:0]                cdin;
    logic [BLOCK_SIZE - 1:0]               mdin;
    logic                                  rden;
    logic                                  wren;
    logic                                  hit;
    logic [WORD_SIZE - 1:0]               cdout;
    logic [BLOCK_SIZE - 1:0]               mdout;
    logic [TAG_WIDTH + INDEX_WIDTH - 1:0]  maddress;
    logic                                  mrden;
    logic                                  mwren;

    int tests_passed;
    int tests_failed;

    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clock);
    endtask

    function automatic logic [WORD_SIZE - 1:0] get_cache_word(
        input logic [INDEX_WIDTH - 1:0]  set_idx,
        input int                        way_idx,
        input logic [OFFSET_WIDTH - 1:0] word_offset
    );
        return DUT_CACHE.cache_mem[set_idx][way_idx]
               [WORD_SIZE * word_offset +: WORD_SIZE];
    endfunction

    function automatic logic tag_in_set(
        input logic [INDEX_WIDTH - 1:0]  set_idx,
        input logic [TAG_WIDTH - 1:0]    tag
    );
        for (int w = 0; w < WAYS; w++) begin
            if (DUT_CACHE.cache_valid[set_idx][w] &&
                DUT_CACHE.cache_tag[set_idx][w] == tag)
                return 1'b1;
        end
        return 1'b0;
    endfunction

    task automatic cache_read(
        input logic [ADDRESS_WIDTH - 1:0] addr,
        input int wait_cycles_n
    );
        @(posedge clock);
        caddress <= addr;
        cdin     <= '0;
        rden     <= 1'b1;
        wren     <= 1'b0;
        @(posedge clock);
        rden     <= 1'b0;
        wren     <= 1'b0;
        wait_cycles(wait_cycles_n);
    endtask

    task automatic cache_write(
        input logic [ADDRESS_WIDTH - 1:0] addr,
        input logic [WORD_SIZE - 1:0]     data,
        input int wait_cycles_n
    );
        @(posedge clock);
        caddress <= addr;
        cdin     <= data;
        rden     <= 1'b0;
        wren     <= 1'b1;
        @(posedge clock);
        rden     <= 1'b0;
        wren     <= 1'b0;
        wait_cycles(wait_cycles_n);
    endtask

    task automatic check(
        input string name,
        input logic  condition
    );
        if (condition) begin
            tests_passed++;
            $display("PASS: %s", name);
        end else begin
            tests_failed++;
            $display("FAIL: %s", name);
        end
    endtask

    initial begin
        $dumpfile("cache_controller_tb.vcd");
        $dumpvars;
    end

    always begin
        clock = 1'b1;
        #(CLK_PERIOD_NS / 2);
        clock = 1'b0;
        #(CLK_PERIOD_NS / 2);
    end

    cache_controller #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .TAG_WIDTH(TAG_WIDTH),
        .OFFSET_WIDTH(OFFSET_WIDTH),
        .WORD_SIZE(WORD_SIZE),
        .NSETS(NSETS),
        .WAYS(WAYS)
    ) DUT_CACHE (
        .clock(clock),
        .rst_n(rst_n),
        .caddress(caddress),
        .cdin(cdin),
        .mdin(mdin),
        .rden(rden),
        .wren(wren),
        .hit(hit),
        .cdout(cdout),
        .mdout(mdout),
        .maddress(maddress),
        .mrden(mrden),
        .mwren(mwren)
    );

    memory #(
        .FILE(MEM_FILE)
    ) DUT_MEM (
        .clock(clock),
        .din(mdout),
        .address(maddress),
        .rden(mrden),
        .wren(mwren),
        .dout(mdin)
    );

    initial begin
        tests_passed = 0;
        tests_failed = 0;

        caddress = '0;
        cdin     = '0;
        rden     = 1'b0;
        wren     = 1'b0;
        rst_n    = 1'b0;

        wait_cycles(2);
        rst_n = 1'b1;
        wait_cycles(1);

        // --- Test 1: cold read miss then hit ---
        cache_read(ADDR_TAG0, MISS_LATENCY_CYCLES);
        cache_read(ADDR_TAG0, HIT_LATENCY_CYCLES);
        check("read hit after cold miss", hit == 1'b1);

        // --- Test 2: same cache line, different word offsets ---
        cache_read(ADDR_TAG0 + 21'h1, HIT_LATENCY_CYCLES);
        cache_read(ADDR_TAG0 + 21'h2, HIT_LATENCY_CYCLES);
        check("same-line offset reads hit", hit == 1'b1);

        // --- Test 3: fill all 4 ways in set 0 ---
        cache_read(ADDR_TAG1, MISS_LATENCY_CYCLES);
        cache_read(ADDR_TAG2, MISS_LATENCY_CYCLES);
        cache_read(ADDR_TAG3, MISS_LATENCY_CYCLES);
        check("fourth way filled without eviction",
              DUT_CACHE.cache_valid[0][0] &&
              DUT_CACHE.cache_valid[0][1] &&
              DUT_CACHE.cache_valid[0][2] &&
              DUT_CACHE.cache_valid[0][3]);

        // --- Test 4: LRU eviction (tag 0 was LRU) ---
        cache_read(ADDR_TAG4, MISS_LATENCY_CYCLES);
        check("LRU evicted tag 0", !tag_in_set(0, ADDR_TAG0[20:11]));

        // --- Test 5: write hit (write-back) ---
        cache_write(ADDR_TAG1, 32'hDEADBEEF, HIT_LATENCY_CYCLES);
        check("write hit sets dirty bit",
              DUT_CACHE.cache_dirty[0][1] == 1'b1 &&
              get_cache_word(0, 1, 0) == 32'hDEADBEEF);

        // --- Test 6: write-allocate on miss (cold set) ---
        cache_write(ADDR_SET1, 32'hCAFEBABE, MISS_LATENCY_CYCLES);
        check("write-allocate fills cache", DUT_CACHE.cache_valid[1][0] == 1'b1);
        check("write-allocate data in cache",
              get_cache_word(1, 0, 0) == 32'hCAFEBABE);

        wait_cycles(2);

        $display("----------------------------------------");
        $display("Tests passed: %0d", tests_passed);
        $display("Tests failed: %0d", tests_failed);
        $display("----------------------------------------");

        if (tests_failed == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
