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
    apply {  }
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
    
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }
    
    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    
    action mark_ecn() {

        if (hdr.ipv4.ecn == 1 || hdr.ipv4.ecn == 2){
            if (standard_metadata.deq_timedelta >= QDELAY_THRESHOLD){
               hdr.ipv4.ecn = 3;
            }
        }
    }

    action add_swtrace(switchID_t swid) { 
        
        hdr.mri.count = hdr.mri.count + 1;
        hdr.swtraces.push_front(1);
        
        // Required from P4_16 v1.1
        hdr.swtraces[0].setValid();

        // Add switch ID
        hdr.swtraces[0].swid = swid;
        // Add queue length
        hdr.swtraces[0].qdepth = (qdepth_t)standard_metadata.deq_qdepth;
        // Add ingress timepstamp
        hdr.swtraces[0].ingress_tstamp = (ingress_tstamp_t)standard_metadata.ingress_global_timestamp;
        // Add queue delay
        hdr.swtraces[0].qdelay = (qdelay_t)standard_metadata.deq_timedelta;

        // Modify header length
        hdr.ipv4.ihl = hdr.ipv4.ihl + 4;
        hdr.ipv4_option.optionLength = hdr.ipv4_option.optionLength + 16; 
	    hdr.ipv4.totalLen = hdr.ipv4.totalLen + 16;
    }

    table swtrace {

        actions = { 
	       add_swtrace; 
	       NoAction; 
        }

        default_action = NoAction();      
    }
    
    apply {
    
        if (hdr.mri.isValid()) {
            swtrace.apply();
        }
        // Mark ECN
        mark_ecn();
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
