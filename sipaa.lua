sipsvrip=session:getVariable("network_addr")
sipsvrport=session:getVariable("sip_network_port")
ani = session:getVariable("caller_id_number")
dnis = session:getVariable("destination_number")


local dbh_cfg = freeswitch.Dbh("sqlite://C:/Program Files/FreeSWITCH/db/sipaacfg.db")
--local dbh_recs = freeswitch.Dbh("core:sipaarecs")

-- variables
this_call_is_valid = false
SipNumber = {server_id = 0, sip_number_id = 0, voice_type = 0, voice_id = 0, transfer_no = "", play_times = 0, timeout_action = 0, default_no = ""}
dial_rules = {}
userdefined_welcome_file = ""
-- variables end


local function select_sipnumber(row)
	for key, val in pairs(row) do
		freeswitch.consoleLog("INFO", "field name:"..key.."\n")
		this_call_is_valid = true
			if ( key == "ID" ) then
				SipNumber.server_id = val
			elseif ( key == "SipNumberID" ) then
				SipNumber.sip_number_id = val
			elseif ( key == "VoiceType" ) then
				SipNumber.voice_type = val
			elseif ( key == "VoiceID" ) then
				SipNumber.voice_id = val
				freeswitch.consoleLog("INFO", "voice_id:"..val.."\n")
			elseif ( key == "TransferNo" ) then
				SipNumber.transfer_no = val
				freeswitch.consoleLog("INFO", "transfer_no:"..val.."\n")
			elseif ( key == "PlayTimes" ) then
				SipNumber.play_times = val
			elseif ( key == "TimeoutAction" ) then
				SipNumber.timeout_action = val
			elseif ( key == "DefaultNo" ) then
				SipNumber.default_no = val
			end
	end
end

local function select_dialrules(row)
	local ruleobj = {key="", value=""}
	for key, val in pairs(row) do
		if ( key == "InputNo" ) then
			ruleobj.key = val
		elseif ( key == "RuleString" ) then
			ruleobj.value = val
		end
	end
	if ( ruleobj.key ~= "" and ruleobj.value ~= "" ) then
		table.insert(dial_rules, ruleobj)
	end
end

local function select_userdefined_welcome_filepath(row)
	for key, val in pairs(row) do
		userdefined_welcome_file = val
	end
end

local function this_incomming_call_is_valid(ip, sipno)
	local sql_query = string.format("SELECT SipServerInfo.ID, SipNumber.ID AS SipNumberID, SipNumber.VoiceType, SipNumber.VoiceID, SipNumber.TransferNo, SipNumber.PlayTimes, SipNumber.TimeoutAction, SipNumber.DefaultNo from SipServerInfo, SipNumber WHERE SipServerInfo.ID = SipNumber.ServerID AND SipServerInfo.ServerIP = \'%s\' AND SipNumber.SipNo = \'%s\' AND SipNumber.Enabled = 1", ip, sipno)
	dbh_cfg:query(sql_query, select_sipnumber)
	local logstr = string.format("ID:%d,  SipNumberID:%d,  VoiceType:%d,  VoiceID:%d,  TransferNo:%s,  PlayTimes:%d,  TimeoutAction:%d,  DefaultNo:%s", SipNumber.server_id, SipNumber.sip_number_id, SipNumber.voice_type, SipNumber.voice_id, SipNumber.transfer_no, SipNumber.play_times, SipNumber.timeout_action, SipNumber.default_no)
	freeswitch.consoleLog("INFO", logstr.."\n")
	return this_call_is_valid
end

local function get_dialrules_by_sipnumber(sipno)
	local sql_query = string.format("SELECT InputNo, RuleString from SipNumber, Dialrules WHERE SipNumber.ID = Dialrules.SipID AND SipNumber.SipNo = \'%s\'", sipno)
	dbh_cfg:query(sql_query, select_dialrules)
	for i,n in ipairs(dial_rules) do
		freeswitch.consoleLog("INFO", "SipNumber:" .. sipno .. "  key:" .. n.key .. ",    value:" .. n.value .. "\n")
	end
end

local function get_userdefined_welcome_file(sipno)
	local sql_query = string.format("SELECT VoicePath from SipNumber, SysVoice WHERE SipNumber.VoiceID = SysVoice.ID AND SipNumber.SipNo = \'%s\'", sipno)
	dbh_cfg:query(sql_query, select_userdefined_welcome_filepath)
	freeswitch.consoleLog("INFO", "SipNumber:" .. sipno .. ",  user defined welcome file:" .. userdefined_welcome_file .. "\n")
end

if ( this_incomming_call_is_valid(sipsvrip, dnis) == false ) then
	-- cannot find any records in SipNumber and SipServerInfo table, so hangup the call.
	freeswitch.consoleLog("INFO", "this incomming call is invalid\n")
	session:streamFile("gbestsmbl/gbestsmbl-bye.wav")
	session:streamFile("gbestsmbl/gbestsmbl-enter_callback.wav")
	session:hangup()
	return
else
	get_dialrules_by_sipnumber(dnis)
end


session:answer()
session:execute("playback", "gbestsmbl/gbestsmbl-bye.wav;loops=2")

repeat_times = 0
objectuuid = session:get_uuid()
user_entered_digits = ""
start_or_user_enter_time = os.time()
changed_to_phoneno = ""

function collect_digits_cb(session, type, data, arg)
	if type == "dtmf" then
		start_or_user_enter_time = os.time()
	user_entered_digits = user_entered_digits .. data["digit"]
    freeswitch.consoleLog("INFO", "Key pressed: " .. data["digit"] .. "    " .. user_entered_digits .. "\n")
	digits_len = string.len(user_entered_digits)

	for i,n in ipairs(dial_rules) do
		if ( n.key == user_entered_digits ) then
			changed_to_phoneno = n.value
			freeswitch.consoleLog("INFO", "found a math for user entered key:" .. user_entered_digits .. ".   key:" .. n.key .. ",  transfer no:" .. n.value .. "\n")
			return "break"
		end
	end
  end
	return "true"
end

while ( true ) do
	session:setInputCallback("collect_digits_cb", "")
	times = 0
	changed_to_phoneno = ""
	while ( times < 3 ) do
		user_entered_digits = ""
		start_or_user_enter_time = os.time()
		session:streamFile("gbestsmbl/gbestsmbl-enter_notifyed_phoneno.wav")
		freeswitch.consoleLog("INFO", "Got " .. user_entered_digits .. "\n")
		while ( ( string.len(user_entered_digits) == 0 and os.difftime(os.time(), start_or_user_enter_time) < 10 ) or ( string.len(user_entered_digits) > 0 and os.difftime(os.time(), start_or_user_enter_time) < 5 ) ) do
			if ( string.len(changed_to_phoneno) > 0 ) then
				break
			end
			session:sleep(50)
		end
		if ( string.len(changed_to_phoneno) > 0 ) then
			break
		end
		times = times + 1
	end
	if ( times >= 3 ) then
		session:streamFile("gbestsmbl/gbestsmbl-bye.wav")
		session:streamFile("gbestsmbl/gbestsmbl-enter_idnumber_welcome.wav")
		session:hangup()
		return
	end
	session:unsetInputCallback()

	changed_to_phoneno = "4001"
	dialB = "[origination_caller_id_number=" .. ani .. ",execute_on_answer=lua tsimplify.lua " .. objectuuid .. "]sofia/external/" .. changed_to_phoneno .. "@" .. sipsvrip .. ":" .. sipsvrport
	freeswitch.consoleLog("INFO","new session:" .. dialB .. "\n")

api = freeswitch.API()
local callstring = "bgapi uuid_hold "..objectuuid
freeswitch.consoleLog("notice", callstring.."\n")
api:executeString(callstring)
	
	legB = freeswitch.Session(dialB, session)
	--freeswitch.bridge(session, legB)
	--original version	legB = freeswitch.Session(dialB, session)
	freeswitch.consoleLog("INFO","after new session..\n")

	state=legB:getState()
	freeswitch.consoleLog("INFO","new session state:"..state.."\n")
	obCause=legB:hangupCause()
	freeswitch.consoleLog("INFO","new session state:"..state.."    hangup cause:"..obCause.."\n")

	if ( state == "ERROR" and obCause == "USER_BUSY" ) then
		session:streamFile("gbestsmbl/gbestsmbl-transferib_welcome.wav")
	elseif ( state == "ERROR" and ( obCause == "UNALLOCATED_NUMBER" or obCause == DESTINATION_OUT_OF_ORDER or obCause == FACILITY_REJECTED or obCause == NORMAL_CIRCUIT_CONGESTION or obCause == NETWORK_OUT_OF_ORDER or obCause == NORMAL_TEMPORARY_FAILURE or obCause == SWITCH_CONGESTION or obCause == REQUESTED_CHAN_UNAVAIL or obCause == BEARERCAPABILITY_NOTAVAIL or obCause == FACILITY_NOT_IMPLEMENTED or obCause == SERVICE_NOT_IMPLEMENTED or obCause == RECOVERY_ON_TIMER_EXPIRE ) ) then
		session:streamFile("gbestsmbl/gbestsmbl-bye.wav")
		session:streamFile("gbestsmbl/gbestsmbl-transferib_welcome.wav")
	elseif ( legB:ready() ) then
		return
	end

	repeat_times = repeat_times + 1
	if ( repeat_times >= 3 ) then
		session:hangup()
		return
	end
end		-- end of while
