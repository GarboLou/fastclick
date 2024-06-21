
/*
 * ethermirror.{cc,hh} -- rewrites Ethernet packet a->b to b->a
 * Eddie Kohler
 *
 * Computational batching support
 * by Georgios Katsikas
 *
 * Copyright (c) 2000 Massachusetts Institute of Technology
 * Copyright (c) 2017 KTH Royal Institute of Technology
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, subject to the conditions
 * listed in the Click LICENSE file. These conditions include: you must
 * preserve this copyright notice, and you cannot mention the copyright
 * holders in advertising related to the Software without their permission.
 * The Software is provided WITHOUT ANY WARRANTY, EXPRESS OR IMPLIED. This
 * notice is a summary of the Click LICENSE file; the license in that file is
 * legally binding.
 */

#include <click/config.h>
#include "modifytimestamp.hh"
#include <clicknet/ether.h>
#include <click/glue.hh>
#include <click/args.hh>
#include <click/error.hh>
#include <click/tsctimestamp.hh>
# include <click/dpdkdevice.hh>

CLICK_DECLS

ModifyTimestamp::ModifyTimestamp() : _delay(0)
{
}

ModifyTimestamp::~ModifyTimestamp()
{
}

int
ModifyTimestamp::configure(Vector<String> &conf, ErrorHandler *errh)
{
    if (Args(conf, this, errh)
        .read_mp("OFFSET", _offset)
        .read_mp("DELAY", _delay)
        .complete() < 0)
        return -1;

    return 0;
}

int
ModifyTimestamp::initialize(ErrorHandler *)
{
    return 0;
}

Packet *
ModifyTimestamp::simple_action(Packet *p)
{
    WritablePacket *q;
    uint64_t tsc_freq = cycles_hz();
    uint64_t access_start, access_end, access_time;
    uint64_t compute_start, compute_end, compute_time;
    my_timestamp access_timestamp, compute_timestamp;
    // printf("tsc frequency is %ld\n", tsc_freq);

    access_start = click_get_cycles();
    q = p->uniqueify();
    access_end = click_get_cycles();

    if (q != NULL) {
        compute_start = click_get_cycles();
        access_time = access_end - access_start;

        char temp_packet[q->length()];

        // do a simple memcpy of the entire packet
        memcpy(&temp_packet, q->data(), q->length());
        size_t header_offset = sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr);

        do {
            compute_end = click_get_cycles();
            compute_time = compute_end - compute_start;
        } while (compute_time * 1E9 < _delay * tsc_freq);

        // printf("packet length is %d, access_time is %ld, compute_time is %ld\n", q->length(), access_time, compute_time);

        // add memory access time to packet at offset
        memcpy(q->data() + _offset + header_offset, &access_time, sizeof(access_time));
        // add compute access time to packet at offset
        memcpy(q->data() + _offset + header_offset + sizeof(access_time), &compute_time, sizeof(compute_time));

        // printf("delay is %d\n", _delay);
        return q;
    } else
        return 0;

    return 0;
}

#if HAVE_BATCH
PacketBatch *
ModifyTimestamp::simple_action_batch(PacketBatch *batch)
{
#ifdef CLICK_NOINDIRECT
    FOR_EACH_PACKET(batch, p)   {
        ModifyTimestamp::simple_action(p);
    }
#else
    EXECUTE_FOR_EACH_PACKET_DROPPABLE(ModifyTimestamp::simple_action, batch, [](Packet*){});
#endif
    return batch;
}
#endif

CLICK_ENDDECLS
EXPORT_ELEMENT(ModifyTimestamp)
ELEMENT_MT_SAFE(ModifyTimestamp)
