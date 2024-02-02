require "Pktgen";

Sendport      = "0";
Recvport      = "1";
local output

Log = function(s)
    print(s)
    output:write(s.."\n")
    io.write(s.."\n"); io.flush()
end

function Round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
end

function Stats(input)
  local duration = input["duration"] or 0
  if input~=nil and input["header"] then
    Log("# TS(sec),TX(pps),RX(pps),totalTX(p),totalRX(p),Trial,Drops");
  end

  local Start, End
  local start_time = os.time()
  local ltxB,rrxB;

  while os.difftime(os.time(), start_time) < duration do
    if ( pktgen.isSending(Sendport)[tonumber(Sendport)] == "y" ) then
           Start = Start or os.time()
    else
           End = End or os.time()
    end

    local ltxA = pktgen.portStats(Sendport, "port")[tonumber(Sendport)].opackets;
    local rrxA = pktgen.portStats(Recvport, "port")[tonumber(Recvport)].ipackets;
    sleep(1)
    ltxB = pktgen.portStats(Sendport, "port")[tonumber(Sendport)].opackets;
    rrxB = pktgen.portStats(Recvport, "port")[tonumber(Recvport)].ipackets;
    local s=string.format("%d,%d,%d,%d,%d,%d,%d",os.time(),
       ltxB-ltxA, rrxB-rrxA, ltxB, rrxB, input["run"] or 0, (ltxB-ltxA) - (rrxB-rrxA));
    Log(s)
   end
   return  os.difftime(End or os.time(), Start or os.time())
end



function RunTrial(speed, size, rate, duration,loss_tol, times)

  local mpps = Round((speed * 10^6)*(rate/100)/((size + 20) * 8));
  if size == 0 then mpps = 0 end
  -- TODO: dump to check the actual size, what is +20 bytes
  local count = Round(mpps*(duration/1000));
  local loss_limit = Round(count*(loss_tol/100));

  local fmt = "# size: %dB, rate: %d%%, link: %d Mbps, mpps: %d, dur: %d sec, total: %d, LossLimit: %d, ts: %d"
  local s=string.format(fmt,size,rate,speed, mpps, duration/1000, count,loss_limit, os.time())
  Log(s)
  local function f ( n )
    Stats({duration =0, header = true});
    pktgen.clr();
    pktgen.set("0", "rate", rate);
    pktgen.set("0", "size", size);
    pktgen.set("0", "count", count );
    Stats({duration=1,run = n});
    if size > 0 then pktgen.start(0) end
    local ret = Stats({ duration = duration/1000+5, run = n});
    -- TODO: we stay more but the stop happens because we send specific number of packets
    pktgen.stop(0);

    local statTx = pktgen.portStats(Sendport, "port")[tonumber(Sendport)];
    local statRx = pktgen.portStats(Recvport, "port")[tonumber(Recvport)];
    local num_tx, num_rx

    num_tx = statTx.opackets; -- + statRx.opackets;
    num_rx = statRx.ipackets; -- + statTx.ipackets;
    Log("#["..n.."] tx:" .. num_tx .. ", rx:" .. num_rx .. ", drop:" .. num_tx -num_rx .. ",dur:".. ret);
    if (num_tx - num_rx) > loss_limit or num_tx < count
    then
      Log("# NOK\n");
    else
      Log("# OK\n");
    end
    if n < times-1 then
      return  f( n + 1 )
    end
  end

  f(1)
end

function SetupTraffic()
  pktgen.reset("all");
  pktgen.capture('0', 'enable');

  pktgen.set("all", "count", 0);
  pktgen.set("all", "rate", 10);
  pktgen.set("all", "size", 64);
  pktgen.set_proto("all", "udp");

  pktgen.set_mac("0", "src", "10:00:00:00:00:12");
  pktgen.set_mac("0", "dst", "10:00:00:00:00:10");
  pktgen.set_ipaddr("0", "src", "16.1.1.1"); -- set 0 src ip 16.1.1.1/24
  pktgen.set("0", "sport", 400);
  pktgen.set_ipaddr("0", "dst", "16.2.2.2/24"); -- set 0 dst ip 16.2.2.2
  pktgen.set("0", "dport", 2222); -- set 0 dport 2222

  pktgen.set_mac("1", "src", "20:00:00:00:00:13"); -- set 1 src mac 20:00:00:00:00:13
  pktgen.set_mac("1", "dst", "20:00:00:00:00:11"); 
  pktgen.set_ipaddr("1", "src", "16.2.2.2");
  pktgen.set("1", "sport", 500);
  pktgen.set_ipaddr("1", "dst", "16.1.1.1/24");
  pktgen.set("1", "dport", 555);
end

function Main(input)

  local linkSpeed= input["s"] or string.match(pktgen.linkState(Sendport)[tonumber(Sendport)],"%d+");
  local d = input["d"] or 30000; -- Duration msec
  local r = input["r"] or 20; -- Rate %
  local l = input["l"] or 0.1; -- LossLimit
  local p = input["p"] or { 0, 64, 128, 256, 512, 1024, 1280, 1518};
  local t = input["t"] or 1; -- times
  local setup = input["setup"] or SetupTraffic;
  local title = input["f"] or string.format("l%f_r%d_d%d_t%d_%s",l,r,d,t,table.concat(p, "_"))
  local path = os.getenv("RESULTSDIR") or "/tmp/"
  local filepath = path .. "pktgen_"..title..".csv"
  output = assert(io.open(filepath, "w"))
  local s=string.format("# Info: %s %s %s %s",
        pktgen.info.Pktgen_Version, pktgen.info.DPDK_Version,pktgen.info.Lua_Version, filepath);
  Log(title)
  Log(s)

  setup()
  --prints("portInfo", pktgen.portInfo("all")[0].info)--l2_l3_info);
  --prints("portInfo", pktgen.portInfo("all")[1].info) --.l2_l3_info);

  for _,size in pairs(p)
  do
    RunTrial(linkSpeed, size, r, d, l, t);
  end

  Log(string.format("# Result %s", filepath))
  output:close();
end

I={d=30000,r=50, t=1, p={ 256, 512}} -- TODO: jumbo frames is broken?!
Main(... or I);
