#ifndef CLICK_ModifyTimestamp_HH
#define CLICK_ModifyTimestamp_HH
#include <click/batchelement.hh>
CLICK_DECLS

/*
 * =c
 * ModifyTimestamp()
 * =s ethernet
 * modify the packet payload contents
 * =d
 *
 * Incoming packets are Ethernet. The payload is memcpy-ed. Their payload is modified.
 * Then it adds _delay latency to the overall processing time.
 * If grow is true, then the packet length will be extended.
 * */

class ModifyTimestamp : public BatchElement {
    public:

        ModifyTimestamp() CLICK_COLD;
        ~ModifyTimestamp() CLICK_COLD;

        const char *class_name() const override    { return "ModifyTimestamp"; }
        const char *port_count() const override    { return PORTS_1_1; }

        int configure(Vector<String> &, ErrorHandler *) CLICK_COLD;
        int initialize(ErrorHandler *) CLICK_COLD;

        Packet *simple_action(Packet *);
    #if HAVE_BATCH
        PacketBatch *simple_action_batch(PacketBatch *);
    #endif
    private:

        unsigned _offset;
        uint64_t _delay;

        struct my_timestamp { 
            char data[64]; 
        }; 
};

CLICK_ENDDECLS
#endif // CLICK_ModifyTimestamp_HH
