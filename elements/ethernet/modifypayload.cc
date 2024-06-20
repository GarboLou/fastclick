
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
#include "modifypayload.hh"
#include <clicknet/ether.h>
#include <click/args.hh>
#include <click/error.hh>
CLICK_DECLS

ModifyPayload::ModifyPayload() : _grow(false), _delay(0)
{
}

ModifyPayload::~ModifyPayload()
{
}

int
ModifyPayload::configure(Vector<String> &conf, ErrorHandler *errh)
{
    if (Args(conf, this, errh)
        .read_mp("OFFSET", _offset)
        .read_mp("DATA", _data)
        .read_mp("DELAY", _delay)
        .read_p("MASK", _mask)
        .read("GROW", _grow)
        .complete() < 0)
        return -1;

    if (_mask && _mask.length() > _data.length())
        return errh->error("MASK must be no longer than DATA");

    return 0;
}

int
ModifyPayload::initialize(ErrorHandler *)
{
    if (_mask) {
        auto md = _data.mutable_data();
        for (int i = 0; i < _mask.length(); i++)
            md[i] = md[i] & _mask[i];
    }
    return 0;
}

Packet *
ModifyPayload::simple_action(Packet *p)
{
    if (WritablePacket *q = p->uniqueify()) {
        unsigned char temp_packet[q->length()];
        int len = q->length() - _offset;
        // do a simple memcpy of the entire packet
        memcpy(&temp_packet, q->data(), q->length());

        // modify packet at offset with provided data
        if (_grow && _data.length() > len) {
            q = q->put(_data.length() - len);
            len = q->length() - _offset;
        }
        if (_mask) {
            auto qd = q->data();
            for (int i = 0; i < (_data.length() < len ? _data.length() : len); i++) {
                if (i < _mask.length())
                    qd[_offset + i] = (qd[_offset + i] & ~_mask[i]) | _data[i];
                else
                    qd[_offset + i] = _data[i];
            }
        }
        else {
            memcpy(q->data() + _offset, _data.data(), (_data.length() < len ? _data.length() : len));
        }

        // printf("delay is %d\n", _delay);

        struct timespec start, end;
        long elapsed_nanoseconds;

        clock_gettime(CLOCK_MONOTONIC, &start);
        do {
            clock_gettime(CLOCK_MONOTONIC, &end);
            elapsed_nanoseconds = (end.tv_sec - start.tv_sec) * 1000000000L + (end.tv_nsec - start.tv_nsec);
        } while (elapsed_nanoseconds < _delay);

        return q;
    } else
        return 0;

    return 0;
}

#if HAVE_BATCH
PacketBatch *
ModifyPayload::simple_action_batch(PacketBatch *batch)
{
#ifdef CLICK_NOINDIRECT
    FOR_EACH_PACKET(batch, p)   {
        ModifyPayload::simple_action(p);
    }
#else
    EXECUTE_FOR_EACH_PACKET_DROPPABLE(ModifyPayload::simple_action, batch, [](Packet*){});
#endif
    return batch;
}
#endif

CLICK_ENDDECLS
EXPORT_ELEMENT(ModifyPayload)
ELEMENT_MT_SAFE(ModifyPayload)
