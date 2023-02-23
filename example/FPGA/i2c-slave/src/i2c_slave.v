`timescale 1ns / 1ps

module iic_slave_design (
    //external port 
	input					iic_scl,
	inout					iic_sda,
    
    input [7:0]             slave_addr,
    output [7:0]            IOout
);


wire iic_sda_shadow    /* synthesis keep = 1 */;
wire start_or_stop /* synthesis keep = 1 */;
assign iic_sda_shadow = (~iic_scl | start_or_stop) ? iic_sda : iic_sda_shadow;
assign start_or_stop = ~iic_scl ? 1'b0 : (iic_sda ^ iic_sda_shadow);

reg incycle;

reg [3:0] bitcnt;  // counts the I2C bits from 7 downto 0, plus an ACK bit
wire bit_DATA = ~bitcnt[3];  // the DATA bits are the first 8 bits sent
wire bit_ACK = bitcnt[3];  // the ACK bit is the 9th bit sent
reg data_phase;

always @(negedge iic_scl or posedge start_or_stop)begin
    if(start_or_stop) incycle <= 1'b0; 
    else if(~iic_sda) incycle <= 1'b1;
end

always @(negedge iic_scl or negedge incycle)begin 
    if(~incycle) begin
        bitcnt <= 4'h7;  // the bit 7 is received first
        data_phase <= 0;
    end
    else begin
    if(bit_ACK)begin
        bitcnt <= 4'h7;
        data_phase <= 1;
    end
    else
        bitcnt <= bitcnt - 4'h1;
    end 
end

wire adr_phase = ~data_phase;
reg adr_match, op_read, got_ACK;
// sample iic_sda on posedge since the I2C spec specifies as low as 0µs hold-time on negedge
reg iic_sdar; 

reg [7:0] mem;
wire op_write = ~op_read;

always @(posedge iic_scl)begin 
    iic_sdar<=iic_sda;
end

always @(negedge iic_scl or negedge incycle)begin 
    if(~incycle) begin
        got_ACK <= 0;
        adr_match <= 1;
        op_read <= 0;
    end 
    else begin
        if(adr_phase & bitcnt==7 & iic_sdar!=slave_addr[6]) adr_match<=0;
        if(adr_phase & bitcnt==6 & iic_sdar!=slave_addr[5]) adr_match<=0;
        if(adr_phase & bitcnt==5 & iic_sdar!=slave_addr[4]) adr_match<=0;
        if(adr_phase & bitcnt==4 & iic_sdar!=slave_addr[3]) adr_match<=0;
        if(adr_phase & bitcnt==3 & iic_sdar!=slave_addr[2]) adr_match<=0;
        if(adr_phase & bitcnt==2 & iic_sdar!=slave_addr[1]) adr_match<=0;
        if(adr_phase & bitcnt==1 & iic_sdar!=slave_addr[0]) adr_match<=0;
        if(adr_phase & bitcnt==0) op_read <= iic_sdar;
        // we monitor the ACK to be able to free the bus when the master doesn't ACK during a read operation
        if(bit_ACK) got_ACK <= ~iic_sdar;
        if(adr_match & bit_DATA & data_phase & op_write) mem[bitcnt] <= iic_sdar;  // memory write
    end
end

wire mem_bit_low = ~mem[bitcnt[2:0]];
wire iic_sda_assert_low = adr_match & bit_DATA & data_phase & op_read & mem_bit_low & got_ACK;
wire iic_sda_assert_ACK = adr_match & bit_ACK & (adr_phase | op_write);
wire iic_sda_low = iic_sda_assert_low | iic_sda_assert_ACK;
assign iic_sda = iic_sda_low ? 1'b0 : 1'bz;

assign IOout = mem;

endmodule 