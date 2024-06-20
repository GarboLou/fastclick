/* sudo bin/click --dpdk -c 0xff -a 0000:17:00.1 -- test_config.click */

DPDKInfo(NB_MBUF 65535, MBUF_SIZE 8192, MBUF_CACHE_SIZE 512)
define($nfport 0000:17:00.1)

fd0 :: FromDPDKDevice($nfport, PROMISC true, PAUSE none, MAXTHREADS 4, N_QUEUES 4, NUMA false, VERBOSE 99, NDESC 2048, BURST 64, RSS_AGGREGATE true) 
-> c::AverageCounterMP()
-> EtherMirror()
-> ToDPDKDevice($nfport, VERBOSE 99, TIMEOUT -1, BLOCKING false)

/* if print every 1s */
Script( wait 1, 
        // print "Time "$(c.time)", rate is "$(c.rate)", bit rate is "$(c.bit_rate), 
        // print "Time "$(c.time)", rate is "$(c.rate)", byte rate is "$(c.byte_rate), 
        loop
)


DriverManager(
    read fd0.rss_reta,
    wait,
    read fd0.xstats,
    /* print after termination */
    print "Time "$(c.time)", rate is "$(c.rate)", byte rate is "$(c.byte_rate)
)
