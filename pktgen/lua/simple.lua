require "Pktgen";

Sendport      = "0";
Recvport      = "1";
local output

Log = function(s)
    print(s)
    output:write(s.."\n");
end


function Round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
end

function Stats(input )
  local duration = input["duration"] or 0
  if input~=nil and input["title"]~=nil then
    Log(input["title"] or "")
  end
  if input~=nil and input["header"] then
    Log("TS(sec),TX(pps),RX(pps),totalTX(p),totalRX(p),Trial");
  end

  local Start, End
  local start_time = os.time()
  local ltxB,rrxB;

  while os.difftime(os.time(), start_time) < duration do
    -- TODO: end when tx is zero, save the timestamp, sleep 3 more and return
    if ( pktgen.isSending(Sendport)[tonumber(Sendport)] == "y" ) then
           Start = Start or os.time()
    else
           End = End or os.time()
    end

    local ltxA = pktgen.portStats(Sendport, "port")[tonumber(Sendport)].opackets;
    local rrxA = pktgen.portStats(Recvport, "port")[tonumber(Recvport)].ipackets;
    pktgen.delay(1000);
    ltxB = pktgen.portStats(Sendport, "port")[tonumber(Sendport)].opackets;
    rrxB = pktgen.portStats(Recvport, "port")[tonumber(Recvport)].ipackets;
    local s=string.format("%d,%d,%d,%d,%d,%d",os.time(),
       ltxB-ltxA, rrxB-rrxA, ltxB, rrxB,input["run"] or 0);
    Log(s)
   end
   return  os.difftime(End or os.time(), Start or os.time())
end



function RunTrial(speed, size, rate, duration,loss_tol, times)

  local mpps = Round((speed * 10^6)*(rate/100)/((size + 20) * 8));
  -- TODO: dump to check the actual size, what is  +20 bytes
  local count = Round(mpps*(duration/1000));
  local loss_limit = Round(count*(loss_tol/100));

  local fmt = "size: %dB, rate: %d%%, link: %d Mbps, mpps: %d, dur: %d sec, total: %d, LossLimit: %d (%2.3f%%)"
  local s=string.format(fmt,size,rate,speed, mpps, duration/1000, count,loss_limit, loss_tol or 0.0 )
  printf("%s\n",s)
  Stats({duration =0, title = s, header = true});
  local function f ( n )
    pktgen.clr();
    pktgen.set("0", "rate", rate);
    pktgen.set("0", "size", size);
    pktgen.set("0", "count", count );
    Stats({duration=1,run = n});
    if size > 0 then pktgen.start(0) end
    local ret = Stats({ duration = duration/1000+5, run  = n});
    -- TODO: we stay more but the stop happens because we send specific number of packets
    pktgen.stop(0);

    local statTx = pktgen.portStats(Sendport, "port")[tonumber(Sendport)];
    local statRx = pktgen.portStats(Recvport, "port")[tonumber(Recvport)];
    local num_tx, num_rx

    num_tx = statTx.opackets; -- + statRx.opackets;
    num_rx = statRx.ipackets; -- + statTx.ipackets;
    printf("#["..n.."] tx:" .. num_tx .. ", rx:" .. num_rx .. ", drop:" .. num_tx -num_rx .. ",dur:".. ret);
    if (num_tx - num_rx) > loss_limit or num_tx < count
    then
      printf(" NOK\n");
    else
      printf(" OK\n");
    end
    if n < times-1 then
      return  f( n + 1 )
    end
  end

  f(0)
end

function SetupTraffic()
  pktgen.reset("all");
  pktgen.capture('0', 'enable');

  pktgen.set("all", "count", 0);
  pktgen.set("all", "rate", 10);
  pktgen.set("all", "size", 64);
  pktgen.set_proto("all", "udp");

  pktgen.set_mac("0", "src", "10:00:00:00:00:12");
  pktgen.set_mac("0", "dst", "20:00:00:00:00:13");
  pktgen.set_ipaddr("0", "src", "16.1.1.1"); -- set 0 src ip 16.1.1.1/24
  pktgen.set("0", "sport", 400);
  pktgen.set_ipaddr("0", "dst", "16.2.2.2/24"); -- set 0 dst ip 16.2.2.2
  pktgen.set("0", "dport", 2222); -- set 0 dport 2222

  pktgen.set_mac("1", "src", "20:00:00:00:00:13"); -- set 1 src mac 20:00:00:00:00:13
  pktgen.set_mac("1", "dst", "10:00:00:00:00:12"); --set 1 dst mac 10:00:00:00:00:12
  pktgen.set_ipaddr("1", "src", "16.2.2.2");
  pktgen.set("1", "sport", 500);
  pktgen.set_ipaddr("1", "dst", "16.1.1.1/24");
  pktgen.set("1", "dport", 555);
end

function Main(input)

  local linkSpeed= input["s"] or string.match(pktgen.linkState(Sendport)[tonumber(Sendport)],"%d+");
  local d = input["d"] or 30000; -- Duration
  local r = input["r"] or 95; -- Rate
  local l = input["l"] or 0.001; -- LossLimit
  local p = input["p"] or { 64, 128, 256, 512, 1024, 1280, 1518};
  local t = input["t"] or 3; -- times
  local setup = input["setup"] or SetupTraffic;
  local title = input["f"] or string.format("r%d_d%d_t%d_%s",r,d,t,table.concat(p, "_"))
  local path = os.getenv("RESULTSDIR") or "/tmp/"
  local filepath = path .. "pktgen_"..title..".csv"
  printf("Info: %s %s %s %s\n",
        pktgen.info.Pktgen_Version, pktgen.info.DPDK_Version,pktgen.info.Lua_Version, filepath);
  output = assert(io.open(filepath, "w"))

  setup()

  Stats({duration= 0, title = "#T " .. title});
  for _,size in pairs(p)
  do
    RunTrial(linkSpeed, size, r, d, l, t);
    Stats({duration= d/1000});
  end

  output:close();

end

--I={d=20000,r=100, t=1, p={0,64,128}}
I={}
-- TODO: zero size for idle time
-- TODO: jumbo frames is broken?!

Main(... or I);

