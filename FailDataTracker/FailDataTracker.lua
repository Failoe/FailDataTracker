-- File: FailDataTracker.lua
-- Name: Fail Data Tracker
-- Author: failoe
-- Description: Tracks various datapoints for vizualization
-- Version: 0.0.2

-- To Do:
-- Track progress by Zone
-- Display zone progress on map for that zone show subzone breakdowns in list
-- Graph of measure names by color over level axis

-- Output Schema
-- {
-- 	Event ID:int, -- [1]
-- 	Event Fired:string, -- [2]
-- 	Epoch Time:int, -- [3]
-- 	Player Level:int, -- [4]
-- 	Zone ID:int, -- [5]
-- 	{
-- 		X Coord:float, -- [1]
-- 		Y Coord:float, -- [2]
-- 	}, -- [6]
-- 	Event Specific Data:table, -- [7]
-- }

sessionEXP = 0
sessionKills = 0
sessionDeaths = 0
sessionSpiritRezzes = 0
sessionMoneyGained = 0
sessionMoneyLost = 0
currentMoney = 0

function secsToHMS(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
    return hours..":"..mins..":"..secs
  end
end

function getGlobalEventInfo(event)
	local y1, x1, _, instance1 = UnitPosition("player")
	-- print(EventID, event)
	return {EventID,event,time(),UnitLevel("player"),C_Map.GetBestMapForUnit("player"),{x1, y1}};
end

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
frame:RegisterEvent("CHAT_MSG_SKILL")
frame:RegisterEvent("CONFIRM_XP_LOSS")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("PLAYER_MONEY")


function frame:OnEvent(event, arg1)
	if event == "ADDON_LOADED" and arg1 == "FailDataTracker" then
		frame:UnregisterEvent("ADDON_LOADED")
		if EventLog == nil then
			print("Initializing Fail Data Tracker for character")
			EventID = 0;
			local lvl = UnitLevel("player");
			print("Initial Level: "..lvl);
			LevelUpTimes = {};
			LevelUpEpochTime = {};
			moneyGainedPerLevel = {};
			moneyLostPerLevel = {};
			killsPerLevel = {};
			deathsPerLevel = {};
			spiritRezzesPerLevel = {};
			questsPerLevel = {};
			
			for i=1,lvl do
				LevelUpTimes[i] = 0;
				LevelUpEpochTime[i] = time();
				LevelUpTimes[i] = 0;
				LevelUpEpochTime[i] = 0;
				moneyGainedPerLevel[i] = 0;
				moneyLostPerLevel[i] = 0;
				killsPerLevel[i] = 0;
				deathsPerLevel[i] = 0;
				spiritRezzesPerLevel[i] = 0;
				questsPerLevel[i] = 0;
			end

			totalKills = 0;
			totalDeaths = 0;
			totalSpiritRezzes = 0;
			popupOn = false;
			EventLog = {};
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		currentMoney = GetMoney();
	elseif (event == "CHAT_MSG_COMBAT_XP_GAIN") then
		EventID = EventID + 1;
		if (string.match(arg1, " dies, you gain ") ~= nil) then
			local exp = string.match(arg1, " dies, you gain (.*) experience.")
			exp = string.gsub(exp, ",", "")
			outstring = {string.match(arg1, "(.*) dies, you gain"), exp};
			totalKills = totalKills + 1
			killsPerLevel[UnitLevel("player")] = (killsPerLevel[UnitLevel("player")] or 0) + 1
			sessionKills = sessionKills + 1
			sessionEXP = sessionEXP + tonumber(outstring[2])
		elseif (string.match(arg1, "You gain (.*) experience.") ~= nil) then
			local exp = string.match(arg1, "You gain (.*) experience.")
			exp = string.gsub(exp, ",", "")
			outstring = {exp};
			questsPerLevel[UnitLevel("player")] = (questsPerLevel[UnitLevel("player")] or 0) + 1
			sessionEXP = sessionEXP + tonumber(outstring[1])
		else
			outstring = {arg1}
		end

		local outputTable = getGlobalEventInfo(event);
		outputTable[#outputTable+1] = outstring;
		EventLog[EventID] = outputTable;

	elseif (event == "PLAYER_LOGIN")
		or (event == "PLAYER_LOGOUT")
		or (event == "CHAT_MSG_SKILL")
		or (event == "PLAYER_PVP_KILLS_CHANGED") then
			EventID = EventID + 1;
			local outputTable = getGlobalEventInfo(event);
			outputTable[#outputTable+1] = arg1;
			EventLog[EventID] = outputTable;
	elseif (event == "PLAYER_LEVEL_UP") then
		EventID = EventID + 1;
		local outputTable = getGlobalEventInfo(event);
		outputTable[#outputTable+1] = arg1;
		EventLog[EventID] = outputTable;
		RequestTimePlayed()
		frame:RegisterEvent("TIME_PLAYED_MSG")
	elseif (event == "TIME_PLAYED_MSG") then
		frame:UnregisterEvent("TIME_PLAYED_MSG")
		LevelUpTimes[UnitLevel("player")] = arg1
		LevelUpEpochTime[UnitLevel("player")] = time()
		-- Output the previous level's time played upon levelup
		print("Level ".. UnitLevel("player")-1 .." completed in "..secsToHMS(LevelUpTimes[UnitLevel("player")] - LevelUpTimes[UnitLevel("player") - 1])..".")
		print("Real world time to gain level: "..secsToHMS(LevelUpEpochTime[UnitLevel("player")] - LevelUpEpochTime[UnitLevel("player") - 1])..".")
		if (moneyGainedPerLevel[UnitLevel("player")-1] or 0) ~= 0 then
			print("Gold Earned: "..(GetCoinText(math.abs((moneyGainedPerLevel[UnitLevel("player")-1] or 0)), " ")) or "None")
		else
			print("Gold Earned: None")
		end
		if (moneyLostPerLevel[UnitLevel("player")-1] or 0) ~= 0 then
			print("Gold Spent: "..(GetCoinText(math.abs((moneyLostPerLevel[UnitLevel("player")-1] or 0)), " ")) or "None");
		else
			print("Gold Spent: None")
		end
		if ((moneyGainedPerLevel[UnitLevel("player")-1] or 0) + (moneyLostPerLevel[UnitLevel("player")-1] or 0)) > 0 then
			minussymbol = "";
		else
			minussymbol = "-";
		end
		if ((moneyGainedPerLevel[UnitLevel("player")-1] or 0) + (moneyLostPerLevel[UnitLevel("player")-1] or 0)) ~= 0 then
			print("Net Money: "..minussymbol..(GetCoinText(math.abs(((moneyGainedPerLevel[UnitLevel("player")-1] or 0) + (moneyLostPerLevel[UnitLevel("player")-1] or 0))), " ")) or "None")
		else
			print("Net Money: None")
		end
		print("Kills: "..(killsPerLevel[UnitLevel("player")-1] or 0))
		print("Deaths: "..(deathsPerLevel[UnitLevel("player")-1] or 0))
		print("Spirit Rezzes: "..(spiritRezzesPerLevel[UnitLevel("player")-1] or 0))
		print("Quests: "..(questsPerLevel[UnitLevel("player")-1] or 0))

		if popupOn then
			popupMsg = "Level ".. UnitLevel("player")-1 .." completed in "..secsToHMS(LevelUpTimes[UnitLevel("player")] - LevelUpTimes[UnitLevel("player") - 1])..".";
			popupMsg = popupMsg.."\nReal world time to gain level: "..secsToHMS(LevelUpEpochTime[UnitLevel("player")] - LevelUpEpochTime[UnitLevel("player") - 1])..".";
			if (moneyGainedPerLevel[UnitLevel("player")-1] or 0) ~= 0 then
				popupMsg = popupMsg.."\nGold Earned: "..(GetCoinText(math.abs((moneyGainedPerLevel[UnitLevel("player")-1] or 0)), " ")) or "None";
			else
				popupMsg = popupMsg.."\nGold Earned: None";
			end
			if (moneyLostPerLevel[UnitLevel("player")-1] or 0) ~= 0 then
				popupMsg = popupMsg.."\nGold Spent: "..(GetCoinText(math.abs((moneyLostPerLevel[UnitLevel("player")-1] or 0)), " ")) or "None";
			else
				popupMsg = popupMsg.."\nGold Spent: None";
			end
			if ((moneyGainedPerLevel[UnitLevel("player")-1] or 0) + (moneyLostPerLevel[UnitLevel("player")-1] or 0)) > 0 then
				minussymbol = "";
			else
				minussymbol = "-";
			end
			if ((moneyGainedPerLevel[UnitLevel("player")-1] or 0) + (moneyLostPerLevel[UnitLevel("player")-1] or 0)) ~= 0 then
				popupMsg = popupMsg.."\nNet Money: "..minussymbol..GetCoinText(math.abs(((moneyGainedPerLevel[UnitLevel("player")-1] or 0) + (moneyLostPerLevel[UnitLevel("player")-1] or 0))), " ")
			else
				popupMsg = popupMsg.."\nNet Money: None"
			end
			popupMsg = popupMsg.."\nKills: "..(killsPerLevel[UnitLevel("player")-1] or 0)
			popupMsg = popupMsg.."\nDeaths: "..(deathsPerLevel[UnitLevel("player")-1] or 0)
			popupMsg = popupMsg.."\nSpirit Rezzes: "..(spiritRezzesPerLevel[UnitLevel("player")-1] or 0)
			popupMsg = popupMsg.."\nQuests: "..(questsPerLevel[UnitLevel("player")-1] or 0)
			StaticPopup_Show("LEVELUP_DATA_SHEET", popupMsg, "", d)
		end
	elseif (event == "CONFIRM_XP_LOSS") then
		-- This is a spirit rez being activated
		EventID = EventID + 1;
		local outputTable = getGlobalEventInfo(event);
		outputTable[#outputTable+1] = arg1;
		EventLog[EventID] = outputTable;
		sessionSpiritRezzes = sessionSpiritRezzes + 1
		spiritRezzesPerLevel[UnitLevel("player")] = (spiritRezzesPerLevel[UnitLevel("player")] or 0) + 1
		totalSpiritRezzes = totalSpiritRezzes + 1
	elseif (event == "PLAYER_DEAD") then
		EventID = EventID + 1;
		local outputTable = getGlobalEventInfo(event);
		outputTable[#outputTable+1] = arg1;
		EventLog[EventID] = outputTable;
		totalDeaths = totalDeaths + 1
		deathsPerLevel[UnitLevel("player")] = (deathsPerLevel[UnitLevel("player")] or 0) + 1
		sessionDeaths = sessionDeaths + 1
	elseif (event == "PLAYER_MONEY") then
		EventID = EventID + 1;
		local outputTable = getGlobalEventInfo(event);
		newMoney = GetMoney();
		moneyDiff = newMoney - currentMoney;
		outputTable[#outputTable+1] = moneyDiff;
		print("moneyDiff "..moneyDiff);
		print("newMoney "..newMoney);
		currentMoney = newMoney;
		EventLog[EventID] = outputTable;
		if moneyDiff > 0 then
			moneyGainedPerLevel[UnitLevel("player")] = (moneyGainedPerLevel[UnitLevel("player")] or 0) + moneyDiff
			sessionMoneyGained = sessionMoneyGained + moneyDiff
		elseif moneyDiff < 0 then
			moneyLostPerLevel[UnitLevel("player")] = (moneyLostPerLevel[UnitLevel("player")] or 0) + moneyDiff
			sessionMoneyLost = sessionMoneyLost + moneyDiff
		end
	elseif (event == "ZONE_CHANGED") then
		EventID = EventID + 1;
		local outputTable = getGlobalEventInfo(event);
		outputTable[#outputTable+1] = {GetRealZoneText(), GetSubZoneText()};
		EventLog[EventID] = outputTable;
	end
end


frame:SetScript("OnEvent", frame.OnEvent);

StaticPopupDialogs["LEVELUP_DATA_SHEET"] = {
    text = "%s",
    button1 = "Close",
    OnAccept = function()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    cancels = "LEVELUP_DATA_SHEET"
}

SLASH_FAILDATATRACKER1 = "/fdt";
SLASH_FAILDATATRACKER2 = "/faildatatracker";
SLASH_FAILDATATRACKER3 = "/FDT";
SLASH_FAILDATATRACKER4 = "/FAILDATATRACKER";

function SlashCmdList.FAILDATATRACKER(msg)
	msg = strlower(msg);
	if msg == "popup on" then
		popupOn = true;
		print("FDT Level Up Window Activated")
	elseif msg == "popup off" then
		popupOn = false;
		print("FDT Level Up Window Deactivated")
	else
		print("Fail Data Tracker has logged " .. EventID .. " events.");
		print("/fdt popup on|off - toggle the popup on level up.")
		print("/failstatsheet commands:")
		print("/fss - to display stats for the current session.");
		print("/fss total - to display total stats.");
		print("/fss <##> - to display stats for level ##.");
	end
end

SLASH_FAILSTATSHEET1 = "/fss";
SLASH_FAILSTATSHEET2 = "/failstatsheet";
SLASH_FAILSTATSHEET3 = "/FSS";
SLASH_FAILSTATSHEET4 = "/FAILSTATSHEET";

function SlashCmdList.FAILSTATSHEET(msg)
	msg = strlower(msg);
	-- Generate our output message
	if msg == "total" then
		outMsg = "Fail Total Stat Sheet";
		outMsg = outMsg .. "\nKills "..(totalKills or 0);
		outMsg = outMsg .. "\nDeaths "..(totalDeaths or 0);
		outMsg = outMsg .. "\nDeaths "..(totalSpiritRezzes or 0);
	elseif (tonumber(msg) ~= nil) then
		lvlInput = tonumber(msg);
		if tonumber(msg)< #LevelUpTimes then
			outMsg = "Fail Stat Sheet for Level "..lvlInput;
		else
			lvlInput = #LevelUpTimes;
			outMsg = "Fail Stat Sheet for the Current Level ("..lvlInput..")";
		end
		outMsg = outMsg .. ("\nKills: "..(killsPerLevel[lvlInput] or 0))
		outMsg = outMsg .. ("\nDeaths: "..(deathsPerLevel[lvlInput] or 0))
		outMsg = outMsg .. ("\nSpirit Rezzes: "..(spiritRezzesPerLevel[lvlInput] or 0))
		outMsg = outMsg .. ("\nQuests: "..(questsPerLevel[lvlInput] or 0))
		if (moneyGainedPerLevel[lvlInput] or 0) ~= 0 then
			outMsg = outMsg .. ("\nGold Earned: "..(GetCoinText(math.abs((moneyGainedPerLevel[lvlInput] or 0)), " ")) or "None")
		else
			outMsg = outMsg .. ("\nGold Earned: None")
		end
		if (moneyLostPerLevel[lvlInput] or 0) ~= 0 then
			outMsg = outMsg .. ("\nGold Spent: "..(GetCoinText(math.abs((moneyLostPerLevel[lvlInput] or 0)), " ")) or "None")
		else
			outMsg = outMsg .. ("\nGold Spent: None")
		end
		if ((moneyGainedPerLevel[lvlInput] or 0) + (moneyLostPerLevel[lvlInput] or 0)) > 0 then
			minussymbol = "";
		else
			minussymbol = "-";
		end
		if ((moneyGainedPerLevel[lvlInput] or 0) + (moneyLostPerLevel[lvlInput] or 0)) ~= 0 then
			outMsg = outMsg .. ("\nNet Gold: "..minussymbol..(GetCoinText(math.abs(((moneyGainedPerLevel[lvlInput] or 0) + (moneyLostPerLevel[lvlInput-1] or 0))), " ")) or "None")
		else
			outMsg = outMsg .. ("\nNet Gold: None")
		end
	else
		outMsg = "Fail Stat Sheet for this Session";
		outMsg = outMsg .. "\nSession EXP Gained "..sessionEXP;
		outMsg = outMsg .. "\nKey = This Session (Totals) [% of Total]";
		if totalKills > 0 then
			outMsg = outMsg .. "\nKills "..sessionKills.." ("..totalKills..") ["..round((sessionKills/totalKills*100), 2).."%]";
		end
		if totalDeaths > 0 then
			outMsg = outMsg .. "\nDeaths "..sessionDeaths.. " ("..totalDeaths..") ["..round((sessionDeaths/totalDeaths*100), 2).."%]";
		end
		if totalSpiritRezzes > 0 then
			outMsg = outMsg .. "\nDeaths "..sessionSpiritRezzes.. " ("..totalSpiritRezzes..") ["..round((sessionSpiritRezzes/totalSpiritRezzes*100), 2).."%]";
		end
		if sessionMoneyGained > 0 then
			outMsg = outMsg .. "\nGold Gained "..GetCoinText(math.abs(sessionMoneyGained));
		end
		if math.abs(sessionMoneyLost) > 0 then
			outMsg = outMsg .. "\nGold Lost "..GetCoinText(math.abs(sessionMoneyLost));
		end
		if sessionMoneyGained ~= 0 and sessionMoneyLost ~= 0 then
			outMsg = outMsg .. "\nNet Gold "
			if sessionMoneyGained + sessionMoneyLost < 0 then
				outMsg = outMsg .. "-"
			end
			outMsg = outMsg..GetCoinText(math.abs(sessionMoneyGained + sessionMoneyLost));
		end
	end
	StaticPopup_Show("LEVELUP_DATA_SHEET", outMsg, "", d)
end
