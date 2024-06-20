#ifndef CLICK_MODIFYPAYLOAD_HH
#define CLICK_MODIFYPAYLOAD_HH
#include <click/batchelement.hh>
CLICK_DECLS

/*
 * =c
 * ModifyPayload()
 * =s ethernet
 * modify the packet payload contents
 * =d
 *
 * Incoming packets are Ethernet. The payload is memcpy-ed. Their payload is modified.
 * Then it adds _delay latency to the overall processing time.
 * If grow is true, then the packet length will be extended.
 * */

class ModifyPayload : public BatchElement {
    public:

        ModifyPayload() CLICK_COLD;
        ~ModifyPayload() CLICK_COLD;

        const char *class_name() const override    { return "ModifyPayload"; }
        const char *port_count() const override    { return PORTS_1_1; }

        int configure(Vector<String> &, ErrorHandler *) CLICK_COLD;
        int initialize(ErrorHandler *) CLICK_COLD;

        Packet *simple_action(Packet *);
    #if HAVE_BATCH
        PacketBatch *simple_action_batch(PacketBatch *);
    #endif
    private:

        unsigned _offset;
        String _data;
        String _mask;
        bool _grow;
        long _delay;

};

CLICK_ENDDECLS
#endif // CLICK_MODIFYPAYLOAD_HH
