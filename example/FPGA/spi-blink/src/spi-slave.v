module spi_slaver(
    input           clk,
    input           rst,
    input           cs,
    input           sck,
    input           MOSI,
    output reg      MISO,
    output reg[7:0] rxd_out,
    input [7:0]     txd_data,
    output          rxd_flag
);

// 根据ESP32的SPI_MODE0配置：
// CPOL = 0 (时钟空闲低电平)
// CPHA = 0 (数据在第一个边沿采样，即上升沿采样)

reg [2:0] sck_sync;
reg [2:0] cs_sync;
wire sck_rising, sck_falling;
wire cs_active;

// 同步外部信号 - 使用非阻塞赋值
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        sck_sync <= 3'b000;
        cs_sync <= 3'b111;
    end else begin
        sck_sync <= {sck_sync[1:0], sck};
        cs_sync <= {cs_sync[1:0], cs};
    end
end

// 边沿检测
assign sck_rising = (sck_sync[2:1] == 2'b01);  // 检测上升沿
assign sck_falling = (sck_sync[2:1] == 2'b10); // 检测下降沿  
assign cs_active = ~cs_sync[1];  // CS低电平有效

// ---------------------- 数据接收 ----------------------
reg [7:0] rxd_shift;
reg [3:0] bit_count_rx;
reg rxd_done;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        rxd_shift <= 8'b0;
        bit_count_rx <= 4'd0;
        rxd_done <= 1'b0;
        rxd_out <= 8'b0;
    end else if (!cs_active) begin
        // CS无效时复位
        rxd_shift <= 8'b0;
        bit_count_rx <= 4'd0;
        rxd_done <= 1'b0;
    end else if (sck_rising) begin
        // 上升沿采样MOSI (SPI_MODE0)
        rxd_shift <= {rxd_shift[6:0], MOSI};
        bit_count_rx <= bit_count_rx + 4'd1;
        
        if (bit_count_rx == 4'd7) begin
            // 完成一个字节
            rxd_out <= {rxd_shift[6:0], MOSI};
            rxd_done <= 1'b1;
        end else begin
            rxd_done <= 1'b0;
        end
    end else begin
        rxd_done <= 1'b0;
    end
end

// 生成接收完成脉冲
reg rxd_done_prev;
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        rxd_done_prev <= 1'b0;
    end else begin
        rxd_done_prev <= rxd_done;
    end
end
assign rxd_flag = rxd_done && !rxd_done_prev;

// ---------------------- 数据发送 ----------------------
reg [7:0] txd_shift;
reg [3:0] bit_count_tx;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        txd_shift <= 8'b0;
        bit_count_tx <= 4'd0;
        MISO <= 1'b0;
    end else if (!cs_active) begin
        // CS无效时复位
        txd_shift <= 8'b0;
        bit_count_tx <= 4'd0;
        MISO <= 1'b0;
    end else if (cs_active && bit_count_tx == 0) begin
        // CS有效且尚未开始传输时，加载数据并输出第一位
        txd_shift <= txd_data;
        MISO <= txd_data[7];
        bit_count_tx <= 4'd1;
    end else if (sck_falling) begin
        // 下降沿移位输出下一位
        if (bit_count_tx < 4'd8) begin
            txd_shift <= {txd_shift[6:0], 1'b0};
            MISO <= txd_shift[6];
            bit_count_tx <= bit_count_tx + 4'd1;
        end
    end
end

endmodule