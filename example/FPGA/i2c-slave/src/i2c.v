module i2c(
    input clk,
    input iic_scl,
	inout iic_sda,
        
    output led_io
);

wire [7:0]   iic_device_adr = 7'h30;
wire [7:0]   get_data ;

iic_slave_design slave(
	.iic_scl(iic_scl),
	.iic_sda(iic_sda),
    .slave_addr(iic_device_adr),
    .IOout(get_data)
);

reg leds;
always@(*)begin
    if(get_data == 7'h1)
        leds = 1;
    else
        leds = 0;
end


led_module led(
    .led_state(leds),
    .led_out(led_io)
);



endmodule