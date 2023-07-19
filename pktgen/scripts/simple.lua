require "Pktgen";

local sendport      = "0";
local recvport      = "1";

function Round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
end

function SetupTraffic()
  Srcip     = "16.1.1.1";
  Dstip     = "16.2.2.2";
  Netmask   = "/24";
  P0_udpp_src = 10000;
  P0_udpp_dst = 20000;
  P1_udpp_src = 30000;
  P1_udpp_dst = 40000;
  P0_destmac  = "10:00:00:00:00:10";
  P1_destmac  = "20:00:00:00:00:11";

  pktgen.reset("all");
  pktgen.set_type("all", "ipv4");
  pktgen.set_proto(sendport..","..recvport, "udp");
  pktgen.set_ipaddr(sendport, "dst", Dstip);
  pktgen.set_ipaddr(sendport, "src", Srcip..Netmask);
  pktgen.set_ipaddr(recvport, "dst", Srcip);
  pktgen.set_ipaddr(recvport, "src", Dstip..Netmask);
  pktgen.set(sendport, "sport", P0_udpp_src);
  pktgen.set(sendport, "dport", P0_udpp_dst);
  pktgen.set(recvport, "sport", P1_udpp_src);
  pktgen.set(recvport, "dport", P1_udpp_dst);
  if P0_destmac then pktgen.set_mac(sendport, "dst", P0_destmac); end
  if P1_destmac then pktgen.set_mac(recvport ,"dst", P1_destmac); end
end


function RunTrial(speed, size, rate, duration,loss_tol, wait)
  local max_pps = Round((speed * 10^6)/((size + 20) * 8));
  local count = Round((max_pps * (rate/100))*(duration/1000));
  local loss_limit = Round(count*(loss_tol/100));

  print("Size: ".. size.."B| Rate: "..rate.."%| Link: "..speed.." | NumPkts: "..count.."| LossLimit: "..loss_limit.." | Dur:"..duration/1000 .."s");
  pktgen.clr();
  pktgen.set("0", "rate", rate);
  pktgen.set("0", "size", size);
  pktgen.set("0", "count", count );
  pktgen.start(0);
  pktgen.delay(duration);
  pktgen.stop(0);
  pktgen.delay(wait);

  local statTx = pktgen.portStats(sendport, "port")[tonumber(sendport)];
  local statRx = pktgen.portStats(recvport, "port")[tonumber(recvport)];
  local num_tx, num_rx, num_dropped

  num_tx = statTx.opackets + statRx.opackets;
  num_rx = statRx.ipackets + statTx.ipackets;
  num_dropped = num_tx - num_rx;
  local loss = Round((1-(num_rx/num_tx))*100,3);
  print("tx: ".. num_tx.."| rx: "..num_rx.."| drop: "..num_dropped.."|loss: "..loss.."%");
  if num_dropped <= loss_limit
  then
    print("[OK ]");
  else
    print("[NOK]");
  end
end

Duration = 30000;
WaitTime = 5000;
LossLimit = 0.10;
Rate = 50

function Main(input)
  local d = input["d"] or Duration
  local r = input["r"] or Rate
  local l = input["l"] or LossLimit
  local p = input["p"] or {512}
  local linkSpeed= string.match(pktgen.linkState(sendport)[tonumber(sendport)],"%d+");

  SetupTraffic();
  for _,size in pairs(p)
  do
    RunTrial(linkSpeed, size, r, d, l, WaitTime);
  end
end

Main(... or {});
