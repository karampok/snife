require "Pktgen";

local sendport      = "0";
local recvport      = "1";

function Round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
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
  Printf("%s %s %s %s\n", "tx", "rx", "drop", "loss");
  Printf("%d %d %d %d%%\n", num_tx, num_rx, num_dropped, loss);
  if num_dropped <= loss_limit
  then
    Printf("[OK ]\n");
  else
    Printf("[NOK]\n");
  end
end

Duration = 30000;
WaitTime = 5000;
LossLimit = 0.001;
Rate = 100

function Main(input)
	Printf("Pktgen Version   : %s\n", pktgen.info.Pktgen_Version);
  local d = input["d"] or Duration
  local r = input["r"] or Rate
  local l = input["l"] or LossLimit
  local p = input["p"] or {512}
  local linkSpeed= string.match(pktgen.linkState(sendport)[tonumber(sendport)],"%d+");

  -- TODO: SetupTraffic(); made optional
  for _,size in pairs(p)
  do
    RunTrial(linkSpeed, size, r, d, l, WaitTime);
  end
end

Main(... or {});
