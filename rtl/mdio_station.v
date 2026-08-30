/*

Copyright (c) 2026 George Fedorov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2005

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * MDIO master (station)
 */
module mdio_station #(
    parameter   ICLK_TO_MDC_FREQ_RATIO=40,
                PREAMBLE_LENGTH=32,
                PHY_ADDR_WIDTH=5,
                REG_ADDR_WIDTH=5,
                DATA_WIDTH=16
) (
    input   wire                        clk,
    input   wire                        rst,
    input   wire                        en,
    output  reg                         err,

    input   wire [PHY_ADDR_WIDTH-1:0]   phy_addr,
    input   wire [REG_ADDR_WIDTH-1:0]   reg_addr,
    input   wire                        write,
    
    input   wire [DATA_WIDTH-1:0]       up_data,
    input   wire                        up_valid,
    output  reg                         up_ready,
    
    output  reg [DATA_WIDTH-1:0]        down_data,
    output  reg                         down_valid,
    input   reg                         down_ready,

    // MDIO interface
    output  wire                        mdc,
    input   wire                        mdio_i,
    output  wire                        mdio_o,
    output  wire                        mdio_t
);
    reg                      ce;

    reg                      mdio_i_r;
    reg                      mdio_o_r;
    reg                      mdio_t_r;
    reg                      mdio_i_latched;
    reg                      mdio_o_next;
    reg                      mdio_t_next;
    
    reg [PHY_ADDR_WIDTH-1:0] phy_addr_r;
    reg [REG_ADDR_WIDTH-1:0] reg_addr_r;
    reg [DATA_WIDTH-1:0]     up_data_r;
    reg                      write_r;

    // Clock generation
    reg [$clog2(ICLK_TO_MDC_FREQ_RATIO):0] mdc_cnt;

    always @(posedge clk) begin
        if ( ( ~en ) | 
             (  rst ) |
             (  mdc_cnt == (ICLK_TO_MDC_FREQ_RATIO-1) ) ) begin
            mdc_cnt <= ICLK_TO_MDC_FREQ_RATIO / 2 + 'd1;
        end else if ( ce ) begin
            mdc_cnt <= mdc_cnt + 'd1;
        end
    end

    assign mdc = ( mdc_cnt > ICLK_TO_MDC_FREQ_RATIO / 2 ) ? 1'b1 : 1'b0;

    // Bit counter
    reg [6:0] bit_cnt;
    reg       mdc_prev;

    always @(clk) begin
        mdc_prev <= mdc;
    end

    // States of state machine
    localparam IDLE     = 4'd0;
    localparam PREAMBLE = 4'd1;
    localparam START    = 4'd2;
    localparam OPCODE   = 4'd3;
    localparam PHY_ADDR = 4'd4;
    localparam REG_ADDR = 4'd5;
    localparam TA       = 4'd6;
    localparam READ     = 4'd7;
    localparam WRITE    = 4'd8;

    reg [3:0] state;

    always @(posedge clk) begin
        err <= 'b0;
        mdio_t_next <= 'b1;
        mdio_o_next <= 'b1;
        mdio_i_r    <= 'b1;

        case (state)
            IDLE: begin
                if (up_valid && up_ready) begin
                    phy_addr_r  <= phy_addr;
                    reg_addr_r  <= reg_addr;
                    up_data_r   <= up_data;
                    write_r     <= write;

                    mdio_t_r <= 1'b1;

                    bit_cnt <= 'd0;

                    state <= PREAMBLE;
                end else begin
                    state <= IDLE;
                end
            end
            PREAMBLE: begin
                if (bit_cnt < (PREAMBLE_LENGTH - 1)) begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= 'b1;

                    state <= PREAMBLE;
                end else begin
                    state <= START;
                end
            end
            START: begin
                if (bit_cnt == 'd0) begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= 'b0;

                    state <= START;
                end else if (bit_cnt == 'd1) begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= 'b1;

                    state <= START;
                end else begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= 'b1;

                    state <= OPCODE;
                end
            end
            OPCODE: begin
                if (write_r) begin
                    if (bit_cnt == 'd0) begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b0;

                        state <= OPCODE;
                    end else if (bit_cnt == 'd1) begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b1;

                        state <= OPCODE;
                    end else begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b1;

                        state <= PHY_ADDR;
                    end
                end else begin
                    if (bit_cnt == 'd0) begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b1;

                        state <= OPCODE;
                    end else if (bit_cnt == 'd1) begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b0;

                        state <= OPCODE;
                    end else begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b0;

                        state <= PHY_ADDR;
                    end
                end
            end
            PHY_ADDR: begin
                if (bit_cnt < PHY_ADDR_WIDTH) begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= phy_addr_r[bit_cnt];

                    state <= PHY_ADDR;
                end else begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= 'b0;

                    state <= REG_ADDR;
                end
            end
            REG_ADDR: begin
                if (bit_cnt < REG_ADDR_WIDTH) begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= reg_addr_r[bit_cnt];

                    state <= REG_ADDR;
                end else begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= 'b0;

                    state <= TA;
                end
            end
            TA: begin
                if (write_r) begin
                    if (bit_cnt == 'd0) begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b1;

                        state <= TA;
                    end else if (bit_cnt == 'd1) begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b0;

                        state <= TA;
                    end else begin
                        mdio_t_next <= 'b0;
                        mdio_o_next <= 'b0;

                        state <= WRITE;
                    end
                end else begin
                    if (bit_cnt == 'd0) begin
                        mdio_t_next <= 'b1;
                        mdio_o_next <= 'b1;

                        state <= TA;
                    end else if (bit_cnt == 'd1) begin
                        mdio_t_next <= 'b1;
                        mdio_o_next <= 'b0;

                        if (~mdio_i_r) begin
                            state <= READ;
                        end else begin
                            state <= IDLE;
                            err   <= 'b1;
                        end

                        state <= TA;
                    end
                end
            end
            WRITE: begin
                if (bit_cnt < DATA_WIDTH) begin
                    mdio_t_next <= 'b0;
                    mdio_o_next <= up_data_r[bit_cnt];

                    state <= WRITE;
                end else begin
                    state <= IDLE;
                end
            end
            READ: begin
                if (bit_cnt < DATA_WIDTH) begin
                    state <= READ;
                end else begin
                    state <= IDLE;
                end
            end
        endcase
    end

    // Posedge MDC logic
    always @(clk) begin
        if ((~mdc) & mdc_prev) begin 
            bit_cnt <= bit_cnt + 'd1;

            if (state == READ) begin
                down_data <= { down_data[DATA_WIDTH-1:1], mdio_i };
            end
        end
    end

    // Negedge MDC logic
    always @(clk) begin
        if (mdc & (~mdc_prev)) begin
            mdio_o_r <= mdio_o_next;
            mdio_t_r <= mdio_t_next;
        end
    end

endmodule
