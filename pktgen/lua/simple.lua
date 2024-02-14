require "Pktgen"

function SetupTraffic(n,d,r)
  pktgen.set_proto("all", "udp")

  pktgen.set("0", "count", n)
  pktgen.set("0", "dport", 2222)
  pktgen.set("0", "rate", r)
  pktgen.set("0", "size", d)
  pktgen.set("0", "sport", 400)
  pktgen.set_ipaddr("0", "dst", "16.2.2.2/24")
  pktgen.set_ipaddr("0", "src", "16.1.1.1")
  -- pktgen.set_mac("0", "src", "10:00:00:00:00:12")
  -- pktgen.set_mac("0", "dst", "10:00:00:00:00:10")


  pktgen.set("1", "count", 10)
  pktgen.set("1", "dport", 555)
  pktgen.set("1", "rate", 1)
  pktgen.set("1", "size", 256)
  pktgen.set("1", "sport", 500)
  pktgen.set_ipaddr("1", "dst", "16.1.1.1/24")
  pktgen.set_ipaddr("1", "src", "16.2.2.2")
  -- pktgen.set_mac("1", "src", "20:00:00:00:00:13")
  -- pktgen.set_mac("1", "dst", "20:00:00:00:00:11")
end


function Main()

  local pnumber = 100000
  local psize = 1024
  local rate =  1

--  pktgen.reset("all")
  SetupTraffic(pnumber, psize, rate)
  printf("# to transmit " .. pnumber .. " packets with packetSize " .. psize .. "B at rate " .. rate .. "%%\n" )

  pktgen.clr()
  pktgen.start(1)
  pktgen.start(0)

  while ( pktgen.isSending("0")[0] == "y" ) do sleep(1) end
  sleep(10)

  pktgen.stop(1)
  pktgen.stop(0)

  local statTx = pktgen.portStats("all", "port")[0]
  local statRx = pktgen.portStats("all", "port")[1]
  local num_tx, num_rx
  num_tx = statTx.opackets; -- + statRx.opackets
  num_rx = statRx.ipackets; -- + statTx.ipackets
  printf("#tx:" .. num_tx .. ", rx:" .. num_rx .. ", drop:" .. num_tx -num_rx .. "\n")

end

Main()
