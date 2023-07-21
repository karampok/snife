require "Pktgen";

Sendport      = "0";
Recvport      = "1";
Duration = 10000;
WaitTime = 5000;
LossLimit = 0.001;
Rate = 100

function Round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
end

function Stats(duration)
    print("# TS(sec),LTX(pps),RRX(pps)");
    local start_time = os.time();
    local ltxB,rrxB;
    while os.difftime(os.time(), start_time) < duration do
       local ltxA = pktgen.portStats(Sendport, "port")[tonumber(Sendport)].opackets;
       local rrxA = pktgen.portStats(Recvport, "port")[tonumber(Recvport)].ipackets;
       sleep(1);
       ltxB = pktgen.portStats(Sendport, "port")[tonumber(Sendport)].opackets;
       rrxB = pktgen.portStats(Recvport, "port")[tonumber(Recvport)].ipackets;
       print(os.time() .. "," .. ltxB-ltxA .. "," .. rrxB-rrxA);
     end
end



function RunTrial(speed, size, rate, duration,loss_tol, wait)
  local max_pps = Round((speed * 10^6)/((size + 20) * 8));
  local count = Round((max_pps * (rate/100))*(duration/1000));
  local loss_limit = Round(count*(loss_tol/100));


  Printf("Size: %dB| Rate: %d%%| Link: %d Mb/s| NumPkts: %d | LossLimit: %d (%2.3f%%) | Dur: %ds\n", size,rate,speed,count,loss_limit,loss_tol,duration/1000);
  pktgen.clr();
  pktgen.set("0", "rate", rate);
  pktgen.set("0", "size", size);
  pktgen.set("0", "count", count );
  pktgen.start(0);
  Stats(duration/1000); --pktgen.delay(duration)
  pktgen.stop(0);
  Stats(wait/1000); -- pktgen.delay(wait);

  local statTx = pktgen.portStats(Sendport, "port")[tonumber(Sendport)];
  local statRx = pktgen.portStats(Recvport, "port")[tonumber(Recvport)];
  local num_tx, num_rx, num_dropped

  num_tx = statTx.opackets; -- + statRx.opackets;
  num_rx = statRx.ipackets; -- + statTx.ipackets;
  print("#TOTAL," .. num_tx .. "," .. num_rx);
  num_dropped = num_tx - num_rx;
  local loss = Round((1-(num_rx/num_tx))*100,3);
  Printf("tx: %d rx: %d  drop: %d %d%%", num_tx, num_rx, num_dropped, loss);
  if num_dropped <= loss_limit
  then
    Printf(" OK\n");
  else
    Printf(" NOK\n");
  end
end

function Main(input)
	Printf("Info: %s %s\n", pktgen.info.Pktgen_Version, pktgen.info.Lua_Version);
  local d = input["d"] or Duration
  local r = input["r"] or Rate
  local l = input["l"] or LossLimit
  local p = input["p"] or {512}
  local linkSpeed= string.match(pktgen.linkState(Sendport)[tonumber(Sendport)],"%d+");

  -- TODO: SetupTraffic(); made optional

  for _,size in pairs(p)
  do
    RunTrial(linkSpeed, size, r, d, l, WaitTime);
  end
end

Main(... or {});
