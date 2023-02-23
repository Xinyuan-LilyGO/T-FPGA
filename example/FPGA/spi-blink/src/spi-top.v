
/*
测试spi从机用 每个接受一个8位的数据
然后把接收到的数据加一在发送回去
接收到小于0x80数据时 led灯点亮
*/
 
module spi_top(
		input				clk,
		input				rst,
		input				cs,
		input				sck,
		input				MOSI,
		output				MISO,
		output	[7:0]		rxd_out,
		output				rxd_flag,
        output  reg         led_state
);

reg [7:0] txd_dat;
wire clk_30M;

always@(posedge rxd_flag or negedge rst)begin
    if(!rst)
	 txd_dat <= 8'b11000011;
	else
	 begin
      txd_dat <= rxd_out + 1'b1; //把数据+1送到发送端
	 end
end

always@(posedge rxd_flag or negedge rst)begin
    if(!rst)
        led_state<=1'b0;
    else if(rxd_out<8'h80)
        led_state<=1'b1;
    else 
        led_state<=1'b0;
end

Gowin_OSC osc(//内部晶振输出25MHz
    .oscout(oscout_o), //output oscout
    .oscen(1) //input oscen
);

Gowin_PLLVR pll(//倍频到30Mhz
      .clkout(clk_30M), //output clkout
      .clkin(oscout_o) //input clkin
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