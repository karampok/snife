package.path = package.path ..";?.lua;test/?.lua;app/?.lua"

require "Pktgen"

pktgen.screen("off");

pktgen.set("all", "count", 10000);
pktgen.set("all", "rate", 1);
pktgen.set("all", "size", 64);
pktgen.set_proto("all", "udp");

pktgen.set_mac("0", "src", "50:00:00:00:00:01");
pktgen.set_mac("0", "dst", "50:00:00:00:00:11");
pktgen.set_ipaddr("0", "src", "16.1.1.1/24");
pktgen.set("0", "sport", 400);
pktgen.set_ipaddr("0", "dst", "16.2.2.2/24");
pktgen.set("0", "dport", 444);

pktgen.set_mac("1", "src", "50:00:00:00:00:02");
pktgen.set_mac("1", "dst", "50:00:00:00:00:12");
pktgen.set_ipaddr("1", "src", "16.2.2.2/24");
pktgen.set("1", "sport", 500);
pktgen.set_ipaddr("1", "dst", "16.1.1.1/24");
pktgen.set("1", "dport", 555);


print("[  INFO ] Starting Test...");
pktgen.start("0");
-- code for taking input of packet size, rate from the user
-- setting the packet size & rate
-- code to check time to run
-- pktgen.stop("0");
