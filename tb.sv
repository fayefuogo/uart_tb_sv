class transaction;
  
  typedef enum bit  {write = 1'b0, read = 1'b1} oper_type;
  
  randc oper_type operation;
  
  bit received;
  
  rand bit [7:0] data_in;
  
  bit new_data;
  bit transmitted;
  
  bit [7:0] data_out;
  bit done_tx;
  bit done_rx;
  
  function transaction copy();
    copy = new();
    copy.received = this.received;
    copy.data_in = this.data_in;
    copy.new_data = this.new_data;
    copy.transmitted = this.transmitted;
    copy.data_out = this.data_out;
    copy.done_tx = this.done_tx;
    copy.done_rx = this.done_rx;
    copy.operation = this.operation;
  endfunction
  
endclass
 
class generator;
  
  transaction trans;
  mailbox #(transaction) mailbox_trans;
  
  event test_done;
  
  int transaction_count = 0;
  
  event drive_next;
  event score_next;
  
  function new(mailbox #(transaction) mailbox_trans);
    this.mailbox_trans = mailbox_trans;
    trans = new();
  endfunction
  
  task run();
    repeat(transaction_count) begin
      assert(trans.randomize) else $error("[GEN] : Randomization Failed");
      mailbox_trans.put(trans.copy);
      $display("[GEN]: Operation : %0s Data In : %0d", trans.operation.name(), trans.data_in);
      @(drive_next);
      @(score_next);
    end
    
    -> test_done;
  endtask
  
endclass

class driver;
  
  virtual uart_if uart_interface;
  transaction trans;
  mailbox #(transaction) mailbox_trans;
  mailbox #(bit [7:0]) mailbox_data_sent;
  
  event drive_next;
  
  bit [7:0] data_in_reg;
  bit write_op = 0;  
  bit [7:0] data_received_reg;  
  
  function new(mailbox #(bit [7:0]) mailbox_data_sent, mailbox #(transaction) mailbox_trans);
    this.mailbox_trans = mailbox_trans;
    this.mailbox_data_sent = mailbox_data_sent;
  endfunction
  
  task reset();
    uart_interface.rst <= 1'b1;
    uart_interface.data_in <= 0;
    uart_interface.new_data <= 0;
    uart_interface.received <= 1'b1;
 
    repeat(5) @(posedge uart_interface.uclk_tx);
    uart_interface.rst <= 1'b0;
    @(posedge uart_interface.uclk_tx);
    $display("[DRV] : RESET DONE");
    $display("----------------------------------------");
  endtask
  
  task run();
    forever begin
      mailbox_trans.get(trans);
      
      if(trans.operation == 1'b0) begin
        @(posedge uart_interface.uclk_tx);
        uart_interface.rst <= 1'b0;
        uart_interface.new_data <= 1'b1;  
        uart_interface.received <= 1'b1;
        uart_interface.data_in = trans.data_in;
        @(posedge uart_interface.uclk_tx);
        uart_interface.new_data <= 1'b0;
        mailbox_data_sent.put(trans.data_in);
        $display("[DRV]: Data Sent : %0d", trans.data_in);
        wait(uart_interface.done_tx == 1'b1);  
        -> drive_next;
      end else if (trans.operation == 1'b1) begin
        @(posedge uart_interface.uclk_rx);
        uart_interface.rst <= 1'b0;
        uart_interface.received <= 1'b0;
        uart_interface.new_data <= 1'b0;
        @(posedge uart_interface.uclk_rx);
        
        for(int i=0; i<=7; i++) begin   
          @(posedge uart_interface.uclk_rx);                
          uart_interface.received <= $urandom;
          data_received_reg[i] = uart_interface.received;                                      
        end 
        
        mailbox_data_sent.put(data_received_reg);
        $display("[DRV]: Data Received : %0d", data_received_reg); 
        wait(uart_interface.done_rx == 1'b1);
        uart_interface.received <= 1'b1;
        -> drive_next;
      end       
    end
  endtask
endclass

class monitor;
  
  transaction trans;
  mailbox #(bit [7:0]) mailbox_monitor;
  
  bit [7:0] sent_data;
  bit [7:0] received_data;
  
  virtual uart_if uart_interface;
  
  function new(mailbox #(bit [7:0]) mailbox_monitor);
    this.mailbox_monitor = mailbox_monitor;
  endfunction
  
  task run();
    forever begin
      @(posedge uart_interface.uclk_tx);
      if ((uart_interface.new_data == 1'b1) && (uart_interface.received == 1'b1)) begin
        @(posedge uart_interface.uclk_tx); 
        
        for(int i = 0; i<= 7; i++) begin 
          @(posedge uart_interface.uclk_tx);
          sent_data[i] = uart_interface.tx;
        end
        
        $display("[MON] : DATA SENT on UART TX %0d", sent_data);
        @(posedge uart_interface.uclk_tx); 
        mailbox_monitor.put(sent_data);
      end else if ((uart_interface.received == 1'b0) && (uart_interface.new_data == 1'b0)) begin
        wait(uart_interface.done_rx == 1);
        received_data = uart_interface.data_out;     
        $display("[MON] : DATA RECEIVED on RX %0d", received_data);
        @(posedge uart_interface.uclk_tx); 
        mailbox_monitor.put(received_data);
      end
    end  
  endtask
  
endclass

class scoreboard;
  mailbox #(bit [7:0]) mailbox_data_sent, mailbox_monitor;
  
  bit [7:0] sent_data;
  bit [7:0] monitor_data;
  
  event score_next;
  
  function new(mailbox #(bit [7:0]) mailbox_data_sent, mailbox #(bit [7:0]) mailbox_monitor);
    this.mailbox_data_sent = mailbox_data_sent;
    this.mailbox_monitor = mailbox_monitor;
  endfunction
  
  task run();
    forever begin
      mailbox_data_sent.get(sent_data);
      mailbox_monitor.get(monitor_data);
      
      $display("[SCO] : DRIVER DATA : %0d MONITOR DATA : %0d", sent_data, monitor_data);
      if(sent_data == monitor_data)
        $display("DATA MATCHED");
      else
        $display("DATA MISMATCHED");
      
      $display("----------------------------------------");
      
      -> score_next; 
    end
  endtask
endclass

class environment;
  
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco; 
  
  event next_gen_drv;  
  event next_gen_sco;  
  
  mailbox #(transaction) mailbox_gen_drv;
  mailbox #(bit [7:0]) mailbox_data_sent;  
  mailbox #(bit [7:0]) mailbox_monitor;  
  
  virtual uart_if uart_interface;
  
  function new(virtual uart_if uart_interface);
    mailbox_gen_drv = new();
    mailbox_monitor = new();
    mailbox_data_sent = new();
    
    gen = new(mailbox_gen_drv);
    drv = new(mailbox_data_sent, mailbox_gen_drv);
    
    mon = new(mailbox_monitor);
    sco = new(mailbox_data_sent, mailbox_monitor);
    
    this.uart_interface = uart_interface;
    drv.uart_interface = this.uart_interface;
    mon.uart_interface = this.uart_interface;
    
    gen.score_next = next_gen_sco;
    sco.score_next = next_gen_sco;
    
    gen.drive_next = next_gen_drv;
    drv.drive_next = next_gen_drv;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask
  
  task post_test();
    wait(gen.test_done.triggered);  
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass

module tb;
    
  uart_if uart_interface();
  
  uart_top #(1000000, 9600) dut (uart_interface.clk, uart_interface.rst, uart_interface.received, uart_interface.data_in, uart_interface.new_data, uart_interface.tx, uart_interface.data_out, uart_interface.done_tx, uart_interface.done_rx);
  
  initial begin
    uart_interface.clk <= 0;
  end
    
  always #10 uart_interface.clk <= ~uart_interface.clk;
    
  environment env;
  
  initial begin
    env = new(uart_interface);
    env.gen.transaction_count = 5;
    env.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
   
  assign uart_interface.uclk_tx = dut.utx.uclk;
  assign uart_interface.uclk_rx = dut.rtx.uclk;
    
endmodule
