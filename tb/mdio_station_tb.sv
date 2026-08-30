`include "../rtl/mdio_station.v"
`default_nettype none

module testbench;

reg clk;
reg rst;
reg en = 1'b1;


mdio_station #(
    .ICLK_TO_MDC_FREQ_RATIO(40 /* default 40 */),
    .PREAMBLE_LENGTH       (32 /* default 32 */),
    .PHY_ADDR_WIDTH        (5 /* default 5 */),
    .REG_ADDR_WIDTH        (5 /* default 5 */),
    .DATA_WIDTH            (16 /* default 16 */)
) mdio_station (
    .clk       (clk),
    .rst       (rst),
    .en        (en)
    // .err       (err),
    // .phy_addr  (phy_addr),
    // .reg_addr  (reg_addr),
    // .write     (write),
    // .up_data   (up_data),
    // .up_valid  (up_valid),
    // .up_ready  (up_ready),
    // .down_data (down_data),
    // .down_valid(down_valid),
    // .down_ready(down_ready),
    // .mdc       (mdc),
    // .mdio_i    (mdio_i),
    // .mdio_o    (mdio_o),
    // .mdio_t    (mdio_t)
);

localparam CLK_PERIOD = 10;
always #(CLK_PERIOD/2) clk=~clk;

initial begin
    $dumpfile("testbench.vcd");
    $dumpvars(0, testbench);
end


endmodule
`resetall
