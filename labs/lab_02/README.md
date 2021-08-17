# Combined ECMP load balancing with ECN marking

## Requirements

1) Do ECMP load balancing

2) Set ECN bit if queue size (qdepth) is larger than a pre-defined threshold QSIZE_THRESHOLD

3) QSIZE_THRESHOLD should be configurable from a table per port

Example: table_add ecn_marking mark_ecn 3 => 10 (QSIZE_THRESHOLD)


## Solution

* Check if standard_metadata.deq_qdepth >= QSIZE_THRESHOLD then hdr.ipv4.ecn = 3
* Make sure that the sender has ECN bit enabled, i.e., TOS = 1 in send.py

## Run the solution

1) Compile and build topology

	```bash
	cd lab_02 && make 
	```

2) Open five terminals for `h1`, `h11`, `h2`, `h22`, and `h3` respectively:

   ```bash
   mininet> xterm h1 h11 h2 h22 h3
   ``` 
3) In `h2`'s xterm, start the server that captures packets:

   ```bash
   ./receive.py > h2.log
   ```
4) In `h3`'s xterm, start the server that captures packets:

   ```bash
   ./receive.py > h3.log
   ```

5) in `h22`'s xterm, start the iperf UDP server:

   ```bash
   iperf -s -u
   ```

6) In `h1`'s xterm, send one packet per second to `10.0.0.1` using send.py for 30 seconds:
   
   ```bash
   ./send.py 10.0.0.1 "P4 is cool" 30
   ```
   
   The message "P4 is cool" should be received in `h2`'s and `h3`'s xterm.

7) In `h11`'s xterm, start iperf client sending for 15 seconds

   ```bash
   iperf -c 10.0.2.22 -t 15 -u
   ```

8) Check h2.log to make sure it also receives packets sent from `h1`
   and it has also the ECN marking value, i.e., tos = 0x3 because of the congested link between `s1` and `s2`.

     ```bash
     less logs/h2.log
     ```

    got a packet
    ###[ Ethernet ]###
      dst       = 00:00:00:00:02:02
      src       = 00:00:00:02:01:00
      type      = 0x800
    ###[ IP ]###
         version   = 4L
         ihl       = 5L
         tos       = 0x3
         len       = 50
         id        = 1
         flags     = 
         frag      = 0L
         ttl       = 62
         proto     = tcp
         chksum    = 0x65c0
         src       = 10.0.1.1
         dst       = 10.0.2.2
         \options   \
    ###[ TCP ]###
            sport     = 57837
            dport     = 1234
            seq       = 0
            ack       = 0
            dataofs   = 5L
            reserved  = 0L
            flags     = S
            window    = 8192
            chksum    = 0xdd7d
            urgptr    = 0
            options   = []
    ###[ Raw ]###
               load      = 'P4 is cool'


9) Check h3.log to make sure it also receives packets sent from `h1`    
    
    ```bash
     less logs/h3.log
     ```

    sniffing on h3-eth0
    got a packet
    ###[ Ethernet ]###
      dst       = 00:00:00:00:03:03
      src       = 00:00:00:03:01:00
      type      = 0x800
    ###[ IP ]###
         version   = 4L
         ihl       = 5L
         tos       = 0x1
         len       = 50
         id        = 1
         flags     = 
         frag      = 0L
         ttl       = 62
         proto     = tcp
         chksum    = 0x64c1
         src       = 10.0.1.1
         dst       = 10.0.3.3
         \options   \
    ###[ TCP ]###
            sport     = 50419
            dport     = 1234
            seq       = 0
            ack       = 0
            dataofs   = 5L
            reserved  = 0L
            flags     = S
            window    = 8192
            chksum    = 0xfa77
            urgptr    = 0
            options   = []
    ###[ Raw ]###
               load      = 'P4 is cool'


## Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background.  Use the following command to clean up
these instances:

```bash
make stop
```
