-- AutoSummon.lua
-- Automatically accepts summon requests after a configurable delay.

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------
local ADDON_NAME            = "AutoSummon"
local DEFAULT_DELAY         = 5
local MIN_DELAY             = 0
local MAX_DELAY             = 60
local DEFAULT_CANCEL_COMBAT = true
local DEFAULT_CANCEL_DEATH  = true
local DEFAULT_SOUND_ALERT   = true
local DEFAULT_SHOW_INFO     = true

-------------------------------------------------------------------------------
-- Saved variables
-------------------------------------------------------------------------------
AutoSummonDB   = AutoSummonDB   or {}
AutoSummonDBPC = AutoSummonDBPC or {}

local function DB(key, default)
    if AutoSummonDB[key] == nil then AutoSummonDB[key] = default end
    return AutoSummonDB[key]
end
local function SetDB(key, val)    AutoSummonDB[key] = val end

local function DBPC(key, default)
    if AutoSummonDBPC[key] == nil then AutoSummonDBPC[key] = default end
    return AutoSummonDBPC[key]
end
local function SetDBPC(key, val)  AutoSummonDBPC[key] = val end

local function GetDelay()         return DB("delay",        DEFAULT_DELAY)         end
local function SetDelay(val)
    val = tonumber(val)
    if not val then return false end
    val = math.floor(val + 0.5)
    if val < MIN_DELAY or val > MAX_DELAY then return false end
    SetDB("delay", val)
    return true
end

local function IsEnabled()        return DB("enabled",      true)                  end
local function SetEnabled(v)      SetDB("enabled", v)                              end

local function GetSoundAlert()    return DB("soundAlert",   DEFAULT_SOUND_ALERT)   end
local function SetSoundAlert(v)   SetDB("soundAlert", v)                           end

local function GetShowInfo()      return DB("showInfo",     DEFAULT_SHOW_INFO)     end
local function SetShowInfo(v)     SetDB("showInfo", v)                             end

local function GetCancelCombat()  return DB("cancelCombat", DEFAULT_CANCEL_COMBAT) end
local function SetCancelCombat(v) SetDB("cancelCombat", v)                         end

local function GetCancelDeath()   return DB("cancelDeath",  DEFAULT_CANCEL_DEATH)  end
local function SetCancelDeath(v)  SetDB("cancelDeath", v)                          end

local function GetShowMinimap()   return DB("showMinimap",  true)                  end
local function SetShowMinimap(v)  SetDB("showMinimap", v)                          end

local function IsPerChar()        return DBPC("usePerChar", false)                 end
local function SetPerChar(v)      SetDBPC("usePerChar", v)                         end
local function GetPerCharDelay()  return DBPC("delay",      DEFAULT_DELAY)         end
local function SetPerCharDelay(val)
    val = tonumber(val)
    if not val then return false end
    val = math.floor(val + 0.5)
    if val < MIN_DELAY or val > MAX_DELAY then return false end
    SetDBPC("delay", val)
    return true
end

local function GetEffectiveDelay()
    if IsPerChar() then return GetPerCharDelay() end
    return GetDelay()
end

-------------------------------------------------------------------------------
-- Countdown state
-------------------------------------------------------------------------------
local countdownTimer  = nil
local countdownTick   = nil
local countdownRemain = 0

local function CancelCountdown(reason)
    if countdownTimer then countdownTimer:Cancel(); countdownTimer = nil end
    if countdownTick  then countdownTick:Cancel();  countdownTick  = nil end
    countdownRemain = 0
    if reason then
        print("|cff00ccff[AutoSummon]|r Summon acceptance cancelled: " .. reason)
    end
end

local function AcceptSummon()
    CancelCountdown()
    local ok = pcall(C_SummonInfo.ConfirmSummon)
    StaticPopup_Hide("CONFIRM_SUMMON")
    if ok then
        print("|cff00ff00[AutoSummon]|r Summon accepted!")
    else
        print("|cffff4444[AutoSummon]|r Summon dialog was no longer available.")
    end
end

local function StartCountdown(delay)
    CancelCountdown()

    local timeLeft = C_SummonInfo.GetSummonConfirmTimeLeft()
    if timeLeft and timeLeft > 0 then
        delay = math.min(delay, math.floor(timeLeft))
    end

    if GetSoundAlert() then PlaySound(SOUNDKIT.READY_CHECK) end

    local infoStr = ""
    if GetShowInfo() then
        local summoner = C_SummonInfo.GetSummonConfirmSummoner()
        local area     = C_SummonInfo.GetSummonConfirmAreaName()
        if summoner and summoner ~= "" then
            infoStr = string.format(" |cffaaaaaa(from |cffffffff%s|r|cffaaaaaa", summoner)
            if area and area ~= "" then
                infoStr = infoStr .. string.format(" to |cffffffff%s|r|cffaaaaaa", area)
            end
            infoStr = infoStr .. ")|r"
        end
    end

    if delay == 0 then
        print(string.format("|cff00ccff[AutoSummon]|r Summon detected%s — accepting instantly.", infoStr))
        AcceptSummon()
        return
    end

    countdownRemain = delay
    print(string.format(
        "|cff00ccff[AutoSummon]|r Summon detected%s — accepting in |cffffd700%d|r second%s. Type |cffffffff/as cancel|r to abort.",
        infoStr, delay, delay == 1 and "" or "s"))

    countdownTick = C_Timer.NewTicker(1, function()
        countdownRemain = countdownRemain - 1
        if countdownRemain > 0 then
            print(string.format("|cff00ccff[AutoSummon]|r Accepting in |cffffd700%d|r second%s...",
                countdownRemain, countdownRemain == 1 and "" or "s"))
        end
    end, delay - 1)

    countdownTimer = C_Timer.NewTimer(delay, AcceptSummon)
end

-------------------------------------------------------------------------------
-- Event handling
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "AutoSummonFrame", UIParent)
frame:RegisterEvent("INCOMING_SUMMON_CHANGED")   -- fires on new summon AND on cancel/expiry
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        GetDelay(); IsEnabled(); GetSoundAlert(); GetShowInfo()
        GetCancelCombat(); GetCancelDeath(); GetShowMinimap(); IsPerChar(); GetPerCharDelay()
        RegisterSettingsPanel()   -- defined below; safe to call here
        print(string.format(
            "|cff00ccff[AutoSummon]|r Loaded. Delay: |cffffd700%ds|r | Status: %s  — type |cffffffff/as|r for help.",
            GetEffectiveDelay(),
            IsEnabled() and "|cff00ff00Enabled|r" or "|cffff4444Disabled|r"))

    elseif event == "INCOMING_SUMMON_CHANGED" then
        -- GetSummonConfirmTimeLeft() > 0 means a new summon just arrived;
        -- 0 or nil means it was cancelled, expired, or already accepted.
        local timeLeft = C_SummonInfo.GetSummonConfirmTimeLeft()
        if timeLeft and timeLeft > 0 then
            if not IsEnabled() then return end
            StartCountdown(GetEffectiveDelay())
        else
            if countdownTimer then CancelCountdown("|cffaaaaaa(summon expired)") end
        end

    elseif event == "PLAYER_DEAD" then
        if countdownTimer and GetCancelDeath() then CancelCountdown("|cffaaaaaa(you died)") end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if countdownTimer and GetCancelCombat() then CancelCountdown("|cffaaaaaa(entered combat)") end
    end
end)

-------------------------------------------------------------------------------
-- Tooltip helper
-------------------------------------------------------------------------------
local function AddTooltip(widget, title, body)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1, 1, true)
        if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- Shared UI builder
-- Builds all the controls onto `parent` starting at anchorY below the top.
-- Returns a SyncUI() function that refreshes all widget states from saved vars.
-------------------------------------------------------------------------------
local function BuildSettingsControls(parent, startX, startY)
    local updatingUI = false
    local x = startX
    local y = startY   -- negative = downward from top of parent

    -- ── Delay ────────────────────────────────────────────────────────────────
    local delayHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    delayHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    delayHeader:SetText("Summon Delay")

    y = y - 24
    local delayDesc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    delayDesc:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    delayDesc:SetText("Seconds to wait before accepting a summon:")
    delayDesc:SetTextColor(0.8, 0.8, 0.8)

    y = y - 32
    local delaySlider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    delaySlider:SetWidth(220)
    delaySlider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 4, y)
    delaySlider:SetMinMaxValues(MIN_DELAY, MAX_DELAY)
    delaySlider:SetValueStep(1)
    delaySlider:SetObeyStepOnDrag(true)
    delaySlider:SetValue(GetEffectiveDelay())
    delaySlider.Low:SetText(tostring(MIN_DELAY))
    delaySlider.High:SetText(tostring(MAX_DELAY))
    delaySlider.Text:SetText("")
    AddTooltip(delaySlider,
        "Auto-Accept Delay",
        "How many seconds to wait before accepting. Set to 0 to accept instantly.\n"..
        "Automatically capped to the remaining summon window.")

    local delayBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    delayBox:SetSize(46, 26)
    delayBox:SetPoint("LEFT", delaySlider, "RIGHT", 12, 0)
    delayBox:SetAutoFocus(false)
    delayBox:SetNumeric(true)
    delayBox:SetMaxLetters(2)
    delayBox:SetText(tostring(GetEffectiveDelay()))
    AddTooltip(delayBox, "Auto-Accept Delay", "Type a number (0-60) and press Enter or Tab to apply.")

    local secLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secLabel:SetPoint("LEFT", delayBox, "RIGHT", 4, 0)
    secLabel:SetTextColor(0.7, 0.7, 0.7)
    secLabel:SetText("sec")

    delaySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        if not updatingUI then
            updatingUI = true
            delayBox:SetText(tostring(value))
            updatingUI = false
        end
        if IsPerChar() then SetPerCharDelay(value) else SetDelay(value) end
    end)

    local function CommitDelayBox()
        local val = tonumber(delayBox:GetText())
        if val then
            val = math.max(MIN_DELAY, math.min(MAX_DELAY, math.floor(val + 0.5)))
            if IsPerChar() then SetPerCharDelay(val) else SetDelay(val) end
            updatingUI = true
            delaySlider:SetValue(val)
            delayBox:SetText(tostring(val))
            updatingUI = false
            print(string.format("|cff00ccff[AutoSummon]|r Delay set to |cffffd700%ds|r.", val))
        else
            delayBox:SetText(tostring(GetEffectiveDelay()))
        end
        delayBox:ClearFocus()
    end
    delayBox:SetScript("OnEnterPressed",  CommitDelayBox)
    delayBox:SetScript("OnTabPressed",    CommitDelayBox)
    delayBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(GetEffectiveDelay()))
        self:ClearFocus()
    end)

    -- ── Per-character override ────────────────────────────────────────────────
    y = y - 42
    local perCharCheck = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    perCharCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 2, y)
    perCharCheck.Text:SetText("Use per-character delay for this character")
    AddTooltip(perCharCheck,
        "Per-Character Delay",
        "When checked, this character uses its own delay instead of the global setting.\n"..
        "Useful if you want different delays on different characters.")
    perCharCheck:SetScript("OnClick", function(self)
        SetPerChar(self:GetChecked())
        local d = GetEffectiveDelay()
        updatingUI = true
        delaySlider:SetValue(d)
        delayBox:SetText(tostring(d))
        updatingUI = false
        print(string.format("|cff00ccff[AutoSummon]|r Per-character delay %s (|cffffd700%ds|r).",
            IsPerChar() and "|cff00ff00enabled|r" or "|cffaaaaaa disabled|r", d))
    end)

    -- ── Divider ───────────────────────────────────────────────────────────────
    y = y - 36
    local div = parent:CreateTexture(nil, "ARTWORK")
    div:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    div:SetSize(320, 1)
    div:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- ── Behaviour section ─────────────────────────────────────────────────────
    y = y - 18
    local behavHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    behavHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    behavHeader:SetText("Behaviour")

    local checks = {}   -- { frame, getter, setter, label, ttTitle, ttBody }
    local checkDefs = {
        {
            getter = IsEnabled,  setter = SetEnabled,
            label  = "Enable AutoSummon",
            ttTitle = "Enable AutoSummon",
            ttBody  = "Master switch. When unchecked all summons are ignored and the normal in-game dialog appears as usual.",
        },
        {
            getter = GetSoundAlert, setter = SetSoundAlert,
            label  = "Play sound alert on summon",
            ttTitle = "Sound Alert",
            ttBody  = "Plays the Ready Check sound the moment a summon is detected, so you hear it even if you are looking away.",
            onChange = function(val) if val then PlaySound(SOUNDKIT.READY_CHECK) end end,
        },
        {
            getter = GetShowInfo, setter = SetShowInfo,
            label  = "Show summoner and destination in chat",
            ttTitle = "Summoner Info",
            ttBody  = "Includes who is summoning you and to which zone in the countdown message.",
        },
        {
            getter = GetCancelCombat, setter = SetCancelCombat,
            label  = "Cancel if you enter combat",
            ttTitle = "Cancel on Combat",
            ttBody  = "Aborts the countdown if you enter combat before it finishes. Prevents being yanked out of a fight by an accidental summon.",
        },
        {
            getter = GetCancelDeath, setter = SetCancelDeath,
            label  = "Cancel if you die",
            ttTitle = "Cancel on Death",
            ttBody  = "Aborts the countdown if you die before it finishes.",
        },
        {
            getter = GetShowMinimap, setter = SetShowMinimap,
            label  = "Show minimap button",
            ttTitle = "Minimap Button",
            ttBody  = "Shows or hides the AutoSummon icon on the minimap edge.",
            onChange = function(val)
                if minimapButton then
                    if val then minimapButton:Show() else minimapButton:Hide() end
                end
            end,
        },
    }

    for _, def in ipairs(checkDefs) do
        y = y - 28
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 2, y)
        cb.Text:SetText(def.label)
        AddTooltip(cb, def.ttTitle, def.ttBody)
        cb:SetScript("OnClick", function(self)
            def.setter(self:GetChecked())
            if def.onChange then def.onChange(self:GetChecked()) end
        end)
        table.insert(checks, { frame = cb, getter = def.getter })
    end

    -- ── SyncUI: refresh all widgets from saved vars ───────────────────────────
    local function SyncUI()
        local d = GetEffectiveDelay()
        updatingUI = true
        delaySlider:SetValue(d)
        delayBox:SetText(tostring(d))
        updatingUI = false
        perCharCheck:SetChecked(IsPerChar())
        for _, c in ipairs(checks) do
            c.frame:SetChecked(c.getter())
        end
    end

    return SyncUI
end

-------------------------------------------------------------------------------
-- Settings panel (registered with the WoW Options > AddOns tab)
-- This is the canonical home for settings in 12.0+.
-------------------------------------------------------------------------------
local settingsCanvas   = nil
local settingsSyncUI   = nil

function RegisterSettingsPanel()
    -- Canvas frame: plain, no chrome — the Settings panel provides its own.
    settingsCanvas = CreateFrame("Frame", "AutoSummonSettingsCanvas", UIParent)
    settingsCanvas:SetSize(634, 500)   -- standard canvas dimensions

    settingsSyncUI = BuildSettingsControls(settingsCanvas, 16, -16)

    local category = Settings.RegisterCanvasLayoutCategory(settingsCanvas, ADDON_NAME)
    Settings.RegisterAddOnCategory(category)

    -- Sync UI every time the panel becomes visible
    settingsCanvas:SetScript("OnShow", settingsSyncUI)
end

-------------------------------------------------------------------------------
-- Standalone config window (slash command / minimap button)
-- Same controls, separate frame with a title bar and close button.
-------------------------------------------------------------------------------
local configFrame = CreateFrame("Frame", "AutoSummonConfig", UIParent, "BasicFrameTemplateWithInset")
configFrame:SetSize(360, 420)
configFrame:SetPoint("CENTER")
configFrame:SetMovable(true)
configFrame:EnableMouse(true)
configFrame:RegisterForDrag("LeftButton")
configFrame:SetScript("OnDragStart", configFrame.StartMoving)
configFrame:SetScript("OnDragStop",  configFrame.StopMovingOrSizing)
configFrame:Hide()
configFrame.TitleText:SetText("AutoSummon Settings")

local standaloneSyncUI = BuildSettingsControls(configFrame, 16, -32)
configFrame:SetScript("OnShow", standaloneSyncUI)

-------------------------------------------------------------------------------
-- Minimap button  (standard circular style used by most addons)
-------------------------------------------------------------------------------
local minimapButton = CreateFrame("Button", "AutoSummonMinimapButton", Minimap)
minimapButton:SetSize(31, 31)   -- matches the TrackingBorder inner circle
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

-- Icon — custom "AS" texture
local minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("CENTER")
minimapIcon:SetTexture("Interface\\AddOns\\AutoSummon\\icon.png")

-- Ring border — circular ring with transparent centre
local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetSize(53, 53)
minimapBorder:SetPoint("TOPLEFT")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Highlight on hover
local minimapHL = minimapButton:CreateTexture(nil, "HIGHLIGHT")
minimapHL:SetSize(18, 18)
minimapHL:SetPoint("CENTER")
minimapHL:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapHL:SetBlendMode("ADD")

local minimapAngle = -math.pi / 4
local function UpdateMinimapPos()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER",
        70 * math.cos(minimapAngle),
        70 * math.sin(minimapAngle))
end
UpdateMinimapPos()

minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", minimapButton.StartMoving)
minimapButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local cx, cy = Minimap:GetCenter()
    local mx, my = self:GetCenter()
    minimapAngle = math.atan2(my - cy, mx - cx)
    UpdateMinimapPos()
end)

minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end
    end
end)

AddTooltip(minimapButton, "AutoSummon", "Click to open settings.\nDrag to reposition.")

-- Apply saved visibility on load
if GetShowMinimap() then minimapButton:Show() else minimapButton:Hide() end

-------------------------------------------------------------------------------
-- Slash commands  /autosummon  /as
-------------------------------------------------------------------------------
local function PrintHelp()
    print("|cff00ccffAutoSummon commands:|r")
    print("  |cffffffff/as|r               — toggle settings window")
    print("  |cffffffff/as options|r       — open the Options panel (AddOns tab)")
    print("  |cffffffff/as delay <N>|r     — set delay in seconds (0–60)")
    print("  |cffffffff/as enable|r        — enable the addon")
    print("  |cffffffff/as disable|r       — disable the addon")
    print("  |cffffffff/as cancel|r        — cancel a pending summon acceptance")
    print("  |cffffffff/as status|r        — show current settings")
end

local function HandleSlash(msg)
    msg = strtrim(msg or ""):lower()
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd or ""
    arg = strtrim(arg or "")

    if cmd == "" then
        if configFrame:IsShown() then configFrame:Hide() else configFrame:Show() end

    elseif cmd == "options" then
        Settings.OpenToCategory(ADDON_NAME)

    elseif cmd == "delay" then
        local ok = IsPerChar() and SetPerCharDelay(arg) or SetDelay(arg)
        if ok then
            print(string.format("|cff00ccff[AutoSummon]|r Delay set to |cffffd700%ds|r.", GetEffectiveDelay()))
        else
            print(string.format("|cffff4444[AutoSummon]|r Invalid value. Enter a whole number %d-%d.", MIN_DELAY, MAX_DELAY))
        end

    elseif cmd == "enable" then
        SetEnabled(true)
        print("|cff00ccff[AutoSummon]|r |cff00ff00Enabled|r.")

    elseif cmd == "disable" then
        SetEnabled(false)
        print("|cff00ccff[AutoSummon]|r |cffff4444Disabled|r.")

    elseif cmd == "cancel" then
        if countdownTimer then
            CancelCountdown("|cffaaaaaa(manual cancel)")
        else
            print("|cff00ccff[AutoSummon]|r No pending summon to cancel.")
        end

    elseif cmd == "status" then
        print(string.format(
            "|cff00ccff[AutoSummon]|r Delay: |cffffd700%ds|r%s | Status: %s | Sound: %s | Info: %s | CancelCombat: %s | CancelDeath: %s",
            GetEffectiveDelay(),
            IsPerChar() and " |cffaaaaaa(per-char)|r" or "",
            IsEnabled()       and "|cff00ff00On|r" or "|cffff4444Off|r",
            GetSoundAlert()   and "|cff00ff00On|r" or "|cffff4444Off|r",
            GetShowInfo()     and "|cff00ff00On|r" or "|cffff4444Off|r",
            GetCancelCombat() and "|cff00ff00On|r" or "|cffff4444Off|r",
            GetCancelDeath()  and "|cff00ff00On|r" or "|cffff4444Off|r"))
    else
        PrintHelp()
    end
end

SLASH_AUTOSUMMON1 = "/autosummon"
SLASH_AUTOSUMMON2 = "/as"
SlashCmdList["AUTOSUMMON"] = HandleSlash
