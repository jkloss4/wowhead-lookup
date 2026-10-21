-- Wowhead Lookup: a key (Key Bindings > AddOns) or /wiki makes a Wowhead link for what you're hovering, a chat link or
-- a search term, and shows it in a box to copy. Addons can't open a browser, so the link is copied with Ctrl+C.

local isClassic = select(4, GetBuildInfo()) < 20000
-- WoW: Forever's items, spells and quests are the classic ones
local BASE_URL = isClassic and "https://www.wowhead.com/classic/" or "https://www.wowhead.com/"

local DIALOG = "WOWHEAD_LOOKUP_LINK"

-- Retail hides some values from addons (unit GUIDs in instances...); reading them as normal values errors.
local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value)
end

local function say(text)
	print("|cffffd100Wowhead Lookup:|r " .. text)
end

local function encode(text)
	return (text:gsub("[^%w%-%._~ ]", function(c)
		return string.format("%%%02X", c:byte())
	end):gsub(" ", "+"))
end

local function pageURL(kind, id)
	return BASE_URL .. kind .. "=" .. id
end

local function searchURL(term)
	return BASE_URL .. "search?q=" .. encode(term)
end

-- Creature-0-1-2-3-<npcID>-<spawn>; Vehicle the same; GameObject-0-1-2-3-<objectID>-<spawn>
local function urlForGUID(guid)
	if not guid or isSecret(guid) then return end
	local unitType, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	if unitType == "Creature" or unitType == "Vehicle" then
		return pageURL("npc", id)
	elseif unitType == "GameObject" then
		return pageURL("object", id)
	end
end

-- An NPC by its ID; where retail hides the ID (dungeons and raids), by its name. Players aren't linked.
local function unitURL(unit, name)
	if not (unit and UnitExists(unit)) then return end
	local url = urlForGUID(UnitGUID(unit))
	if url then return url, name end
	local isPlayer = UnitIsPlayer(unit)
	if isSecret(isPlayer) or isPlayer then return end
	name = name or UnitName(unit)
	if name and not isSecret(name) and name ~= "" then
		return searchURL(name), name
	end
end

local function mountURL(mountID)
	local _, spellID = C_MountJournal.GetMountInfoByID(mountID)
	return spellID and pageURL("spell", spellID)
end

-- Tooltip data types (Enum.TooltipDataType names) and their Wowhead pages.
local TOOLTIP_PAGES = {
	Item = "item", Toy = "item",
	Spell = "spell", UnitAura = "spell",
	Quest = "quest",
	Achievement = "achievement",
	Currency = "currency",
}

local tooltipTypeNames = {}
for name, value in pairs(Enum.TooltipDataType or {}) do
	tooltipTypeNames[value] = name
end

local function tooltipTitle(tooltip, data)
	local line = data and data.lines and data.lines[1]
	local text = line and line.leftText
	if not text then
		local region = tooltip:GetName() and _G[tooltip:GetName() .. "TextLeft1"]
		text = region and region:GetText()
	end
	if text and not isSecret(text) and text ~= "" then
		return text
	end
end

local function urlForTooltip(tooltip)
	if not (tooltip and tooltip:IsShown() and tooltip.GetPrimaryTooltipData) then return end
	local data = tooltip:GetPrimaryTooltipData()
	if not data then return end

	local title = tooltipTitle(tooltip, data)
	local kind = tooltipTypeNames[data.type]
	local id = data.id
	if isSecret(id) then id = nil end

	if kind == "Unit" then
		local _, unit = tooltip:GetUnit()
		if unit and not isSecret(unit) then
			return unitURL(unit, title)
		end
	end

	local url
	if TOOLTIP_PAGES[kind] and id then
		url = pageURL(TOOLTIP_PAGES[kind], id)
	elseif kind == "Mount" and id then
		url = mountURL(id)
	elseif data.guid then
		url = urlForGUID(data.guid)
	end
	-- anything else with a name (pets, battle pets, players' gear sets...) is looked up by name
	if not url and title and kind ~= "Unit" then
		url = searchURL(title)
	end
	return url, title
end

-- Quest log entries, map pins and the objective tracker don't put the quest (or achievement) in their tooltip, but
-- the hovered frame or one of its parents knows it.
local TRACKER_PAGES = {
	QuestObjectiveTracker = "quest",
	CampaignQuestObjectiveTracker = "quest",
	WorldQuestObjectiveTracker = "quest",
	BonusObjectiveTracker = "quest",
	AchievementObjectiveTracker = "achievement",
}

local function readNumber(frame, key)
	local value = frame[key]
	if type(value) == "number" and not isSecret(value) then
		return value
	end
end

local function questURL(questID)
	return pageURL("quest", questID), C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
end

local function achievementURL(achievementID)
	return pageURL("achievement", achievementID), select(2, GetAchievementInfo(achievementID))
end

-- In the Achievements window every achievement (list, summary, meta criteria) keeps its ID in .id; so do the
-- category and statistic buttons, with other IDs.
local function isAchievementButton(frame)
	if not (AchievementFrame and AchievementFrame:IsShown()) then return end
	if (AchievementCategoryTemplateButtonMixin and frame.OnEnter == AchievementCategoryTemplateButtonMixin.OnEnter)
		or (AchievementStatTemplateMixin and frame.OnEnter == AchievementStatTemplateMixin.OnEnter) then
		return
	end
	local parent = frame:GetParent()
	while parent do
		if parent == AchievementFrame then return true end
		parent = parent:GetParent()
	end
end

local function urlForFrame(frame)
	for _ = 1, 8 do
		if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
		local questID = readNumber(frame, "questID")
		if questID and questID > 0 then
			return questURL(questID)
		end
		local id = readNumber(frame, "id")
		local module = rawget(frame, "parentModule")
		if id and module then
			for name, kind in pairs(TRACKER_PAGES) do
				if _G[name] == module then
					if kind == "quest" then
						return questURL(id)
					end
					return achievementURL(id)
				end
			end
		end
		if id and isAchievementButton(frame) and GetAchievementInfo(id) then
			return achievementURL(id)
		end
		frame = frame:GetParent()
	end
end

local function hoveredFrame()
	if GetMouseFoci then
		return GetMouseFoci()[1]
	end
	return GetMouseFocus and GetMouseFocus()
end

local function urlForHovered()
	-- the tooltip under the mouse, what's under the mouse, then a chat link opened by clicking it
	local url, title = urlForTooltip(GameTooltip)
	if url then return url, title end
	url, title = urlForFrame(hoveredFrame())
	if url then return url, title end
	url, title = urlForTooltip(ItemRefTooltip)
	if url then return url, title end
	return unitURL("mouseover")
end

-- Chat link types and their Wowhead pages; |Hitem:19019:...|h[Thunderfury...]|h
local LINK_PAGES = {
	item = "item", keystone = "item",
	spell = "spell", enchant = "spell",
	quest = "quest",
	achievement = "achievement",
	currency = "currency",
}

local function urlForText(text)
	local linkType, payload, name = text:match("|H(%a+):([^|]*)|h(.-)|h")
	if linkType then
		name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%[?(.-)%]?$")
		local id = payload:match("^(%d+)")
		if LINK_PAGES[linkType] and id then
			return pageURL(LINK_PAGES[linkType], id), name
		elseif linkType == "unit" then
			local url = urlForGUID(payload:match("^([^:]+)"))
			if url then return url, name end
		end
		if name ~= "" then
			return searchURL(name), name
		end
	end
	-- a search term: drop any color codes and textures pasted with it
	local term = strtrim((text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")))
	if term ~= "" then
		return searchURL(term), term
	end
end

-- The link box: Blizzard's popup with the link selected, closed by Ctrl+C (copied), Enter or Escape.
local shownEditBox
local hookedEditBoxes = {}

local function onKeyDown(editBox, key)
	if editBox == shownEditBox and key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
		-- let the copy happen first
		C_Timer.After(0, function() StaticPopup_Hide(DIALOG) end)
	end
end

StaticPopupDialogs[DIALOG] = {
	text = "%s\n\nPress Ctrl+C to copy the Wowhead link, then paste it in your browser.",
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 350,
	OnShow = function(dialog, data)
		local editBox = dialog:GetEditBox()
		shownEditBox = editBox
		if not hookedEditBoxes[editBox] then
			hookedEditBoxes[editBox] = true
			editBox:HookScript("OnKeyDown", onKeyDown)
		end
		editBox:SetText(data)
		editBox:SetFocus()
		editBox:HighlightText()
	end,
	OnHide = function()
		shownEditBox = nil
	end,
	-- the box only shows the link: put it back if it's typed over
	EditBoxOnTextChanged = function(editBox, data)
		if editBox:GetText() ~= data then
			editBox:SetText(data)
			editBox:HighlightText()
		end
	end,
	EditBoxOnEnterPressed = function()
		StaticPopup_Hide(DIALOG)
	end,
	EditBoxOnEscapePressed = function()
		StaticPopup_Hide(DIALOG)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function showLink(url, title)
	StaticPopup_Hide(DIALOG)
	-- %s in the dialog text is formatted, so a stray % in a name would break it
	StaticPopup_Show(DIALOG, ((title or url):gsub("%%", "%%%%")), nil, url)
end

-- Key Bindings > AddOns > Wowhead Lookup
BINDING_HEADER_WOWHEADLOOKUP = "Wowhead Lookup"
BINDING_NAME_WOWHEADLOOKUP_HOVERED = "Wowhead Link for Mouseover"

function WowheadLookup_LinkHovered()
	local url, title = urlForHovered()
	if url then
		showLink(url, title)
	else
		say("hover over an item, spell, quest, achievement or NPC first.")
	end
end

SLASH_WOWHEADLOOKUP1 = "/wiki"
SLASH_WOWHEADLOOKUP2 = "/wowhead"
SlashCmdList.WOWHEADLOOKUP = function(msg)
	local url, title = urlForText(msg or "")
	if not url then
		url, title = unitURL("target")
	end
	if url then
		showLink(url, title)
	else
		say("/wiki <shift-click a link, or type a search>; with nothing after it, your target. "
			.. "Set a key for what you're hovering in Key Bindings > AddOns.")
	end
end
