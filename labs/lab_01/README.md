# Drop packets and counter practices

## Requirements

1) Drop all TCP packets and count how many TCP dropped packets

## Solution

* At Ingress pipepline, check if hdr.ipv4.protocol != TCP_PROTOCOL then forwards the packet, otherwise drops the packet and increase the counter by one.

## Run the solution

1) Compile and build topology
	
	```bash
	cd lab_01 && make 
	```

2) Open two terminals for `h1` and `h2` respectively:
   
   ```bash
   mininet> xterm h1 h2
   ``` 

3) In `h2`'s xterm, start the server that captures packets:

   ```bash
   ./receive.py
   ```

4) In `h1`'s xterm, send one TCP packet per second to `10.0.2.2` using send.py for 30 seconds:
   
   ```bash
   ./send.py 10.0.2.2 "P4 is cool" 30
   ```
`h2` should not receive any packets as expected.

5) Check counter for the number of TCP dropped packets at `s1` by reading the dropped_tcp_packets counter.

   ```bash
   simple_switch_CLI --thrift-port 9090

   	Obtaining JSON from switch...
	Done
	Control utility for runtime P4 table manipulation
	RuntimeCmd: counter_read dropped_tcp_packets 1
   ```

   We should get the following:

 	dropped_tcp_packets[1]=  BmCounterValue(packets=30, bytes=1920)

6) Verify again with udp traffic 

In `h2` xterm, start iperf server to listening for UDP traffic:
	
	```bash
	iperf -s -u
	```
In `h1` xterm, start ipert client to send UDP traffic to `h2`:
	
	```bash
	iperf -c 10.0.2.2 -u -t 15
	```
The UDP traffic should go through.
