pfUI:RegisterModule("hidebuffs", "vanilla:tbc", function ()
  -- Configuration defaults
  pfUI:UpdateConfig("hidebuffs", nil, "enabled", "1")
  pfUI:UpdateConfig("hidebuffs", nil, "hiddenBuffs", "")

  local hiddenBuffNames = {}
  local visibleBuffIndices = {}
  local visibleBuffCount = 0
  local buffNameCache = {}  -- Cache buff names to avoid repeated tooltip scans
  local lastConfigString = ""  -- Track config changes

  -- Tooltip for getting buff names
  local tooltip = CreateFrame("GameTooltip", "pfUIHideBuffsTooltip", nil, "GameTooltipTemplate")

  -- Parse hidden buffs from config (only when config changes)
  local function ParseHiddenBuffs()
    local buffList = C.hidebuffs.hiddenBuffs or ""

    -- Only re-parse if config changed
    if buffList == lastConfigString then
      return
    end

    lastConfigString = buffList
    hiddenBuffNames = {}

    -- Handle empty or whitespace-only strings
    if buffList == "" or string.gsub(buffList, "%s", "") == "" then
      return
    end

    -- Split by # and process each buff name
    for buff in string.gfind(buffList, "[^#]+") do
      local trimmed = string.gsub(buff, "^%s*(.-)%s*$", "%1")
      if trimmed ~= "" then
        hiddenBuffNames[trimmed] = true
      end
    end
  end

  -- Get buff name from buff ID (with caching to avoid repeated tooltip scans)
  local function GetBuffName(buffId)
    if not buffId or buffId < 0 then return nil end

    -- Check cache first
    if buffNameCache[buffId] then
      return buffNameCache[buffId]
    end

    -- Scan with tooltip (expensive)
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPlayerBuff(buffId)
    local name = pfUIHideBuffsTooltipTextLeft1:GetText()
    tooltip:Hide()

    -- Cache the result
    buffNameCache[buffId] = name
    return name
  end

  -- Build list of visible buff indices (skipping hidden ones)
  local function BuildVisibleBuffs()
    if C.hidebuffs.enabled ~= "1" then
      visibleBuffIndices = {}
      visibleBuffCount = 0
      return
    end

    ParseHiddenBuffs()
    visibleBuffIndices = {}
    visibleBuffCount = 0

    local wepCount = pfUI.buff.wepbuffs.count or 0
    local actualBuffId = wepCount + 1

    while actualBuffId <= 32 do
      local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + actualBuffId, "HELPFUL")
      if bid < 0 then break end

      local buffName = GetBuffName(bid)
      if not (buffName and hiddenBuffNames[buffName]) then
        table.insert(visibleBuffIndices, actualBuffId)
        visibleBuffCount = visibleBuffCount + 1
      end
      actualBuffId = actualBuffId + 1
    end
  end

  -- Function to apply buff filtering
  local function ApplyBuffFiltering()
    if not pfUI.buff or not pfUI.buff.buffs or not pfUI.buff.buffs.buttons then return end

    -- Build visible buffs if enabled
    if C.hidebuffs.enabled == "1" then
      BuildVisibleBuffs()

      -- Apply filtering to helpful buffs
      if visibleBuffCount > 0 then
        for i=1,32 do
          local buff = pfUI.buff.buffs.buttons[i]
          if buff and buff.btype == "HELPFUL" and not buff.weapon then
            if i > visibleBuffCount then
              buff:Hide()
            else
              local actualId = visibleBuffIndices[i]
              if actualId then
                local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + actualId, "HELPFUL")
                if bid >= 0 and GetPlayerBuffTexture(bid) then
                  buff.bid = bid
                  buff.texture:SetTexture(GetPlayerBuffTexture(bid))
                  local br, bg, bb, ba = GetStringColor(pfUI_config.appearance.border.color)
                  buff.backdrop:SetBackdropBorderColor(br,bg,bb,ba)
                  buff:Show()
                else
                  buff:Hide()
                end
              else
                buff:Hide()
              end
            end
          end
        end
      end
    end
  end

  -- Hook into pfUI.buff after it's created
  local hookFrame = CreateFrame("Frame")
  hookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  hookFrame:SetScript("OnEvent", function()
    if not pfUI.buff then return end

    -- Store original OnEvent
    local originalOnEvent = pfUI.buff:GetScript("OnEvent")

    -- Replace OnEvent to inject our filtering
    pfUI.buff:SetScript("OnEvent", function()
      -- Get weapon count first
      if C.buffs.weapons == "1" then
        local mh, mhtime, mhcharge, oh, ohtime, ohcharge = GetWeaponEnchantInfo()
        pfUI.buff.wepbuffs.count = (mh and 1 or 0) + (oh and 1 or 0)
      else
        pfUI.buff.wepbuffs.count = 0
      end

      -- Build visible buffs if enabled
      if C.hidebuffs.enabled == "1" then
        BuildVisibleBuffs()
      end

      -- Call original to refresh all buttons
      if originalOnEvent then
        originalOnEvent()
      end

      -- Apply our filtering
      ApplyBuffFiltering()
    end)

    -- Trigger initial update
    pfUI.buff:GetScript("OnEvent")()

    -- Hook into pfUI unitframes RefreshUnit for player buffs
    -- We need to completely replace the buff reading logic like we did for global buffs
    if pfUI.uf and pfUI.uf.RefreshUnit then
      local originalRefreshUnit = pfUI.uf.RefreshUnit

      pfUI.uf.RefreshUnit = function(self, unit, component)
        -- Only intercept player unitframe buff updates
        if C.hidebuffs.enabled == "1" and unit and unit.label == "player" and unit.buffs and (component == "all" or component == "aura") then
          ParseHiddenBuffs()

          -- Build list of visible buff indices (exactly like global buff frame)
          local unitVisibleIndices = {}
          local actualBuffId = 1

          while actualBuffId <= 32 do
            local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + actualBuffId, "HELPFUL")
            if bid < 0 then break end

            local buffName = GetBuffName(bid)
            if not (buffName and hiddenBuffNames[buffName]) then
              table.insert(unitVisibleIndices, actualBuffId)
            end
            actualBuffId = actualBuffId + 1
          end

          -- Manually update buff slots using visible buff mapping
          for i=1, unit.config.bufflimit do
            if not unit.buffs[i] then break end

            local actualId = unitVisibleIndices[i]
            if actualId then
              -- Get the actual buff data
              local bid = GetPlayerBuff(PLAYER_BUFF_START_ID + actualId, "HELPFUL")
              local texture = GetPlayerBuffTexture(bid)
              local stacks = GetPlayerBuffApplications(bid)

              -- Update the buff slot's ID so tooltips work correctly
              unit.buffs[i].id = actualId

              unit.buffs[i].texture:SetTexture(texture)
              unit.buffs[i]:Show()

              if stacks > 1 then
                unit.buffs[i].stacks:SetText(stacks)
              else
                unit.buffs[i].stacks:SetText("")
              end

              -- Update cooldown if exists
              if unit.buffs[i].cd then
                local timeleft = GetPlayerBuffTimeLeft(bid)
                if timeleft and timeleft > 0 then
                  CooldownFrame_SetTimer(unit.buffs[i].cd, GetTime(), timeleft, 1)
                else
                  CooldownFrame_SetTimer(unit.buffs[i].cd, 0, 0, 0)
                end
              end
            else
              -- No more visible buffs
              unit.buffs[i]:Hide()
            end
          end

          -- Call original for non-buff components
          if component == "all" then
            -- Call with each component except aura
            originalRefreshUnit(self, unit, "base")
            originalRefreshUnit(self, unit, "portrait")
            originalRefreshUnit(self, unit, "pvp")
          elseif component ~= "aura" then
            originalRefreshUnit(self, unit, component)
          end
        else
          -- Normal flow for non-player or when disabled
          originalRefreshUnit(self, unit, component)
        end
      end
    end

    this:UnregisterAllEvents()
  end)

  -- Create GUI configuration
  if pfUI.gui.CreateGUIEntry then
    pfUI.gui.CreateGUIEntry(T["Thirdparty"], T["Hide Buffs"], function()
      pfUI.gui.CreateConfig(nil, T["Enable Hide Buffs"], C.hidebuffs, "enabled", "checkbox")
      pfUI.gui.CreateConfig(nil, T["Hidden Buff Names"], C.hidebuffs, "hiddenBuffs", "list")
    end)
  else
    pfUI.gui.tabs.thirdparty.tabs.hidebuffs = pfUI.gui.tabs.thirdparty.tabs:CreateTabChild("Hide Buffs", true)
    pfUI.gui.tabs.thirdparty.tabs.hidebuffs:SetScript("OnShow", function()
      if not this.setup then
        local CreateConfig = pfUI.gui.CreateConfig
        this.setup = true
        CreateConfig(this, T["Enable Hide Buffs"], C.hidebuffs, "enabled", "checkbox")
        CreateConfig(this, T["Hidden Buff Names"], C.hidebuffs, "hiddenBuffs", "list")
      end
    end)
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Hide Buffs|r loaded successfully")
end)
