`include "defs.svh"

`timescale 1ns/1ps

module cache_controller #(
    parameter BLOCK_SIZE    = `BLOCK_SIZE,
    parameter ADDRESS_WIDTH = `ADDRESS_WIDTH,
    parameter INDEX_WIDTH   = `INDEX_WIDTH,
    parameter TAG_WIDTH     = `TAG_WIDTH,
    parameter OFFSET_WIDTH  = `OFFSET_WIDTH,
    parameter WORD_SIZE     = `WORD_SIZE,
    parameter NSETS         = `NSETS,
    parameter WAYS          = `WAYS
) (
    input  logic                                  clock,
    input  logic                                  rst_n,
    input  logic [ADDRESS_WIDTH - 1:0]            caddress,
    input  logic [WORD_SIZE - 1:0]                cdin,
    input  logic [BLOCK_SIZE - 1:0]               mdin,
    input  logic                                  rden,
    input  logic                                  wren,
    output logic                                  hit,
    output logic [WORD_SIZE - 1:0]               cdout,
    output logic [BLOCK_SIZE - 1:0]              mdout,
    output logic [TAG_WIDTH + INDEX_WIDTH - 1:0] maddress,
    output logic                                  mrden,
    output logic                                  mwren
);

    typedef enum logic [2:0] {
        STATE_IDLE,
        STATE_READ_HIT,
        STATE_READ_MISS,
        STATE_WRITE_HIT,
        STATE_WRITE_MISS,
        STATE_REPLACE,
        STATE_FETCH,
        STATE_FILL
    } state_t;

    localparam WAY_WIDTH = $clog2(WAYS);
    localparam LRU_MAX   = WAYS - 1;

    localparam TAG_MSB          = 20;
    localparam TAG_LSB          = 11;
    localparam INDEX_MSB        = 10;
    localparam INDEX_LSB        = 3;
    localparam BLOCK_OFFSET_MSB = 2;
    localparam BLOCK_OFFSET_LSB = 0;

    state_t current_state, next_state;

    logic                         cache_valid [0:NSETS - 1][0:WAYS - 1];
    logic                         cache_dirty [0:NSETS - 1][0:WAYS - 1];
    logic [TAG_WIDTH - 1:0]       cache_tag   [0:NSETS - 1][0:WAYS - 1];
    logic [BLOCK_SIZE - 1:0]      cache_mem   [0:NSETS - 1][0:WAYS - 1];
    logic [WAY_WIDTH - 1:0]       lru         [0:NSETS - 1][0:WAYS - 1];

    logic [ADDRESS_WIDTH - 1:0]   req_addr;
    logic                         req_read;
    logic                         req_write;
    logic [WORD_SIZE - 1:0]       req_wdata;

    logic [ADDRESS_WIDTH - 1:0]   active_addr;
    logic [INDEX_WIDTH - 1:0]     active_index;
    logic [TAG_WIDTH - 1:0]       active_tag;
    logic [OFFSET_WIDTH - 1:0]    active_offset;

    logic                         lookup_hit;
    logic [WAY_WIDTH - 1:0]       hit_way;
    logic [WAY_WIDTH - 1:0]       victim_way;
    logic [WAY_WIDTH - 1:0]       active_way;
    logic [WORD_SIZE - 1:0]       read_data;

    function automatic logic [WORD_SIZE - 1:0] block_get_word(
        input logic [BLOCK_SIZE - 1:0]   block,
        input logic [OFFSET_WIDTH - 1:0] word_offset
    );
        return block[WORD_SIZE * word_offset +: WORD_SIZE];
    endfunction

    function automatic logic [BLOCK_SIZE - 1:0] block_set_word(
        input logic [BLOCK_SIZE - 1:0]   block,
        input logic [OFFSET_WIDTH - 1:0] word_offset,
        input logic [WORD_SIZE - 1:0]    word
    );
        logic [BLOCK_SIZE - 1:0] result;
        result = block;
        result[WORD_SIZE * word_offset +: WORD_SIZE] = word;
        return result;
    endfunction

    assign active_addr    = (current_state == STATE_IDLE) ? caddress : req_addr;
    assign active_index   = active_addr[INDEX_MSB:INDEX_LSB];
    assign active_tag     = active_addr[TAG_MSB:TAG_LSB];
    assign active_offset  = active_addr[BLOCK_OFFSET_MSB:BLOCK_OFFSET_LSB];

    always_comb begin
        lookup_hit = 1'b0;
        hit_way    = '0;

        for (int w = 0; w < WAYS; w++) begin
            if (cache_valid[active_index][w] &&
                cache_tag[active_index][w] == active_tag) begin
                lookup_hit = 1'b1;
                hit_way    = WAY_WIDTH'(w);
            end
        end
    end

    always_comb begin
        logic found_invalid;
        logic found_lru;

        found_invalid = 1'b0;
        found_lru     = 1'b0;
        victim_way    = '0;

        for (int w = 0; w < WAYS; w++) begin
            if (!found_invalid && !cache_valid[active_index][w]) begin
                found_invalid = 1'b1;
                victim_way    = WAY_WIDTH'(w);
            end
        end

        if (!found_invalid) begin
            for (int w = 0; w < WAYS; w++) begin
                if (!found_lru && lru[active_index][w] == '0) begin
                    found_lru  = 1'b1;
                    victim_way = WAY_WIDTH'(w);
                end
            end
        end
    end

    assign active_way = lookup_hit ? hit_way : victim_way;
    assign hit        = lookup_hit;
    assign read_data  = block_get_word(cache_mem[active_index][active_way], active_offset);

    always_comb begin
        next_state = current_state;
        cdout      = '0;
        mdout      = '0;
        maddress   = '0;
        mrden      = 1'b0;
        mwren      = 1'b0;

        case (current_state)
            STATE_IDLE: begin
                if (rden && lookup_hit)
                    next_state = STATE_READ_HIT;
                else if (rden)
                    next_state = STATE_READ_MISS;
                else if (wren && lookup_hit)
                    next_state = STATE_WRITE_HIT;
                else if (wren)
                    next_state = STATE_WRITE_MISS;
            end

            STATE_READ_HIT: begin
                cdout      = read_data;
                next_state = STATE_IDLE;
            end

            STATE_READ_MISS: begin
                if (cache_valid[active_index][victim_way] &&
                    cache_dirty[active_index][victim_way])
                    next_state = STATE_REPLACE;
                else
                    next_state = STATE_FETCH;
            end

            STATE_WRITE_MISS: begin
                if (cache_valid[active_index][victim_way] &&
                    cache_dirty[active_index][victim_way])
                    next_state = STATE_REPLACE;
                else
                    next_state = STATE_FETCH;
            end

            STATE_REPLACE: begin
                mwren    = 1'b1;
                maddress = {cache_tag[active_index][victim_way], active_index};
                mdout    = cache_mem[active_index][victim_way];
                next_state = STATE_FETCH;
            end

            STATE_FETCH: begin
                mrden    = 1'b1;
                maddress = {active_tag, active_index};
                next_state = STATE_FILL;
            end

            STATE_FILL: begin
                if (req_read)
                    next_state = STATE_READ_HIT;
                else if (req_write)
                    next_state = STATE_WRITE_HIT;
                else
                    next_state = STATE_IDLE;
            end

            STATE_WRITE_HIT: begin
                next_state = STATE_IDLE;
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    integer s, w;

    initial begin
        for (s = 0; s < NSETS; s = s + 1) begin
            for (w = 0; w < WAYS; w = w + 1) begin
                cache_valid[s][w] = 1'b0;
                cache_dirty[s][w] = 1'b0;
                cache_tag[s][w]   = '0;
                cache_mem[s][w]   = '0;
                lru[s][w]         = '0;
            end
        end
    end

    always_ff @(posedge clock) begin
        logic [WAY_WIDTH - 1:0] old_lru;
        integer                 i;

        if (!rst_n) begin
            current_state <= STATE_IDLE;
            req_read      <= 1'b0;
            req_write     <= 1'b0;
            req_addr      <= '0;
            req_wdata     <= '0;

            for (s = 0; s < NSETS; s = s + 1) begin
                for (w = 0; w < WAYS; w = w + 1) begin
                    cache_valid[s][w] <= 1'b0;
                    cache_dirty[s][w] <= 1'b0;
                    cache_tag[s][w]   <= '0;
                    cache_mem[s][w]   <= '0;
                    lru[s][w]         <= '0;
                end
            end
        end else begin
            current_state <= next_state;

            if (current_state == STATE_IDLE && (rden || wren)) begin
                req_addr  <= caddress;
                req_read  <= rden;
                req_write <= wren;
                req_wdata <= cdin;
            end

            if (current_state == STATE_FILL) begin
                cache_mem[active_index][victim_way]   <= mdin;
                cache_tag[active_index][victim_way]   <= active_tag;
                cache_valid[active_index][victim_way] <= 1'b1;
                cache_dirty[active_index][victim_way] <= 1'b0;
            end

            if (current_state == STATE_WRITE_HIT) begin
                cache_mem[active_index][active_way] <= block_set_word(
                    cache_mem[active_index][active_way],
                    active_offset,
                    req_wdata
                );
                cache_dirty[active_index][active_way] <= 1'b1;
            end

            if ((current_state == STATE_READ_HIT) ||
                (current_state == STATE_WRITE_HIT)) begin
                old_lru = lru[active_index][active_way];

                for (i = 0; i < WAYS; i = i + 1) begin
                    if (WAY_WIDTH'(i) != active_way &&
                        lru[active_index][i] > old_lru)
                        lru[active_index][i] <= lru[active_index][i] - 1'b1;
                end

                lru[active_index][active_way] <= LRU_MAX[WAY_WIDTH - 1:0];
            end
        end
    end

endmodule
