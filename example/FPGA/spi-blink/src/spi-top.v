module spi_top(
    input           clk,
    input           rst,
    input           cs,
    input           sck, 
    input           MOSI,
    output          MISO,
    output  [7:0]   rxd_out,
    output          rxd_flag,
    output  reg     led_state
);

reg [7:0] txd_dat;
reg [7:0] prev_rxd;  // 存储上一个接收的数据
wire clk_30M;
wire oscout_o;

// 总是回复"上次接收数据+1"
always @(posedge clk_30M or negedge rst) begin
    if (!rst) begin
        txd_dat <= 8'b11000011;  // 初始回复值
        prev_rxd <= 8'b0;
        led_state <= 1'b0;
    end else if (rxd_flag) begin
        // 接收到新数据时，更新下次要回复的数据
        prev_rxd <= rxd_out;
        txd_dat <= rxd_out + 1'b1;
        
        // 控制LED
        if (rxd_out < 8'h80)
            led_state <= 1'b1;
        else 
            led_state <= 1'b0;
    end
end

Gowin_OSC osc(
    .oscout(oscout_o),
    .oscen(1'b1)
);

Gowin_PLLVR pll(
    .clkout(clk_30M),
    .clkin(oscout_o)
);

spi_slaver spi_slaver1(
    .clk(clk_30M),
    .rst(rst),
    .cs(cs),
    .sck(sck),
    .MOSI(MOSI),
    .MISO(MISO),
    .rxd_out(rxd_out),
    .txd_data(txd_dat),
    .rxd_flag(rxd_flag)
);

endmodule