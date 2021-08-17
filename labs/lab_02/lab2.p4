/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/* My include */
#include "include/headers.p4"
#include "include/parsers.p4"


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    
    action drop() {
        mark_to_drop(standard_metadata);
    }

    action set_ecmp_select(bit<16> ecmp_base, bit<32> ecmp_count) {
        hash(
          meta.ecmp_select,
          HashAlgorithm.crc16,
          ecmp_base,
          { 
            hdr.ipv4.srcAddr,
            hdr.ipv4.dstAddr,
            hdr.ipv4.protocol,
            hdr.tcp.srcPort,
            hdr.tcp.dstPort 
          },
          ecmp_count);
    }

    action set_nhop(bit<48> nhop_dmac, bit<32> nhop_ipv4, bit<9> port) {
        hdr.ethernet.dstAddr = nhop_dmac;
        hdr.ipv4.dstAddr = nhop_ipv4;
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ecmp_group {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            drop;
            set_ecmp_select;
        }
        size = 1024;
    }

    table ecmp_nhop {
        key = {
            meta.ecmp_select: exact;
        }
        actions = {
            drop;
            set_nhop;
        }
        size = 2;
    }

    apply {
        if (hdr.ipv4.isValid() && hdr.ipv4.ttl > 0) {
            ecmp_group.apply();
            ecmp_nhop.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    
    counter(5, CounterType.packets) marked_packets; // array of 5 egress ports

    counter(1, CounterType.packets) not_marked_packets; // count everything to a single field array.


    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }

    action mark_ecn(qsize_threshold_t threshold) {
        if (hdr.ipv4.ecn == 1 || hdr.ipv4.ecn == 2) {
            if (standard_metadata.enq_qdepth >= threshold){
                hdr.ipv4.ecn = 3;
            }
        }
        // egress port number as index in the counter array
        marked_packets.count((bit<32>)standard_metadata.egress_port);
    }

    action drop() {
        mark_to_drop(standard_metadata);
    }

    table send_frame {
        key = {
            standard_metadata.egress_port: exact;
        }

        actions = {
            rewrite_mac;
            drop;
        }
        size = 256;
    }

    table ecn_marking {
        key = {
            standard_metadata.egress_port: exact;
        }

        actions = {
            mark_ecn;
            drop;
        }
        size = 256;
    }

    apply {
        send_frame.apply();
        if (!ecn_marking.apply().hit) {
            not_marked_packets.count(0);
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
    update_checksum(
        hdr.ipv4.isValid(),
            { 
              hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr 
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;