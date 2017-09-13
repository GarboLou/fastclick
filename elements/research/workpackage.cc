// -*- c-basic-offset: 4 -*-
/*
 * WorkPackage.{cc,hh} --
 * Tom Barbette
 *
 * Copyright (c) 2017 University of Liege
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
#include "workpackage.hh"
#include <click/args.hh>
#include <click/error.hh>
#include <click/standard/scheduleinfo.hh>
#include <random>

CLICK_DECLS

std::random_device rd;

#define FRAND_MAX rd.max()

inline int frand() {
    return rd();
}

WorkPackage::WorkPackage()
{
}

int
WorkPackage::configure(Vector<String> &conf, ErrorHandler *errh)
{
    int s;
    if (Args(conf, this, errh)
        .read_mp("S", s) //Array size in MB
        .read_mp("N", _n) //Number of array access (4bytes)
        .read_mp("R", _r) //Percentage of access that are packet read (vs Array access) between 0 and 100
        .read_mp("PAYLOAD", _payload) //Access payload or only header
        .read("W",_w) //Amount of work (x100 xor on the data just read)
        .complete() < 0)
        return -1;
    _array.resize(s * 1024 * 1024 / sizeof(uint32_t));
    for (int i = 0; i < _array.size(); i++) {
        _array[i] = frand();
    }
    return 0;
}

void
WorkPackage::smaction(Packet* p) {
    uint32_t sum = 0;
    int r = frand();
    for (int i = 0; i < _n; i++) {
        uint32_t data;
        if (r / (FRAND_MAX / 101 + 1) < _r) {
            int pos = r / (FRAND_MAX / ((_payload?p->length():54) + 1) + 1);
            data = *(uint32_t*)(p->data() + pos);
        } else {
            int pos = r / ((FRAND_MAX / _array.size()) + 1);
            data = _array[pos];
        }
        for (int j = 0; j < _w * 100; j ++) {
            sum ^= data;
        }
        r = data ^ (r << 24 ^ r << 16  ^ r << 8 ^ r >> 16);
    }
}

#if HAVE_BATCH
void
WorkPackage::push_batch(int port, PacketBatch* batch) {
    FOR_EACH_PACKET(batch, p)
            smaction(p);
    output_push_batch(port, batch);
}
#endif

void
WorkPackage::push(int port, Packet* p) {
    smaction(p);
    output_push(port, p);
}


CLICK_ENDDECLS
EXPORT_ELEMENT(WorkPackage)
