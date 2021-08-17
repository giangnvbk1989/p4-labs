# Extended MRI implementation and ECN marking

## Requirements

1) Add the following INT data together with the switch ID and the queue depth:

* Ingress timestamp -> ingress_tstamp
* Queuing delay -> qdelay

2) Set ECN bit if qdelay is larger than a pre-defined threshold QDELAY_THRESHOLD

## Solution

* ingress_tstamp can be obtained from standard_metadata.ingress_global_timestamp
* qdelay can be obtained from standard_metadata.deq_timedelta
* set QDELAY_THRESHOLD = 1000 us and check if standard_metadata.deq_timedelta >= QDELAY_THRESHOLD then hdr.ipv4.ecn = 3
* Make sure that the sender has ECN enabled, i.e., TOS = 1 in send.py

## Run the solution

1) Compile and build topology

	```bash
	cd lab_03 && make 
	```

2) Open four terminals for `h1`, `h11`, `h2`, `h22`, respectively:

   ```bash
   mininet> xterm h1 h11 h2 h22
   ``` 
3) In `h2`'s xterm, start the server that captures packets:

   ```bash
   ./receive.py > h2.log
   ```
4) in `h22`'s xterm, start the iperf UDP server:
   
   ```bash
   iperf -s -u
   ```

5) In `h1`'s xterm, send one packet per second to `h2` using send.py script for 30 seconds:
   
   ```bash
   ./send.py 10.0.2.2 "P4 is cool" 30
   ```
   The message "P4 is cool" should be received in `h2`'s xterm,
6) In `h11`'s xterm, start iperf client sending for 15 seconds
   
   ```bash
   iperf -c 10.0.2.22 -t 15 -u
   ```
7) Check h2.log
   Queuing delay information:
	
	```bash
	grep -r qdelay h2.log
	```
     qdelay    = 64
     qdelay    = 13
     qdelay    = 13
     qdelay    = 46
     qdelay    = 58
     qdelay    = 29
     qdelay    = 17
     qdelay    = 145
     qdelay    = 60
     qdelay    = 509
     qdelay    = 288065
     qdelay    = 22
     qdelay    = 428951
     qdelay    = 16
     qdelay    = 1303672
     qdelay    = 15
     qdelay    = 1413692
     qdelay    = 213
     qdelay    = 2111705
     qdelay    = 179
     qdelay    = 1084932
     qdelay    = 165
     qdelay    = 1581901
     qdelay    = 359
     qdelay    = 560695


   ECN marking information:

     ```bash
     grep -r tos h2.log
     ```
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x3
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1
     tos       = 0x1

## Cleaning up Mininet

In the latter two cases above, `make` may leave a Mininet instance
running in the background.  Use the following command to clean up
these instances:

```bash
make stop
```
