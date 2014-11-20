local objectuuid=argv[1]

api = freeswitch.API();
local callstring = "bgapi uuid_simplify "..objectuuid
freeswitch.consoleLog("notice", callstring.."\n");
api:executeString(callstring);
