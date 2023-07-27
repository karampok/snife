require "Pktgen"

local function doWait(port, waitTime)
   pktgen.delay(1000);
   if ( waitTime == 0 ) then
       return;
   end
   waitTime = waitTime - 1;
-- local send_for_secs = 10;
-- local start_time = os.time();
-- while os.difftime(os.time(), start_time) < send_for_secs do
--     sleep(1);
-- end
    -- Try to wait for the total number of packets to be sent.
    local idx = 0;
    while( idx < waitTime ) do

        idx = idx + 1;

        local sending = pktgen.isSending(port);
        if ( sending[tonumber(port)] == "n" ) then
            break;
        end
        pktgen.delay(1000);
    end

end


local function whileStats(output, duration, interval)
    print("TS(sec),LRX(pps),RRX(pps),LTX(pps),RTX(pps)");
    output:write("TS(sec),LRX(pps),RRX(pps),LTX(pps),RTX(pps)\n");
    local start_time = os.time();
    while os.difftime(os.time(), start_time) < duration do
      local ltxA = pktgen.portStats(0, "port")[0].opackets;
      local lrxA = pktgen.portStats(0, "port")[0].ipackets;
      local rtxA = pktgen.portStats(1, "port")[1].opackets;
      local rrxA = pktgen.portStats(1, "port")[1].ipackets;
      sleep(interval);
      local ltxB = pktgen.portStats(0, "port")[0].opackets;
      local lrxB = pktgen.portStats(0, "port")[0].ipackets;
      local rtxB = pktgen.portStats(1, "port")[1].opackets;
      local rrxB = pktgen.portStats(1, "port")[1].ipackets;

      print(os.time() .. "," .. ltxB-ltxA .. ",0," .. rrxB-rrxA ..",0");
      output:write(os.time() .. "," .. ltxB-ltxA .. ",".. lrxB-lrxA .."," .. rtxB-rtxA ..","..rrxB-rrxA .."\n");
    end

end

pktgen.reset("all");

pktgen.set("all", "count", 0);
pktgen.set("all", "rate", 10);
pktgen.set("all", "size", 64);
pktgen.set_proto("all", "udp");

pktgen.set_mac("0", "src", "10:00:00:00:00:12");
pktgen.set_mac("0", "dst", "10:00:00:00:00:10");
pktgen.set_ipaddr("0", "src", "16.1.1.1");
pktgen.set("0", "sport", 400);
pktgen.set_ipaddr("0", "dst", "16.2.2.2/24");
pktgen.set("0", "dport", 444);

pktgen.set_mac("1", "src", "20:00:00:00:00:13");
pktgen.set_mac("1", "dst", "20:00:00:00:00:11");
pktgen.set_ipaddr("1", "src", "16.2.2.2");
pktgen.set("1", "sport", 500);
pktgen.set_ipaddr("1", "dst", "16.1.1.1/24");
pktgen.set("1", "dport", 555);


local fileName = os.getenv("RESULTSFILE") or "pktgen.csv"
local file = io.open(fileName, "w")
if not file then
  print("Failed to open the file for writing.")
  os.exit(1)  -- Exit the program with a non-zero status code
end


-- TODO: signaling
-- local signal = require("posix.signal")
--
-- signal.signal(signal.SIGINT, function(signum)
--   io.write("\n")
--   -- put code to save some stuff here
--   os.exit(128 + signum)
-- end)


pktgen.clr();
print("[  INFO ] Starting Test...");
pktgen.start(0);
pktgen.delay(1000);
whileStats(file,20,10)
pktgen.delay(1000);
--doWait(port,10)
file:close()
pktgen.stop(0);
-- local statTx = pktgen.portStats(0, "port")[tonumber(0)];
-- local statRx = pktgen.portStats(1, "port")[tonumber(1)];
-- local num_tx = statTx.opackets;
-- local num_rx = statRx.ipackets;
-- local num_dropped = num_tx - num_rx;
-- print("[  INFO ]Tx - Rx: " .. num_tx .. " - " .. num_rx .. " = " .. num_dropped);
print("[  INFO ] Stopping Test...");
