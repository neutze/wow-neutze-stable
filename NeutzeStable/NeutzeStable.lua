-- Neutze's Stable: one mount per character, kept in a character macro called "Mount".
NeutzeStable = NeutzeStable or {}
local NS = NeutzeStable
local PREFIX = "|cff66ccffNeutze's Stable|r: "
local MACRO = "Mount"

local function DB()
  NeutzeStableDB = NeutzeStableDB or {}
  return NeutzeStableDB
end

-- Find a collected mount by (part of) its name. Returns {id, name, spellID, icon} or nil.
local function FindMount(name)
  if not name or name == "" or not C_MountJournal then return nil end
  local want, partial = name:lower(), nil
  for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
    local mName, spellID, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(id)
    if mName and isCollected then
      local l = mName:lower()
      if l == want then return { id = id, name = mName, spellID = spellID, icon = icon } end
      if not partial and l:find(want, 1, true) then partial = { id = id, name = mName, spellID = spellID, icon = icon } end
    end
  end
  return partial
end

-- The mount you are sitting on right now, if any.
local function CurrentMountName()
  if not C_MountJournal or not IsMounted() then return nil end
  for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
    local mName, _, _, isActive = C_MountJournal.GetMountInfoByID(id)
    if isActive then return mName end
  end
end

local function Body(m)
  return "#showtooltip " .. m.name .. "\n/dismount [mounted]\n/run if not IsMounted() then C_MountJournal.SummonByID(" .. m.id .. ") end"
end

-- Create or update the character macro. Returns a status text.
local function WriteMacro()
  local m = FindMount(DB().name)
  if not m then return nil end
  if InCombatLockdown() then NS.pending = true; return "Will update the macro after combat." end
  local idx = GetMacroIndexByName(MACRO)
  if idx and idx > 0 then
    EditMacro(idx, MACRO, 134400, Body(m))
    return "Macro |cffffd200Mount|r updated."
  end
  local _, perChar = GetNumMacros()
  if perChar and perChar >= (MAX_CHARACTER_MACROS or 18) then
    return "|cffff5555Character macro tab is full|r - free a slot, then press Enter again."
  end
  CreateMacro(MACRO, 134400, Body(m), true)
  return "Macro |cffffd200Mount|r created on the character tab - drag it to your bar."
end
NS.WriteMacro = WriteMacro

local function StatusText(extra)
  local d = DB()
  if not d.name or d.name == "" then return "No mount set for this character." end
  local m = FindMount(d.name)
  if not m then return "|cffff5555Not found|r in your collected mounts." end
  return "|cff33ff33Found:|r " .. m.name .. (extra and ("  " .. extra) or "")
end

local function SetMount(name)
  name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
  local m = FindMount(name)
  DB().name = m and m.name or name
  return StatusText(m and WriteMacro() or nil)
end
NS.SetMount = SetMount

-- events: retry after combat, refresh the macro on login (mount list ready)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_REGEN_ENABLED" and not NS.pending then return end
  NS.pending = false
  if DB().name and DB().name ~= "" then C_Timer.After(2, WriteMacro) end
end)

-- own options panel (Options > AddOns > Neutze's Stable), works without Neutze's Pantry
local panel = CreateFrame("Frame")
panel.name = "Neutze's Stable"
local category
panel:SetScript("OnShow", function(self)
  if self.built then return end
  self.built = true
  local t = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16); t:SetText("Neutze's Stable")
  local l = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  l:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
  l:SetText("Mount for this character - writes the character macro \"Mount\" (press Enter):")
  local box = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
  box:SetSize(240, 22); box:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 6, -6); box:SetAutoFocus(false)
  local st = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  st:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -6); st:SetWidth(560); st:SetJustifyH("LEFT")
  local function apply(v) st:SetText(SetMount(v)) end
  box:SetText(DB().name or "")
  box:SetScript("OnEnterPressed", function(b) apply(b:GetText()); b:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(b) b:SetText(DB().name or ""); b:ClearFocus() end)
  local btn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
  btn:SetSize(150, 22); btn:SetPoint("LEFT", box, "RIGHT", 8, 0); btn:SetText("Use current mount")
  btn:SetScript("OnClick", function() local v = CurrentMountName(); if v then box:SetText(v); apply(v) else st:SetText("Mount up first, then click this.") end end)
  st:SetText(StatusText())
end)
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
end
local function OpenPanel()
  if category and Settings and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then InterfaceOptionsFrame_OpenToCategory(panel); InterfaceOptionsFrame_OpenToCategory(panel) end
end

SLASH_NEUTZESTABLE1 = "/stable"
SLASH_NEUTZESTABLE2 = "/ns"
SlashCmdList.NEUTZESTABLE = function(msg)
  msg = msg or ""
  if msg ~= "" then print(PREFIX .. SetMount(msg)); return end
  OpenPanel()
end

-- field at the end of the Neutze's Pantry panel
if NeutzePantry and NeutzePantry.RegisterSection and NeutzePantry.FieldRow then
  NeutzePantry.RegisterSection({ display = 91, order = 910, title = "Mount (Neutze's Stable)", height = 62,
    custom = function(parent, anchor)
      return NeutzePantry.FieldRow(parent, anchor, {
        label = "Mount for this character - writes the character macro \"Mount\" (press Enter):",
        get = function() return DB().name end,
        set = SetMount,
        status = StatusText,
        button = "Use current mount", current = CurrentMountName, noCurrent = "Mount up first, then click this.",
      })
    end })
end
