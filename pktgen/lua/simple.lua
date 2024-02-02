require "Pktgen"

function SetupTraffic(n,d,r)
  pktgen.reset("all");

  pktgen.set("all", "count", 0);
  pktgen.set("all", "rate", 10);
  pktgen.set("all", "size", 64);
  pktgen.set_proto("all", "udp");


  pktgen.set("0", "count", n);
  pktgen.set("0", "dport", 2222); -- set 0 dport 2222
  pktgen.set("0", "rate", r);
  pktgen.set("0", "size", d);
  pktgen.set("0", "sport", 400);
  pktgen.set_ipaddr("0", "dst", "16.2.2.2/24"); -- set 0 dst ip 16.2.2.2
  pktgen.set_ipaddr("0", "src", "16.1.1.1"); -- set 0 src ip 16.1.1.1/24
  pktgen.set_mac("0", "dst", "10:00:00:00:00:10");
  pktgen.set_mac("0", "src", "10:00:00:00:00:12");
  -- pktgen:10:00:00:00:00:12 -> left tor.3 ->10:00:00:00:00:10:testpmd 
  --                                                              |
  -- pktgen:20:00:00:00:00:13 <- right tor.121 <- 20:00:00:00:00:11:testpmd

  pktgen.set("1", "count", 1);
  pktgen.set("1", "dport", 555);
  pktgen.set("1", "rate", 0.1);
  pktgen.set("1", "size", 64);
  pktgen.set("1", "sport", 500);
  pktgen.set_ipaddr("1", "dst", "16.1.1.1/24");
  pktgen.set_ipaddr("1", "src", "16.2.2.2");
  pktgen.set_mac("1", "dst", "20:00:00:00:00:11");
  pktgen.set_mac("1", "src", "20:00:00:00:00:13"); -- set 1 src mac 20:00:00:00:00:13
end


function Main(input)

  local n = input["n"] or 1000000
  local p = input["p"] or 1024
  local r = input["r"] or 20
  SetupTraffic(n,p,r)
  printf("# to transmit " .. n .. " packets with packetSize " .. p .. "B at rate " .. r .. "%%\n" )

  pktgen.clr()
  pktgen.start(1)
  pktgen.start(0)
  while ( pktgen.isSending("0")[0] == "y" ) do sleep(1) end

  sleep(5)
  local statTx = pktgen.portStats("all", "port")[0];
  local statRx = pktgen.portStats("all", "port")[1];
  local num_tx, num_rx
  num_tx = statTx.opackets; -- + statRx.opackets;
  num_rx = statRx.ipackets; -- + statTx.ipackets;
  printf("#tx:" .. num_tx .. ", rx:" .. num_rx .. ", drop:" .. num_tx -num_rx .. "\n")

end

I={n=90000, r=1,  p= 512}
Main(... or I);
