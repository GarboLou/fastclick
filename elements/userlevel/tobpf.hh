#ifndef TOBPF_HH
#define TOBPF_HH
#include "element.hh"
#include "string.hh"
#include "elements/userlevel/frombpf.hh"

/*
 * =c
 * ToBPF(DEVNAME)
 * =d
 *
 * This element has been deprecated. Use ToDevice(DEVNAME) instead.
 * 
 * =a ToDevice.u */

class ToBPF : public Element {
 public:
  
  ToBPF();
  
  const char *class_name() const		{ return "ToBPF"; }
  ToBPF *clone() const;
  const char *processing() const		{ return AGNOSTIC; }
  
  int configure(const Vector<String> &, ErrorHandler *);
  
};

#endif
