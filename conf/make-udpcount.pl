#!/usr/bin/perl -w
#
# Copyright (c) 2000 Massachusetts Institute of Technology.
#
# make-udpcount.pl -- make an udpcount configuration
#
# ./make-udpcount.pl s d
#    options: s - network number of source (e.g. 2)
#             d - network number of destination (e.g. 3)

my $rtrifs = [ 
# ethernet address of card on router
	[ "00:C0:95:E2:16:9C" ], # 1.0.0.1
	[ "00:C0:95:E2:16:9D" ], # 2.0.0.1
	[ "00:C0:95:E2:09:14" ], # 3.0.0.1
	[ "00:C0:95:E2:09:15" ], # 4.0.0.1
	[ "00:C0:95:E1:FC:D4" ], # 5.0.0.1
	[ "00:C0:95:E1:FC:D5" ], # 6.0.0.1
	[ "00:C0:95:E1:FC:D6" ], # 7.0.0.1
	[ "00:C0:95:E1:FC:D7" ], # 8.0.0.1
];

my $cltifs = [
# ethernet address of sender/receiver, interface on machine for tx/rx
	[ "00:A0:CC:55:E3:D0", "eth1" ], # 1.0.0.2
	[ "00:00:C0:B4:68:EF", "eth0" ], # 2.0.0.2
	[ "00:E0:29:05:E4:DA", "eth1" ], # 3.0.0.2
	[ "00:00:C0:4F:71:EF", "eth1" ], # 4.0.0.2
	[ "00:00:C0:61:67:EF", "eth1" ], # 5.0.0.2
	[ "00:00:C0:CA:68:EF", "eth1" ], # 6.0.0.2
	[ "00:E0:29:05:E2:D4", "eth1" ], # 7.0.0.2
	[ "00:00:C0:8A:67:EF", "eth1" ], # 8.0.0.2
];

if ($#ARGV != 1) {
  print "usage: make-udpcount.pl src dest\n";
  print "   where src and dest are network numbers between 1 and 8\n";
  exit();
}

my $s = $ARGV[0];
my $d = $ARGV[1];

if ($s < 1 || $s > 8 || $d < 1 || $d > 8) {
  print "usage: make-udpcount.pl src dest\n";
  print "   where src and dest are network numbers between 1 and 8\n";
  exit();
}
 

print "// Generated by make-udpcount.pl\n";

{
print <<EOF

ar	:: ARPResponder($d.0.0.2 $cltifs->[$d-1]->[0]);
c0	:: Classifier(12/0806 20/0001, -);
pd	:: PollDevice($cltifs->[$d-1]->[1]);
td	:: ToDevice($cltifs->[$d-1]->[1]);
out	:: Queue(200) -> td;
tol	:: ToLinux;

pd -> [0]c0;
c0[0] -> ar -> out;
c0[1] -> Counter -> tol;

ScheduleInfo(td 1, pd 1);
EOF
}

