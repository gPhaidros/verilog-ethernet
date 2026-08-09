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
    output  wire                        err,

    input   wire [PHY_ADDR_WIDTH-1:0]   phy_addr,
    input   wire [REG_ADDR_WIDTH-1:0]   reg_addr,
    input   wire                        write,
    // Write interface
    input   wire [DATA_WIDTH-1:0]       up_data,
    input   wire                        up_valid,
    output  wire                        up_ready,
    // Read interface
    input   wire [DATA_WIDTH-1:0]       down_data,
    output  wire                        down_valid,
    output  wire                        down_ready,

    // MDIO interface
    output  wire                        mdc,
    input   wire                        mdio_i,
    output  wire                        mdio_o,
    output  wire                        mdio_t,
);
    
    // Clock generation
    reg [$clog2(ICLK_TO_MDC_FREQ_RATIO):0] mdc_cnt;

    always @(posedge clk) begin
        if ( ( ~en ) | 
             (  rst )
             (  mdc_cnt == (ICLK_TO_MDC_FREQ_RATIO-1) ) ) begin
            mdc_cnt <= ICLK_TO_MDC_FREQ_RATIO / 2 + 'd1;
        end else begin
            mdc_cnt <= mdc_cnt + 'd1;
        end
    end

    assign mdc = ( mdc_cnt > ICLK_TO_MDC_FREQ_RATIO / 2 ) ? 1'b1 : 1'b0;

    // States of state machine
    localparam IDLE     = 4'b;
    localparam PREAMBLE = 4'b;
    localparam START    = 4'b;
    localparam OPCODE   = 4'b;
    localparam PHY_ADDR = 4'b;
    localparam REG_ADDR = 4'b;
    localparam TA       = 4'b;
    localparam READ     = 4'b;
    localparam WRITE    = 4'b;

endmodule