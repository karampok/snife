require "Pktgen"


pktgen.screen("off");

-- A list of the test script for Pktgen and Lua.
-- Each command somewhat mirrors the pktgen command line versions.
-- A couple of the arguments have be changed to be more like the others.
--
function Info()
	Printf("Lua Version      : %s\n", pktgen.info.Lua_Version);

	Printf("Pktgen Version   : %s\n",
		pktgen.info.Pktgen_Version);
	Printf("Pktgen Copyright : %s\n",
		pktgen.info.Pktgen_Copyright);

	prints("pktgen.info",
		pktgen.info);

	Printf("Port Count %d\n",
		pktgen.portCount());
	Printf("Total port Count %d\n",
		pktgen.totalPorts());
end

Info()
