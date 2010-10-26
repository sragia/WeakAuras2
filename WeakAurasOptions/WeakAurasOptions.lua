local LDB = LibStub:GetLibrary("LibDataBroker-1.1");
local AceGUI = LibStub("AceGUI-3.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

local L = WeakAuras.L;

local ADDON_NAME = "WeakAurasOptions";

local GetSpellInfo = GetSpellInfo;
local GetItemInfo = GetItemInfo;

local iconCache = {};

local regionOptions = {};
local displayButtons = {};
local optionReloads = {};
local optionTriggerChoices = {};
local thumbnails = {};
local displayOptions = {};
WeakAuras.displayOptions = displayOptions;

--This function computes the Levenshtein distance between two strings
--It is based on the Wagner-Fisher algorithm
--
--The Levenshtein distance between two strings is the minimum number of operations needed
--to transform one into the other, with allowable operations being addition of one letter,
--subtraction of one letter, or substitution of one letter for another
--
--It is used in this program to match spell icon textures with "good" spell names; i.e.,
--spell names that are very similar to the name of the texture
local function Lev(str1, str2)
   local matrix = {};
   for i=0, str1:len() do
      matrix[i] = {[0] = i};
   end
   for j=0, str2:len() do
      matrix[0][j] = j;
   end
   for j=1, str2:len() do
      for i =1, str1:len() do
         if(str1:sub(i, i) == str2:sub(j, j)) then
            matrix[i][j] = matrix[i-1][j-1];
         else
            matrix[i][j] = math.min(matrix[i-1][j], matrix[i][j-1], matrix[i-1][j-1]) + 1;
         end
      end
   end
   
   return matrix[str1:len()][str2:len()];
end

local trigger_types = WeakAuras.trigger_types;
local debuff_types = WeakAuras.debuff_types;
local unit_types = WeakAuras.unit_types;
local actual_unit_types = WeakAuras.actual_unit_types;
local threat_unit_types = WeakAuras.threat_unit_types;
local unit_threat_situations = WeakAuras.unit_threat_situations;
local no_unit_threat_situations = WeakAuras.no_unit_threat_situations;
local class_for_stance_types = WeakAuras.class_for_stance_types;
local class_types = WeakAuras.class_types;
local deathknight_form_types = WeakAuras.deathknight_form_types;
local druid_form_types = WeakAuras.druid_form_types;
local paladin_form_types = WeakAuras.paladin_form_types;
local priest_form_types = WeakAuras.priest_form_types;
local rogue_form_types = WeakAuras.rogue_form_types;
local shaman_form_types = WeakAuras.shaman_form_types;
local warrior_form_types = WeakAuras.warrior_form_types;
local single_form_types = WeakAuras.single_form_types;
local blend_types = WeakAuras.blend_types;
local point_types = WeakAuras.point_types;
local event_types = WeakAuras.event_types;
local subevent_prefix_types = WeakAuras.subevent_prefix_types;
local subevent_actual_prefix_types = WeakAuras.subevent_actual_prefix_types;
local subevent_suffix_types = WeakAuras.subevent_suffix_types;
local power_types = WeakAuras.power_types;
local miss_types = WeakAuras.miss_types;
local environmental_types = WeakAuras.environmental_types;
local aura_types = WeakAuras.aura_types;
local orientation_types = WeakAuras.orientation_types;
local spec_types = WeakAuras.spec_types;
local totem_types = WeakAuras.totem_types;
local texture_types = WeakAuras.texture_types;
local operator_types = WeakAuras.operator_types;
local string_operator_types = WeakAuras.string_operator_types;
local weapon_types = WeakAuras.weapon_types;
local rune_specific_types = WeakAuras.rune_specific_types;
local eventend_types = WeakAuras.eventend_types;
local autoeventend_types = WeakAuras.autoeventend_types;
local justify_types = WeakAuras.justify_types;
local grow_types = WeakAuras.grow_types;
local align_types = WeakAuras.align_types;
local rotated_align_types = WeakAuras.rotated_align_types;
local anim_types = WeakAuras.anim_types;
local anim_translate_types = WeakAuras.anim_translate_types;
local anim_scale_types = WeakAuras.anim_scale_types;
local anim_alpha_types = WeakAuras.anim_alpha_types;
local anim_rotate_types = WeakAuras.anim_rotate_types;
local group_types = WeakAuras.group_types;
local difficulty_types = WeakAuras.difficulty_types;
local anim_start_preset_types = WeakAuras.anim_start_preset_types;
local anim_main_preset_types = WeakAuras.anim_main_preset_types;
local anim_finish_preset_types = WeakAuras.anim_finish_preset_types;
local chat_message_types = WeakAuras.chat_message_types;
local send_chat_message_types = WeakAuras.send_chat_message_types;
local sound_types = WeakAuras.sound_types;
local duration_types = WeakAuras.duration_types;
local duration_types_no_choice = WeakAuras.duration_types_no_choice;

local function union(table1, table2)
  local meta = {};
  for i,v in pairs(table1) do
    meta[i] = v;
  end
  for i,v in pairs(table2) do
    meta[i] = v;
  end
  return meta;
end

function WeakAuras.CreateIconCache(callback)
  local cacheFrame = CreateFrame("Frame");
  local id = 95000;
  cacheFrame:SetAllPoints(UIParent);
  cacheFrame:SetScript("OnUpdate", function()
    local start = GetTime();
    while(GetTime() - start < 0.01) do
      id = id - 1;
      if(id > 0) then
        local name, _, icon = GetSpellInfo(id);
        if(name) then
          iconCache[name] = icon;
        end
      end
    end
    if(id < 1) then
      cacheFrame:SetScript("OnUpdate", nil);
      if(callback) then
        callback();
      end
    end
  end);
end


function WeakAuras.ConstructOptions(prototype, data, startorder, subPrefix, subSuffix, triggernum, triggertype, unevent)
  local trigger, untrigger;
  if(triggertype == "load") then
    trigger = data.load;
  elseif(data.controlledChildren) then
    trigger, untrigger = {}, {};
  else
    if(triggernum == 0) then
      data.untrigger = data.untrigger or {};
      if(triggertype == "untrigger") then
        trigger = data.untrigger;
      else
        trigger = data.trigger;
        untrigger = data.untrigger;
      end
    elseif(triggernum >= 1 and triggernum <= 9) then
      data.additional_triggers[triggernum].untrigger = data.additional_triggers[triggernum].untrigger or {};
      if(triggertype == "untrigger") then
        trigger = data.additional_triggers[triggernum].untrigger;
      else
        trigger = data.additional_triggers[triggernum].trigger;
        untrigger = data.additional_triggers[triggernum].untrigger;
      end
    else
      error("Improper argument to WeakAuras.ConstructOptions - trigger number not in range");
    end
  end
  unevent = unevent or trigger.unevent;
  local options = {};
  local order = startorder or 10;
  for index, arg in pairs(prototype.args) do
    local hidden = nil;
    if(type(arg.enable) == "function") then
      hidden = function() return not arg.enable(trigger) end;
    end
    local name = arg.name;
    if(name and not arg.hidden) then
      local realname = name;
      if(triggertype == "untrigger") then
        name = "untrigger_"..name;
      end
      if(arg.type == "tristate") then
        options["use_"..name] = {
          type = "toggle",
          name = function(input)
            local value = trigger["use_"..realname];
            if(value == nil) then return arg.display;
            elseif(value == false) then return "|cFFFF0000 "..L["Negator"].." "..arg.display;
            else return "|cFF00FF00"..arg.display; end
          end,
          get = function() 
            local value = trigger["use_"..realname];
            if(value == nil) then return false;
            elseif(value == false) then return "false";
            else return "true"; end
          end,
          set = function(info, v)
            if(v) then
              trigger["use_"..realname] = true;
            else
              local value = trigger["use_"..realname];
              if(value == false) then trigger["use_"..realname] = nil;
              else trigger["use_"..realname] = false end
            end
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end,
          hidden = hidden,
          order = order
        };
      else
        options["use_"..name] = {
          type = "toggle",
          name = arg.display,
          order = order,
          hidden = hidden,
          get = function() return trigger["use_"..realname]; end,
          set = function(info, v)
            trigger["use_"..realname] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
      end
      if(arg.type == "toggle" or arg.type == "tristate") then
        options["use_"..name].width = "double";
      elseif(arg.type == "spell" or arg.type == "aura" or arg.type == "item") then
        options["use_"..name].width = "half";
      end
      if(arg.required) then
        trigger["use_"..realname] = true;
        if not(triggertype) then
          options["use_"..name].disabled = true;
        else
          options["use_"..name] = nil;
          order = order - 1;
        end
      end
      order = order + 1;
      if(arg.type == "number") then
        options[name.."_operator"] = {
          type = "select",
          name = L["Operator"],
          width = "half",
          order = order,
          hidden = hidden,
          values = operator_types,
          disabled = function() return not trigger["use_"..realname]; end,
          get = function() return trigger["use_"..realname] and trigger[realname.."_operator"] or nil; end,
          set = function(info, v)
            trigger[realname.."_operator"] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name.."_operator"].set = function(info, v) trigger[realname.."_operator"] = v; untrigger[realname.."_operator"] = v; WeakAuras.Add(data); WeakAuras.ScanForLoads(); WeakAuras.SortDisplayButtons(); end
        elseif(arg.required and triggertype == "untrigger") then
          options[name.."_operator"] = nil;
          order = order - 1;
        end
        order = order + 1;
        options[name] = {
          type = "input",
          name = arg.display,
          width = "half",
          order = order,
          hidden = hidden,
          disabled = function() return not trigger["use_"..realname]; end,
          get = function() return trigger["use_"..realname] and trigger[realname] or nil; end,
          set = function(info, v)
            trigger[realname] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name].set = function(info, v) trigger[realname] = v; untrigger[realname] = v; WeakAuras.Add(data); WeakAuras.ScanForLoads(); WeakAuras.SortDisplayButtons(); end
        elseif(arg.required and triggertype == "untrigger") then
          options[name] = nil;
          order = order - 1;
        end
        order = order + 1;
      elseif(arg.type == "string") then
        options[name] = {
          type = "input",
          name = arg.display,
          order = order,
          hidden = hidden,
          disabled = function() return not trigger["use_"..realname]; end,
          get = function() return trigger["use_"..realname] and trigger[realname] or nil; end,
          set = function(info, v)
            trigger[realname] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name].set = function(info, v) trigger[realname] = v; untrigger[realname] = v; WeakAuras.Add(data); WeakAuras.ScanForLoads(); WeakAuras.SortDisplayButtons(); end
        elseif(arg.required and triggertype == "untrigger") then
          options[name] = nil;
          order = order - 1;
        end
        order = order + 1;
      elseif(arg.type == "longstring") then
        options[name.."_operator"] = {
          type = "select",
          name = L["Operator"],
          order = order,
          hidden = hidden,
          values = string_operator_types,
          disabled = function() return not trigger["use_"..realname]; end,
          get = function() return trigger["use_"..realname] and trigger[realname.."_operator"] or nil; end,
          set = function(info, v)
            trigger[realname.."_operator"] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name.."_operator"].set = function(info, v) trigger[realname.."_operator"] = v; untrigger[realname.."_operator"] = v; WeakAuras.Add(data); WeakAuras.ScanForLoads(); WeakAuras.SortDisplayButtons(); end
        elseif(arg.required and triggertype == "untrigger") then
          options[name.."_operator"] = nil;
          order = order - 1;
        end
        order = order + 1;
        options[name] = {
          type = "input",
          name = arg.display,
          width = "double",
          order = order,
          hidden = hidden,
          disabled = function() return not trigger["use_"..realname]; end,
          get = function() return trigger["use_"..realname] and trigger[realname] or nil; end,
          set = function(info, v)
            trigger[realname] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name].set = function(info, v) trigger[realname] = v; untrigger[realname] = v; WeakAuras.Add(data); WeakAuras.ScanForLoads(); WeakAuras.SortDisplayButtons(); end
        elseif(arg.required and triggertype == "untrigger") then
          options[name] = nil;
          order = order - 1;
        end
        order = order + 1;
      elseif(arg.type == "spell" or arg.type == "aura" or arg.type == "item") then
        options["icon"..name] = {
          type = "execute",
          name = "",
          order = order,
          hidden = hidden,
          width = "half",
          image = function()
            if(trigger["use_"..realname] and trigger[realname]) then
              if(arg.type == "aura") then
                return iconCache[trigger[realname]] or "", 18, 18;
              elseif(arg.type == "spell") then
                local _, _, icon = GetSpellInfo(trigger[realname]);
                return icon or "", 18, 18;
              elseif(arg.type == "item") then
                local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(trigger[realname]);
                return icon or "", 18, 18;
              end
            else
              return "", 18, 18;
            end
          end,
          disabled = function() return not ((arg.type == "aura" and trigger[realname] and iconCache[trigger[realname]]) or (arg.type == "spell" and trigger[realname] and GetSpellInfo(trigger[realname])) or (arg.type == "item" and trigger[realname] and GetItemIcon(trigger[realname]))) end
        };
        order = order + 1;
        options[name] = {
          type = "input",
          name = arg.display,
          order = order,
          hidden = hidden,
          disabled = function() return not trigger["use_"..realname]; end,
          get = function()
            if(arg.type == "item") then
              if(trigger["use_"..realname] and trigger[realname] and trigger[realname] ~= "") then
                local name = GetItemInfo(trigger[realname]);
                if(name) then
                  return name;
                else
                  return "Invalid Item Name/ID/Link";
                end
              else
                return nil;
              end
            elseif(arg.type == "spell") then
              if(trigger["use_"..realname] and trigger[realname] and trigger[realname] ~= "") then
                local name = GetSpellInfo(trigger[realname]);
                if(name) then
                  return name;
                else
                  return "Invalid Spell Name/ID/Link";
                end
              else
                return nil;
              end
            else
              return trigger["use_"..realname] and trigger[realname] or nil;
            end
          end,
          set = function(info, v)
            local fixedInput = v;
            if(arg.type == "aura") then
              fixedInput = WeakAuras.CorrectAuraName(v);
            elseif(arg.type == "spell") then
              fixedInput = WeakAuras.CorrectSpellName(v);
            elseif(arg.type == "item") then
              fixedInput = WeakAuras.CorrectItemName(v);
            end
            trigger[realname] = fixedInput;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name].set = function(info, v)
            local fixedInput = v;
            if(arg.type == "aura") then
              fixedInput = WeakAuras.CorrectAuraName(v);
            elseif(arg.type == "spell") then
              fixedInput = GetSpellInfo(v);
            elseif(arg.type == "item") then
              fixedInput = GetItemInfo(v);
            end
            trigger[realname] = fixedInput;
            untrigger[realname] = fixedInput;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        elseif(arg.required and triggertype == "untrigger") then
          options["icon"..name] = nil;
          options[name] = nil;
          order = order - 2;
        end
        order = order + 1;
      elseif(arg.type == "select") then
        options[name] = {
          type = "select",
          name = arg.display,
          order = order,
          hidden = hidden,
          values = WeakAuras[arg.values],
          disabled = function() return not trigger["use_"..realname]; end,
          get = function() return trigger["use_"..realname] and trigger[realname] or nil; end,
          set = function(info, v)
            trigger[realname] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        };
        if(arg.required and not triggertype) then
          options[name].set = function(info, v)
            trigger[realname] = v;
            untrigger[realname] = v;
            WeakAuras.Add(data);
            WeakAuras.ScanForLoads();
            WeakAuras.SetThumbnail(data);
            WeakAuras.SetIconNames(data);
            WeakAuras.UpdateDisplayButton(data);
            WeakAuras.SortDisplayButtons();
          end
        elseif(arg.required and triggertype == "untrigger") then
          options[name] = nil;
          order = order - 1;
        end
        order = order + 1;
      end
    end
  end
  
  if not(triggertype or prototype.automaticrequired) then
    options.unevent = {
      type = "select",
      name = L["Hide"],
      width = "double",
      order = order
    };
    order = order + 1;
    if(unevent == "timed") then
      options.unevent.width = "normal";
      options.duration = {
        type = "input",
        name = L["Duration (s)"],
        order = order
      }
      order = order + 1;
    else
      options.unevent.width = "double";
    end
    if(unevent == "custom") then
      local unevent_options = WeakAuras.ConstructOptions(prototype, data, order, subPrefix, subSuffix, triggernum, "untrigger");
      options = union(options, unevent_options);
    end
    if(prototype.automatic) then
      options.unevent.values = autoeventend_types;
    else
      options.unevent.values = eventend_types;
    end
  end
  
  WeakAuras.option = options;
  return options;
end

local frame;

local db;
local odb;
local loaded = WeakAuras.loaded;
local options;
local newOptions;
local loadedOptions;
local unloadedOptions;
local pickonupdate;
local loadedFrame = CreateFrame("FRAME");
loadedFrame:RegisterEvent("ADDON_LOADED");
loadedFrame:SetScript("OnEvent", function(self, event, addon)
  if(addon == ADDON_NAME) then
    db = WeakAurasSaved;
    WeakAurasOptionsSaved = WeakAurasOptionsSaved or {};
    odb = WeakAurasOptionsSaved;
    
    --Builds a cache of name/icon pairs from existing spell data
    --Why? Because if you call GetSpellInfo with a spell name, it only works if the spell is an actual castable ability,
    --but if you call it with a spell id, you can get buffs, talents, etc. This is useful for displaying faux aura information
    --for displays that are not actually connected to auras (for non-automatic icon displays with predefined icons)
    --Also builds a hash where icon keys return tables of all spell names that use that icon
    --
    --This is a very slow operation, so it's only done once, and the result is subsequently saved
    odb.iconCache = odb.iconCache or {};
    iconCache = odb.iconCache;
    local _, build = GetBuildInfo();
    local locale = GetLocale();
    if(odb.locale ~= locale or odb.build ~= build or forceCacheReset) then
      WeakAuras.CreateIconCache();

      odb.build = build;
      odb.locale = locale;
    end

    --Updates the icon cache with whatever icons WeakAuras core has actually used.
    --This helps keep name<->icon matches relevant.
    for name, icon in pairs(db.tempIconCache) do
      iconCache[name] = icon;
    end
  end
end);

function WeakAuras.RegisterRegionOptions(name, createFunction, icon, displayName, createThumbnail, modifyThumbnail, description)
  if not(name) then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - name is not defined");
  elseif(type(name) ~= "string") then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - name is not a string");
  elseif not(createFunction) then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - creation function is not defined");
  elseif(type(createFunction) ~= "function") then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - creation function is not a function");
  elseif not(icon) then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - icon is not defined");
  elseif not(type(icon) == "string" or type(icon) == "function") then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - icon is not a string or a function")
  elseif not(displayName) then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - display name is not defined".." "..name);
  elseif(type(displayName) ~= "string") then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - display name is not a string");
  elseif(regionOptions[name]) then
    error("Improper arguments to WeakAuras.RegisterRegionOptions - region type \""..name.."\" already defined");
  else
    regionOptions[name] = {
      create = createFunction,
      icon = icon,
      displayName = displayName,
      createThumbnail = createThumbnail,
      modifyThumbnail = modifyThumbnail,
      description = description
    };
  end
end

function WeakAuras.ToggleOptions(forceCacheReset)
  if(frame) then
    WeakAuras.HideOptions();
  else
    WeakAuras.ShowOptions(forceCacheReset);
  end
end

function WeakAuras.ShowOptions(forceCacheReset)
  WeakAuras.Pause();

  if not(frame) then
    frame = WeakAuras.CreateFrame();
  end
  WeakAuras.BuildOptions();
  WeakAuras.LayoutDisplayButtons();
  frame:Show();
  frame:PickOption("New");
  WeakAuras.LockUpdateInfo();
  for id, data in pairs(db.displays) do
    WeakAuras.SetIconNames(data);
  end
  for id, data in pairs(WeakAuras.regions) do
    if(data.region.SetStacks) then
      data.region:SetStacks(1);
    end
  end
  for id, child in pairs(displayButtons) do
    if(loaded[id]) then
      child:PriorityShow(1);
    end
  end
end

function WeakAuras.HideOptions()
  WeakAuras.UnlockUpdateInfo();
  if(frame) then
    frame:Hide();
  end
  wipe(displayButtons);
  for id, child in pairs(frame) do
    if(type(child) == table and child.Release) then
      child:Release();
    end
  end
  frame = nil;
  for id, data in pairs(WeakAuras.regions) do
    data.region:Collapse();
  end
  WeakAuras.ReloadAll();
  WeakAuras.Resume();
end

function WeakAuras.LockUpdateInfo()
  frame.elapsed = 12;
  frame.count = 0;
  frame:SetScript("OnUpdate", function(self, elapsed)
    frame.elapsed = frame.elapsed + elapsed;
    if(frame.elapsed > 1) then
      frame.elapsed = frame.elapsed - 1;
      frame.count = (frame.count + 1) % 4;
      for id, region in pairs(WeakAuras.regions) do
        local data = db.displays[id];
        if(data) then
          if(WeakAuras.CanHaveDuration(data)) then
            if(region.region.SetDurationInfo) then
              if not(frame.count ~= 0 and region.region.cooldown and region.region.cooldown:IsVisible()) then
                region.region:SetDurationInfo(12, GetTime() + 8 - (frame.count + frame.elapsed));
              end
            end
            WeakAuras.duration_cache:SetDurationInfo(id, 12, GetTime() + 8 - (frame.count + frame.elapsed));
          else
            if(region.region.SetDurationInfo) then
              region.region:SetDurationInfo(0, math.huge);
            end
            WeakAuras.duration_cache:SetDurationInfo(id, 0, math.huge);
          end
        end
      end
    end
  end);
end

function WeakAuras.UnlockUpdateInfo()
  frame:SetScript("OnUpdate", nil);
end

function WeakAuras.SetIconNames(data)
  WeakAuras.SetIconName(data, WeakAuras.regions[data.id].region);
  WeakAuras.SetIconName(data, thumbnails[data.id].region);
end

function WeakAuras.SetIconName(data, region)
  local name, icon;
  if(data.trigger.type == "aura" and not (data.trigger.inverse or WeakAuras.CanGroupShowWithZero(data))) then
    --Try to get an icon from the icon cache
    for index, checkname in pairs(data.trigger.names) do
      if(iconCache[checkname]) then
        name, icon = checkname, iconCache[checkname];
        break;
      end
    end
  elseif(data.trigger.type == "event" and data.trigger.event and WeakAuras.event_prototypes[data.trigger.event]) then
    if(WeakAuras.event_prototypes[data.trigger.event].iconFunc) then
      icon = WeakAuras.event_prototypes[data.trigger.event].iconFunc(data.trigger);
    end
    if(WeakAuras.event_prototypes[data.trigger.event].nameFunc) then
      name = WeakAuras.event_prototypes[data.trigger.event].nameFunc(data.trigger);
    end
  end
  
  if(region.SetIcon) then
    region:SetIcon(icon);
  end
  if(region.SetName) then
    region:SetName(name);
  end
end

function WeakAuras.BuildOptions()
  for id, data in pairs(db.displays) do
    if not(data.regionType == "group" or data.regionType == "dynamicgroup") then
      WeakAuras.AddOption(id, data);
    end
  end
  for id, data in pairs(db.displays) do
    if(data.regionType == "group" or data.regionType == "dynamicgroup") then
      WeakAuras.AddOption(id, data);
    end
  end
end

local function filterAnimPresetTypes(intable, id)
  local ret = {};
  local region = WeakAuras.regions[id] and WeakAuras.regions[id].region;
  local regionType = WeakAuras.regions[id] and WeakAuras.regions[id].regionType;
  local data = db.displays[id];
  if(region and regionType and data) then
    for key, value in pairs(intable) do
      local preset = WeakAuras.anim_presets[key];
      if(preset) then
        if(regionType == "group" or regionType == "dynamicgroup") then
          local valid = true;
          for index, childId in pairs(data.controlledChildren) do
            local childRegion = WeakAuras.regions[childId] and WeakAuras.regions[childId].region
            if(childRegion and ((preset.use_scale and not childRegion.Scale) or (preset.use_rotate and not childRegion.Rotate))) then
              valid = false;
            end
          end
          if(valid) then
            ret[key] = value;
          end
        else
          if not((preset.use_scale and not region.Scale) or (preset.use_rotate and not region.Rotate)) then
            ret[key] = value;
          end
        end
      end
    end
  end
  return ret;
end

local function removeFuncs(intable)
  for i,v in pairs(intable) do
    if(i == "get" or i == "set" or i == "hidden" or i == "disabled") then
      intable[i] = nil;
    elseif(type(v) == "table" and i ~= "values") then
      removeFuncs(v);
    end
  end
end

local function getAll(data, info)
  local combinedValues = {};
  local first = true;
  for index, childId in ipairs(data.controlledChildren) do
    local childData = WeakAuras.GetData(childId);
    if(childData) then
      local childOptions = displayOptions[childId];
      local childOption = childOptions;
      local childOptionTable = {[0] = childOption};
      for i=1,#info do
        childOption = childOption.args[info[i]];
        childOptionTable[i] = childOption;
      end
      for i=#childOptionTable,0,-1 do
        if(childOptionTable[i].get) then
          local values = {childOptionTable[i].get(info)};
          if(first) then
            combinedValues = values;
            first = false;
          else
            local same = true;
            if(#combinedValues == #values) then
              for j=1,#combinedValues do
                if(type(combinedValues[j]) == "number" and type(values[j]) == "number") then
                  if((math.floor(combinedValues[j] * 100) / 100) ~= (math.floor(values[j] * 100) / 100)) then
                    same = false;
                    break;
                  end
                else
                  if(combinedValues[j] ~= values[j]) then
                    same = false;
                    break;
                  end
                end
              end
            else
              same = false;
            end
            if not(same) then
              return nil;
            end
          end
          break;
        end
      end
    end
  end
  
  return unpack(combinedValues);
end

local function setAll(data, info, ...)
  for index, childId in ipairs(data.controlledChildren) do
    local childData = WeakAuras.GetData(childId);
    if(childData) then
      local childOptions = displayOptions[childId];
      local childOption = childOptions;
      local childOptionTable = {[0] = childOption};
      for i=1,#info do
        childOption = childOption.args[info[i]];
        childOptionTable[i] = childOption;
      end
      for i=#childOptionTable,0,-1 do
        if(childOptionTable[i].set) then
          childOptionTable[i].set(info, ...);
          break;
        end
      end
    end
  end
end

local function hiddenAll(data, info)
  if(#data.controlledChildren == 0 and info[1] ~= "group") then
    return true;
  end
  for index, childId in ipairs(data.controlledChildren) do
    local childData = WeakAuras.GetData(childId);
    if(childData) then
      local childOptions = displayOptions[childId];
      local childOption = childOptions;
      local childOptionTable = {[0] = childOption};
      for i=1,#info do
        childOption = childOption.args[info[i]];
        childOptionTable[i] = childOption;
      end
      for i=#childOptionTable,0,-1 do
        if(childOptionTable[i].hidden ~= nil) then
          if(type(childOptionTable[i].hidden) == "boolean") then
            if(childOptionTable[i].hidden) then
              return true;
            else
              return false;
            end
          elseif(type(childOptionTable[i].hidden) == "function") then
            if(childOptionTable[i].hidden(info)) then
              return true;
            end
          end
        end
      end
    end
  end
  
  return false;
end
  
local function disabledAll(data, info)
  for index, childId in ipairs(data.controlledChildren) do
    local childData = WeakAuras.GetData(childId);
    if(childData) then
      local childOptions = displayOptions[childId];
      local childOption = childOptions;
      local childOptionTable = {[0] = childOption};
      for i=1,#info do
        childOption = childOption.args[info[i]];
        childOptionTable[i] = childOption;
      end
      for i=#childOptionTable,0,-1 do
        if(childOptionTable[i].disabled ~= nil) then
          if(type(childOptionTable[i].disabled) == "boolean") then
            if(childOptionTable[i].disabled) then
              DebugFunction = childOptionTable[i].disabled
              return true;
            else
              return false;
            end
          elseif(type(childOptionTable[i].disabled) == "function") then
            if(childOptionTable[i].disabled(info)) then
              DebugFunction = childOptionTable[i].disabled
              return true;
            end
          end
        end
      end
    end
  end
  
  return false;
end

local function replaceNameDescFuncs(intable, data)
  local function sameAll(info)
    local combinedValues = {};
    local first = true;
    for index, childId in ipairs(data.controlledChildren) do
      local childData = WeakAuras.GetData(childId);
      if(childData) then
        local childOptions = displayOptions[childId];
        local childOption = childOptions;
        local childOptionTable = {[0] = childOption};
        for i=1,#info do
          childOption = childOption.args[info[i]];
          childOptionTable[i] = childOption;
        end
        for i=#childOptionTable,0,-1 do
          if(childOptionTable[i].get) then
            local values = {childOptionTable[i].get(info)};
            if(first) then
              combinedValues = values;
              first = false;
            else
              local same = true;
              if(#combinedValues == #values) then
                for j=1,#combinedValues do
                  if(type(combinedValues[j]) == "number" and type(values[j]) == "number") then
                    if((math.floor(combinedValues[j] * 100) / 100) ~= (math.floor(values[j] * 100) / 100)) then
                      same = false;
                      break;
                    end
                  else
                    if(combinedValues[j] ~= values[j]) then
                      same = false;
                      break;
                    end
                  end
                end
              else
                same = false;
              end
              if not(same) then
                return nil;
              end
            end
            break;
          end
        end
      end
    end
    
    return true;
  end
    
  local function nameAll(info)
    local combinedName;
    local first = true;
    for index, childId in ipairs(data.controlledChildren) do
      local childData = WeakAuras.GetData(childId);
      if(childData) then
        local childOption = displayOptions[childId];
        if not(childOption) then
          return "error 1";
        end
        for i=1,#info do
          childOption = childOption.args[info[i]];
          if not(childOption) then
            return "error 2 - "..childId.." - "..table.concat(info, ", ").." - "..i;
          end
        end
        local name;
        if(type(childOption.name) == "function") then
          name = childOption.name(info);
        else
          name = childOption.name;
        end
        if(first) then
          combinedName = name;
          first = false;
        elseif not(combinedName == name) then
          return childOption.name("default");
        end
      end
    end
    
    return combinedName;
  end
  
  local function descAll(info)
    local combinedDesc;
    local first = true;
    for index, childId in ipairs(data.controlledChildren) do
      local childData = WeakAuras.GetData(childId);
      if(childData) then
        local childOption = displayOptions[childId];
        if not(childOption) then
          return "error"
        end
        for i=1,#info do
          childOption = childOption.args[info[i]];
          if not(childOption) then
            return "error"
          end
        end
        local desc;
        if(type(childOption.desc) == "function") then
          desc = childOption.desc(info);
        else
          desc = childOption.desc;
        end
        if(first) then
          combinedDesc = desc;
          first = false;
        elseif not(combinedDesc == desc) then
          return L["Not all children have the same value for this option"];
        end
      end
    end
    
    return combinedDesc;
  end
  
  local function recurse(intable)
    for i,v in pairs(intable) do
      if(i == "name" and type(v) ~= "table") then
        intable.name = function(info)
          local name = nameAll(info);
          if(sameAll(info)) then
            return name;
          else
            if(name == "") then
              return name;
            else
              return "|cFF4080FF"..name;
            end
          end
        end
        intable.desc = function(info)
          if(sameAll(info)) then
            return descAll(info);
          else
            local values = {};
            for index, childId in ipairs(data.controlledChildren) do
              local childData = WeakAuras.GetData(childId);
              if(childData) then
                local childOptions = displayOptions[childId];
                local childOption = childOptions;
                local childOptionTable = {[0] = childOption};
                for i=1,#info do
                  childOption = childOption.args[info[i]];
                  childOptionTable[i] = childOption;
                end
                for i=#childOptionTable,0,-1 do
                  if(childOptionTable[i].get) then
                    if(intable.type == "toggle") then
                      local name, tri;
                      if(type(childOption.name) == "function") then
                        name = childOption.name(info);
                        tri = true;
                      else
                        name = childOption.name;
                      end
                      if(tri and childOptionTable[i].get(info)) then
                        tinsert(values, "|cFFE0E000"..childId..": |r"..name);
                      elseif(tri) then
                        tinsert(values, "|cFFE0E000"..childId..": |r"..L["Ignored"]);
                      elseif(childOptionTable[i].get(info)) then
                        tinsert(values, "|cFFE0E000"..childId..": |r|cFF00FF00"..L["Enabled"]);
                      else
                        tinsert(values, "|cFFE0E000"..childId..": |r|cFFFF0000"..L["Disabled"]);
                      end
                    elseif(intable.type == "color") then
                      local r, g, b = childOptionTable[i].get(info);
                      r, g, b = r or 1, g or 1, b or 1;
                      tinsert(values, ("|cFF%2x%2x%2x%s"):format(r * 220 + 35, g * 220 + 35, b * 220 + 35, childId));
                    elseif(intable.type == "select") then
                      local selectValues = type(intable.values) == "table" and intable.values or intable.values();
                      local key = childOptionTable[i].get(info);
                      local display = key and selectValues[key] or L["None"];
                      tinsert(values, "|cFFE0E000"..childId..": |r"..display);
                    else
                      local display = childOptionTable[i].get(info) or L["None"];
                      if(type(display) == "number") then
                        display = math.floor(display * 100) / 100;
                      end
                      tinsert(values, "|cFFE0E000"..childId..": |r"..display);
                    end
                    break;
                  end
                end
              end
            end
            return table.concat(values, "\n");
          end
        end
      elseif(type(v) == "table" and i ~= "values") then
        recurse(v);
      end
    end
  end
  recurse(intable);
end

local function replaceImageFuncs(intable, data)
  local function imageAll(info)
    local combinedImage = {};
    local first = true;
    for index, childId in ipairs(data.controlledChildren) do
      local childData = WeakAuras.GetData(childId);
      if(childData) then
        local childOption = displayOptions[childId];
        if not(childOption) then
          return "error"
        end
        for i=1,#info do
          childOption = childOption.args[info[i]];
          if not(childOption) then
            return "error"
          end
        end
        local image;
        if not(childOption.image) then
          return "", 0, 0;
        else
          image = {childOption.image(info)};
        end
        if(first) then
          combinedImage = image;
          first = false;
        else
          if not(combinedImage[1] == image[1]) then
            return "", 0, 0;
          end
        end
      end
    end
    
    return unpack(combinedImage);
  end
  
  local function recurse(intable)
    for i,v in pairs(intable) do
      if(i == "image" and type(v) == "function") then
        intable[i] = imageAll;
      elseif(type(v) == "table" and i ~= "values") then
        recurse(v);
      end
    end
  end
  recurse(intable);
end

function WeakAuras.AddOption(id, data)
  local regionOption;
  if(regionOptions[data.regionType]) then
    regionOption = regionOptions[data.regionType].create(id, data);
  else
    regionOption = {
      unsupported = {
        type = "description",
        name = L["This region of type \"%s\" has no configuration options."]:format(data.regionType)
      }
    };
  end
  
  displayOptions[id] = {
    type = "group",
    childGroups = "tab",
    args = {
      region = {
        type = "group",
        name = L["Display"],
        order = 10,
        get = function(info)
          if(info.type == "color") then
            data[info[#info]] = data[info[#info]] or {};
            local c = data[info[#info]];
            return c[1], c[2], c[3], c[4];
          else
            return data[info[#info]];
          end
        end,
        set = function(info, v, g, b, a)
          if(info.type == "color") then
            data[info[#info]] = data[info[#info]] or {};
            local c = data[info[#info]];
            c[1], c[2], c[3], c[4] = v, g, b, a;
          elseif(info.type == "toggle") then
            data[info[#info]] = v;
          else
            data[info[#info]] = (v ~= "" and v) or nil;
          end
          WeakAuras.Add(data);
          WeakAuras.SetThumbnail(data);
          WeakAuras.SetIconNames(data);
          if(data.parent) then
            local parentData = WeakAuras.GetData(data.parent);
            if(parentData) then
              WeakAuras.Add(parentData);
              WeakAuras.SetThumbnail(parentData);
            end
          end
          WeakAuras.ResetMoverSizer();
        end,
        args = regionOption
      },
      trigger = {
        type = "group",
        name = L["Trigger"],
        order = 20,
        args = {}
      },
      load = {
        type = "group",
        name = L["Load"],
        order = 30,
        get = function(info) return data.load[info[#info]] end,
        set = function(info, v)
          data.load[info[#info]] = (v ~= "" and v) or nil;
          WeakAuras.Add(data);
          WeakAuras.SetThumbnail(data);
          WeakAuras.ScanForLoads();
          WeakAuras.SortDisplayButtons();
        end,
        args = {}
      },
      action = {
        type = "group",
        name = L["Actions"],
        order = 50,
        get = function(info)
          local split = info[#info]:find("_");
          if(split) then
            local field, value = info[#info]:sub(1, split-1), info[#info]:sub(split+1);
            if(data.actions and data.actions[field]) then
              return data.actions[field][value];
            else
              return nil;
            end
          end
        end,
        set = function(info, v)
          local split = info[#info]:find("_");
          local field, value = info[#info]:sub(1, split-1), info[#info]:sub(split+1);
          data.actions = data.actions or {};
          data.actions[field] = data.actions[field] or {};
          data.actions[field][value] = v;
          if(value == "sound" or value == "sound_path") then
            PlaySoundFile(v);
          end
        end,
        args = {
          start_header = {
            type = "header",
            name = L["On Show"],
            order = 0.5
          },
          start_do_message = {
            type = "toggle",
            name = L["Chat Message"],
            order = 1
          },
          start_message_type = {
            type = "select",
            name = L["Message Type"],
            order = 2,
            values = send_chat_message_types,
            disabled = function() return not data.actions.start.do_message end
          },
          start_message_space = {
            type = "execute",
            name = "",
            order = 3,
            image = function() return "", 0, 0 end,
            hidden = function() return not(data.actions.start.message_type == "WHISPER" or data.actions.start.message_type == "CHANNEL") end
          },
          start_message_dest = {
            type = "input",
            name = L["Send To"],
            order = 4,
            disabled = function() return not data.actions.start.do_message end,
            hidden = function() return data.actions.start.message_type ~= "WHISPER" end
          },
          start_message_channel = {
            type = "input",
            name = L["Channel Number"],
            order = 4,
            disabled = function() return not data.actions.start.do_message end,
            hidden = function() return data.actions.start.message_type ~= "CHANNEL" end
          },
          start_message = {
            type = "input",
            name = L["Message"],
            width = "double",
            order = 5,
            disabled = function() return not data.actions.start.do_message end
          },
          start_do_sound = {
            type = "toggle",
            name = L["Play Sound"],
            order = 7
          },
          start_sound = {
            type = "select",
            name = L["Sound"],
            order = 8,
            values = sound_types,
            disabled = function() return not data.actions.start.do_sound end
          },
          start_sound_path = {
            type = "input",
            name = L["Sound File Path"],
            order = 9,
            width = "double",
            hidden = function() return data.actions.start.sound ~= " custom" end,
            disabled = function() return not data.actions.start.do_sound end
          },
          start_do_custom = {
            type = "toggle",
            name = L["Custom"],
            order = 11,
            width = "double"
          },
          start_custom = {
            type = "input",
            name = L["Custom Code"],
            order = 13,
            multiline = true,
            width = "double",
            hidden = function() return not data.actions.start.do_custom end
          },
          start_customError = {
            type = "description",
            name = function()
              if not(data.actions.start.custom) then
                return "";
              end
              local _, errorString = loadstring("return function() "..data.actions.start.custom.." end");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 15,
            hidden = function()
              if not(data.actions.start.do_custom and data.actions.start.custom) then
                return true;
              else
                local loadedFunction, errorString = loadstring("return function() "..data.actions.start.custom.." end");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          finish_header = {
            type = "header",
            name = L["On Hide"],
            order = 20.5
          },
          finish_do_message = {
            type = "toggle",
            name = L["Chat Message"],
            order = 21
          },
          finish_message_type = {
            type = "select",
            name = L["Message Type"],
            order = 22,
            values = send_chat_message_types,
            disabled = function() return not data.actions.finish.do_message end
          },
          finish_message_space = {
            type = "execute",
            name = "",
            order = 23,
            image = function() return "", 0, 0 end,
            hidden = function() return not(data.actions.finish.message_type == "WHISPER" or data.actions.finish.message_type == "CHANNEL") end
          },
          finish_message_dest = {
            type = "input",
            name = L["Send To"],
            order = 24,
            disabled = function() return not data.actions.finish.do_message end,
            hidden = function() return data.actions.finish.message_type ~= "WHISPER" end
          },
          finish_message_channel = {
            type = "input",
            name = L["Channel Number"],
            order = 24,
            disabled = function() return not data.actions.finish.do_message end,
            hidden = function() return data.actions.finish.message_type ~= "CHANNEL" end
          },
          finish_message = {
            type = "input",
            name = L["Message"],
            width = "double",
            order = 25,
            disabled = function() return not data.actions.finish.do_message end
          },
          finish_do_sound = {
            type = "toggle",
            name = L["Play Sound"],
            order = 27
          },
          finish_sound = {
            type = "select",
            name = L["Sound"],
            order = 28,
            values = sound_types,
            disabled = function() return not data.actions.finish.do_sound end
          },
          finish_sound_path = {
            type = "input",
            name = L["Sound File Path"],
            order = 29,
            width = "double",
            hidden = function() return data.actions.finish.sound ~= " custom" end,
            disabled = function() return not data.actions.finish.do_sound end
          },
          finish_do_custom = {
            type = "toggle",
            name = L["Custom"],
            order = 31,
            width = "double"
          },
          finish_custom = {
            type = "input",
            name = L["Custom Code"],
            order = 33,
            multiline = true,
            width = "double",
            hidden = function() return not data.actions.finish.do_custom end
          },
          finish_customError = {
            type = "description",
            name = function()
              if not(data.actions.finish.custom) then
                return "";
              end
              local _, errorString = loadstring("return function() "..data.actions.finish.custom.." end");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 35,
            hidden = function()
              if not(data.actions.finish.do_custom and data.actions.finish.custom) then
                return true;
              else
                local loadedFunction, errorString = loadstring("return function() "..data.actions.finish.custom.." end");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          }
        }
      },
      animation = {
        type = "group",
        name = L["Animations"],
        order = 60,
        get = function(info)
          local split = info[#info]:find("_");
          if(split) then
            local field, value = info[#info]:sub(1, split-1), info[#info]:sub(split+1);
            
            if(data.animation and data.animation[field]) then
              return data.animation[field][value];
            else
              if(value == "scalex" or value == "scaley") then
                return 1;
              else
                return nil;
              end
            end
          end
        end,
        set = function(info, v)
          local split = info[#info]:find("_");
          local field, value = info[#info]:sub(1, split-1), info[#info]:sub(split+1);
          data.animation = data.animation or {};
          data.animation[field] = data.animation[field] or {};
          data.animation[field][value] = v;
          if(field == "main" and not WeakAuras.IsAnimating("display", id)) then
            WeakAuras.Animate("display", id, "main", data.animation.main, WeakAuras.regions[id].region, false, nil, true);
          end
          WeakAuras.Add(data);
        end,
        disabled = function(info, v)
          local split = info[#info]:find("_");
          local valueToType = {
            alphaType = "use_alpha",
            alpha = "use_alpha",
            translateType = "use_translate",
            x = "use_translate",
            y = "use_translate",
            scaleType = "use_scale",
            scalex = "use_scale",
            scaley = "use_scale",
            rotateType = "use_rotate",
            rotate = "use_rotate"
          }
          if(split) then
            local field, value = info[#info]:sub(1, split-1), info[#info]:sub(split+1);
            if(data.animation and data.animation[field]) then
              if(valueToType[value]) then
                return not data.animation[field][valueToType[value]];
              else
                return false;
              end
            else
              return true;
            end
          else
            return false;
          end
        end,
        args = {
          start_header = {
            type = "header",
            name = L["Start"],
            order = 30
          },
          start_type = {
            type = "select",
            name = L["Type"],
            order = 32,
            values = anim_types,
            disabled = false
          },
          start_preset = {
            type = "select",
            name = L["Preset"],
            order = 33,
            values = function() return filterAnimPresetTypes(anim_start_preset_types, id) end,
            hidden = function() return data.animation.start.type ~= "preset" end
          },
          start_duration_type_no_choice = {
            type = "select",
            name = L["Time in"],
            order = 33,
            width = "half",
            values = duration_types_no_choice,
            disabled = true,
            hidden = function() return data.animation.start.type ~= "custom" or WeakAuras.CanHaveDuration(data) end,
            get = function() return "seconds" end
          },
          start_duration_type = {
            type = "select",
            name = L["Time in"],
            order = 33,
            width = "half",
            values = duration_types,
            hidden = function() return data.animation.start.type ~= "custom" or not WeakAuras.CanHaveDuration(data) end
          },
          start_duration = {
            type = "input",
            name = function()
              if(data.animation.start.duration_type == "relative") then
                return L["% of Progress"];
              else
                return L["Duration (s)"];
              end
            end,
            desc = function()
              if(data.animation.start.duration_type == "relative") then
                return L["Animation relative duration description"];
              else
                return L["The duration of the animation in seconds."];
              end
            end,
            order = 33.5,
            width = "half",
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_use_alpha = {
            type = "toggle",
            name = L["Fade In"],
            order = 34,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_alphaType = {
            type = "select",
            name = L["Type"],
            order = 35,
            values = anim_alpha_types,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_alphaFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 35.3,
            hidden = function() return data.animation.start.type ~= "custom" or data.animation.start.alphaType ~= "custom" or not data.animation.start.use_alpha end,
            get = function() return data.animation.start.alphaFunc and data.animation.start.alphaFunc:sub(8); end,
            set = function(info, v) data.animation.start.alphaFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          start_alphaFuncError = {
            type = "description",
            name = function()
              if not(data.animation.start.alphaFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.start.alphaFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 35.6,
            hidden = function()
              if(data.animation.start.type ~= "custom" or data.animation.start.alphaType ~= "custom" or not data.animation.start.use_alpha) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.start.alphaFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          start_alpha = {
            type = "range",
            name = L["Alpha"],
            width = "double",
            order = 36,
            min = 0,
            max = 1,
            bigStep = 0.01,
            isPercent = true,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_use_translate = {
            type = "toggle",
            name = L["Slide In"],
            order = 38,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_translateType = {
            type = "select",
            name = L["Type"],
            order = 39,
            values = anim_translate_types,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_translateFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 39.3,
            hidden = function() return data.animation.start.type ~= "custom" or data.animation.start.translateType ~= "custom" or not data.animation.start.use_translate end,
            get = function() return data.animation.start.translateFunc and data.animation.start.translateFunc:sub(8); end,
            set = function(info, v) data.animation.start.translateFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          start_translateFuncError = {
            type = "description",
            name = function()
              if not(data.animation.start.translateFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.start.translateFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 39.6,
            hidden = function()
              if(data.animation.start.type ~= "custom" or data.animation.start.translateType ~= "custom" or not data.animation.start.use_translate) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.start.translateFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          start_x = {
            type = "range",
            name = L["X Offset"],
            order = 40,
            softMin = -200,
            softMax = 200,
            step = 1,
            bigStep = 5,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_y = {
            type = "range",
            name = L["Y Offset"],
            order = 41,
            softMin = -200,
            softMax = 200,
            step = 1,
            bigStep = 5,
            hidden = function() return data.animation.start.type ~= "custom" end
          },
          start_use_scale = {
            type = "toggle",
            name = L["Zoom In"],
            order = 42,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          start_scaleType = {
            type = "select",
            name = L["Type"],
            order = 43,
            values = anim_scale_types,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          start_scaleFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 43.3,
            hidden = function() return data.animation.start.type ~= "custom" or data.animation.start.scaleType ~= "custom" or not (data.animation.start.use_scale and WeakAuras.regions[id].region.Scale) end,
            get = function() return data.animation.start.scaleFunc and data.animation.start.scaleFunc:sub(8); end,
            set = function(info, v) data.animation.start.scaleFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          start_scaleFuncError = {
            type = "description",
            name = function()
              if not(data.animation.start.scaleFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.start.scaleFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 43.6,
            hidden = function()
              if(data.animation.start.type ~= "custom" or data.animation.start.scaleType ~= "custom" or not (data.animation.start.use_scale and WeakAuras.regions[id].region.Scale)) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.start.scaleFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          start_scalex = {
            type = "range",
            name = L["X Scale"],
            order = 44,
            softMin = 0,
            softMax = 5,
            step = 0.01,
            bigStep = 0.1,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          start_scaley = {
            type = "range",
            name = L["Y Scale"],
            order = 45,
            softMin = 0,
            softMax = 5,
            step = 0.01,
            bigStep = 0.1,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          start_use_rotate = {
            type = "toggle",
            name = L["Rotate In"],
            order = 46,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          start_rotateType = {
            type = "select",
            name = L["Type"],
            order = 47,
            values = anim_rotate_types,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          start_rotateFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 47.3,
            hidden = function() return data.animation.start.type ~= "custom" or data.animation.start.rotateType ~= "custom" or not (data.animation.start.use_rotate and WeakAuras.regions[id].region.Rotate) end,
            get = function() return data.animation.start.rotateFunc and data.animation.start.rotateFunc:sub(8); end,
            set = function(info, v) data.animation.start.rotateFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          start_rotateFuncError = {
            type = "description",
            name = function()
              if not(data.animation.start.rotateFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.start.rotateFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 47.6,
            hidden = function()
              if(data.animation.start.type ~= "custom" or data.animation.start.rotateType ~= "custom" or not (data.animation.start.use_rotate and WeakAuras.regions[id].region.Rotate)) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.start.rotateFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          start_rotate = {
            type = "range",
            name = L["Angle"],
            width = "double",
            order = 48,
            softMin = 0,
            softMax = 360,
            bigStep = 3,
            hidden = function() return (data.animation.start.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          main_header = {
            type = "header",
            name = L["Main"],
            order = 50
          },
          main_type = {
            type = "select",
            name = L["Type"],
            order = 52,
            values = anim_types,
            disabled = false
          },
          main_preset = {
            type = "select",
            name = L["Preset"],
            order = 53,
            values = function() return filterAnimPresetTypes(anim_main_preset_types, id) end,
            hidden = function() return data.animation.main.type ~= "preset" end
          },
          main_duration_type_no_choice = {
            type = "select",
            name = L["Time in"],
            order = 53,
            width = "half",
            values = duration_types_no_choice,
            disabled = true,
            hidden = function() return data.animation.main.type ~= "custom" or WeakAuras.CanHaveDuration(data) end,
            get = function() return "seconds" end
          },
          main_duration_type = {
            type = "select",
            name = L["Time in"],
            order = 53,
            width = "half",
            values = duration_types,
            hidden = function() return data.animation.main.type ~= "custom" or not WeakAuras.CanHaveDuration(data) end
          },
          main_duration = {
            type = "input",
            name = function()
              if(data.animation.main.duration_type == "relative") then
                return L["% of Progress"];
              else
                return L["Duration (s)"];
              end
            end,
            desc = function()
              if(data.animation.main.duration_type == "relative") then
                return L["Animation relative duration description"];
              else
                local ret = "";
                ret = ret..L["The duration of the animation in seconds."].."\n";
                ret = ret..L["Unlike the start or finish animations, the main animation will loop over and over until the display is hidden."]
                return ret;
              end
            end,
            order = 53.5,
            width = "half",
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_use_alpha = {
            type = "toggle",
            name = L["Fade"],
            order = 54,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_alphaType = {
            type = "select",
            name = L["Type"],
            order = 55,
            values = anim_alpha_types,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_alphaFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 55.3,
            hidden = function() return data.animation.main.type ~= "custom" or data.animation.main.alphaType ~= "custom" or not data.animation.main.use_alpha end,
            get = function() return data.animation.main.alphaFunc and data.animation.main.alphaFunc:sub(8); end,
            set = function(info, v) data.animation.main.alphaFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          main_alphaFuncError = {
            type = "description",
            name = function()
              if not(data.animation.main.alphaFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.main.alphaFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 55.6,
            hidden = function()
              if(data.animation.main.type ~= "custom" or data.animation.main.alphaType ~= "custom" or not data.animation.main.use_alpha) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.main.alphaFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          main_alpha = {
            type = "range",
            name = L["Alpha"],
            width = "double",
            order = 56,
            min = 0,
            max = 1,
            bigStep = 0.01,
            isPercent = true,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_use_translate = {
            type = "toggle",
            name = L["Slide"],
            order = 58,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_translateType = {
            type = "select",
            name = L["Type"],
            order = 59,
            values = anim_translate_types,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_translateFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 59.3,
            hidden = function() return data.animation.main.type ~= "custom" or data.animation.main.translateType ~= "custom" or not data.animation.main.use_translate end,
            get = function() return data.animation.main.translateFunc and data.animation.main.translateFunc:sub(8); end,
            set = function(info, v) data.animation.main.translateFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          main_translateFuncError = {
            type = "description",
            name = function()
              if not(data.animation.main.translateFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.main.translateFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 59.6,
            hidden = function()
              if(data.animation.main.type ~= "custom" or data.animation.main.translateType ~= "custom" or not data.animation.main.use_translate) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.main.translateFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          main_x = {
            type = "range",
            name = L["X Offset"],
            order = 60,
            softMin = -200,
            softMax = 200,
            step = 1,
            bigStep = 5,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_y = {
            type = "range",
            name = L["Y Offset"],
            order = 61,
            softMin = -200,
            softMax = 200,
            step = 1,
            bigStep = 5,
            hidden = function() return data.animation.main.type ~= "custom" end
          },
          main_use_scale = {
            type = "toggle",
            name = L["Zoom"],
            order = 62,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          main_scaleType = {
            type = "select",
            name = L["Type"],
            order = 63,
            values = anim_scale_types,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          main_scaleFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 63.3,
            hidden = function() return data.animation.main.type ~= "custom" or data.animation.main.scaleType ~= "custom" or not (data.animation.main.use_scale and WeakAuras.regions[id].region.Scale) end,
            get = function() return data.animation.main.scaleFunc and data.animation.main.scaleFunc:sub(8); end,
            set = function(info, v) data.animation.main.scaleFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          main_scaleFuncError = {
            type = "description",
            name = function()
              if not(data.animation.main.scaleFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.main.scaleFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 63.6,
            hidden = function()
              if(data.animation.main.type ~= "custom" or data.animation.main.scaleType ~= "custom" or not (data.animation.main.use_scale and WeakAuras.regions[id].region.Scale)) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.main.scaleFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          main_scalex = {
            type = "range",
            name = L["X Scale"],
            order = 64,
            softMin = 0,
            softMax = 5,
            step = 0.01,
            bigStep = 0.1,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          main_scaley = {
            type = "range",
            name = L["Y Scale"],
            order = 65,
            softMin = 0,
            softMax = 5,
            step = 0.01,
            bigStep = 0.1,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          main_use_rotate = {
            type = "toggle",
            name = L["Rotate"],
            order = 66,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          main_rotateType = {
            type = "select",
            name = L["Type"],
            order = 67,
            values = anim_rotate_types,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          main_rotateFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 47.3,
            hidden = function() return data.animation.main.type ~= "custom" or data.animation.main.rotateType ~= "custom" or not (data.animation.main.use_rotate and WeakAuras.regions[id].region.Rotate) end,
            get = function() return data.animation.main.rotateFunc and data.animation.main.rotateFunc:sub(8); end,
            set = function(info, v) data.animation.main.rotateFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          main_rotateFuncError = {
            type = "description",
            name = function()
              if not(data.animation.main.rotateFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.main.rotateFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 47.6,
            hidden = function()
              if(data.animation.main.type ~= "custom" or data.animation.main.rotateType ~= "custom" or not (data.animation.main.use_rotate and WeakAuras.regions[id].region.Rotate)) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.main.rotateFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          main_rotate = {
            type = "range",
            name = L["Angle"],
            width = "double",
            order = 68,
            softMin = 0,
            softMax = 360,
            bigStep = 3,
            hidden = function() return (data.animation.main.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          finish_header = {
            type = "header",
            name = L["Finish"],
            order = 70
          },
          finish_type = {
            type = "select",
            name = L["Type"],
            order = 72,
            values = anim_types,
            disabled = false
          },
          finish_preset = {
            type = "select",
            name = L["Preset"],
            order = 73,
            values = function() return filterAnimPresetTypes(anim_finish_preset_types, id) end,
            hidden = function() return data.animation.finish.type ~= "preset" end
          },
          finish_duration_type_no_choice = {
            type = "select",
            name = L["Time in"],
            order = 73,
            width = "half",
            values = duration_types_no_choice,
            disabled = true,
            hidden = function() return data.animation.finish.type ~= "custom" end,
            get = function() return "seconds" end
          },
          finish_duration = {
            type = "input",
            name = L["Duration (s)"],
            desc = "The duration of the animation in seconds.\n\nThe finish animation does not start playing until after the display would normally be hidden.",
            order = 73.5,
            width = "half",
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_use_alpha = {
            type = "toggle",
            name = L["Fade Out"],
            order = 74,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_alphaType = {
            type = "select",
            name = L["Type"],
            order = 75,
            values = anim_alpha_types,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_alphaFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 75.3,
            hidden = function() return data.animation.finish.type ~= "custom" or data.animation.finish.alphaType ~= "custom" or not data.animation.finish.use_alpha end,
            get = function() return data.animation.finish.alphaFunc and data.animation.finish.alphaFunc:sub(8); end,
            set = function(info, v) data.animation.finish.alphaFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          finish_alphaFuncError = {
            type = "description",
            name = function()
              if not(data.animation.finish.alphaFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.finish.alphaFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 75.6,
            hidden = function()
              if(data.animation.finish.type ~= "custom" or data.animation.finish.alphaType ~= "custom" or not data.animation.finish.use_alpha) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.finish.alphaFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          finish_alpha = {
            type = "range",
            name = L["Alpha"],
            width = "double",
            order = 76,
            min = 0,
            max = 1,
            bigStep = 0.01,
            isPercent = true,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_use_translate = {
            type = "toggle",
            name = L["Slide Out"],
            order = 78,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_translateType = {
            type = "select",
            name = L["Type"],
            order = 79,
            values = anim_translate_types,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_translateFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 59.3,
            hidden = function() return data.animation.finish.type ~= "custom" or data.animation.finish.translateType ~= "custom" or not data.animation.finish.use_translate end,
            get = function() return data.animation.finish.translateFunc and data.animation.finish.translateFunc:sub(8); end,
            set = function(info, v) data.animation.finish.translateFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          finish_translateFuncError = {
            type = "description",
            name = function()
              if not(data.animation.finish.translateFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.finish.translateFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 59.6,
            hidden = function()
              if(data.animation.finish.type ~= "custom" or data.animation.finish.translateType ~= "custom" or not data.animation.finish.use_translate) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.finish.translateFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          finish_x = {
            type = "range",
            name = L["X Offset"],
            order = 80,
            softMin = -200,
            softMax = 200,
            step = 1,
            bigStep = 5,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_y = {
            type = "range",
            name = L["Y Offset"],
            order = 81,
            softMin = -200,
            softMax = 200,
            step = 1,
            bigStep = 5,
            hidden = function() return data.animation.finish.type ~= "custom" end
          },
          finish_use_scale = {
            type = "toggle",
            name = L["Zoom Out"],
            order = 82,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          finish_scaleType = {
            type = "select",
            name = L["Type"],
            order = 83,
            values = anim_scale_types,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          finish_scaleFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 63.3,
            hidden = function() return data.animation.finish.type ~= "custom" or data.animation.finish.scaleType ~= "custom" or not (data.animation.finish.use_scale and WeakAuras.regions[id].region.Scale) end,
            get = function() return data.animation.finish.scaleFunc and data.animation.finish.scaleFunc:sub(8); end,
            set = function(info, v) data.animation.finish.scaleFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          finish_scaleFuncError = {
            type = "description",
            name = function()
              if not(data.animation.finish.scaleFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.finish.scaleFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 63.6,
            hidden = function()
              if(data.animation.finish.type ~= "custom" or data.animation.finish.scaleType ~= "custom" or not (data.animation.finish.use_scale and WeakAuras.regions[id].region.Scale)) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.finish.scaleFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          finish_scalex = {
            type = "range",
            name = L["X Scale"],
            order = 84,
            softMin = 0,
            softMax = 5,
            step = 0.01,
            bigStep = 0.1,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          finish_scaley = {
            type = "range",
            name = L["Y Scale"],
            order = 85,
            softMin = 0,
            softMax = 5,
            step = 0.01,
            bigStep = 0.1,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Scale) end
          },
          finish_use_rotate = {
            type = "toggle",
            name = L["Rotate Out"],
            order = 86,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          finish_rotateType = {
            type = "select",
            name = L["Type"],
            order = 87,
            values = anim_rotate_types,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          },
          finish_rotateFunc = {
            type = "input",
            multiline = true,
            name = L["Custom Function"],
            width = "double",
            order = 47.3,
            hidden = function() return data.animation.finish.type ~= "custom" or data.animation.finish.rotateType ~= "custom" or not (data.animation.finish.use_rotate and WeakAuras.regions[id].region.Rotate) end,
            get = function() return data.animation.finish.rotateFunc and data.animation.finish.rotateFunc:sub(8); end,
            set = function(info, v) data.animation.finish.rotateFunc = "return "..(v or ""); WeakAuras.Add(data); end
          },
          finish_rotateFuncError = {
            type = "description",
            name = function()
              if not(data.animation.finish.rotateFunc) then
                return "";
              end
              local _, errorString = loadstring(data.animation.finish.rotateFunc or "");
              return errorString and "|cFFFF0000"..errorString or "";
            end,
            width = "double",
            order = 47.6,
            hidden = function()
              if(data.animation.finish.type ~= "custom" or data.animation.finish.rotateType ~= "custom" or not (data.animation.finish.use_rotate and WeakAuras.regions[id].region.Rotate)) then
                return true;
              else
                local loadedFunction, errorString = loadstring(data.animation.finish.rotateFunc or "");
                if(errorString and not loadedFunction) then
                  return false;
                else
                  return true;
                end
              end
            end
          },
          finish_rotate = {
            type = "range",
            name = L["Angle"],
            width = "double",
            order = 88,
            softMin = 0,
            softMax = 360,
            bigStep = 3,
            hidden = function() return (data.animation.finish.type ~= "custom" or not WeakAuras.regions[id].region.Rotate) end
          }
        }
      }
    }
  };
  
  WeakAuras.ReloadTriggerOptions(data);
end

local function unused()
end

function WeakAuras.ReloadTriggerOptions(data)
  local id = data.id;
  local trigger, untrigger;
  if(data.controlledChildren) then
    optionTriggerChoices[id] = nil;
    for index, childId in pairs(data.controlledChildren) do
      if not(optionTriggerChoices[id]) then
        optionTriggerChoices[id] = optionTriggerChoices[childId];
        trigger = WeakAuras.GetData(childId).trigger;
        untrigger = WeakAuras.GetData(childId).untrigger;
      else
        if(optionTriggerChoices[id] ~= optionTriggerChoices[childId]) then
          trigger, untrigger = {}, {};
          optionTriggerChoices[id] = -1;
          break;
        end
      end
    end
    
    optionTriggerChoices[id] = optionTriggerChoices[id] or 0;
    
    if(optionTriggerChoices[id] >= 0) then
      for index, childId in pairs(data.controlledChildren) do
        local childData = WeakAuras.GetData(childId);
        if(childData) then
          optionTriggerChoices[childId] = optionTriggerChoices[id];
          WeakAuras.ReloadTriggerOptions(childData);
        end
      end
    end
  else
    optionTriggerChoices[id] = optionTriggerChoices[id] or 0;
    if(optionTriggerChoices[id] == 0) then
      trigger = data.trigger;
      untrigger = data.untrigger;
    else
      trigger = data.additional_triggers[optionTriggerChoices[id]].trigger or data.trigger;
      untrigger = data.additional_triggers[optionTriggerChoices[id]].untrigger or data.untrigger;
    end
  end
  
  local aura_options = {
    useName = {
      type = "toggle",
      name = L["Aura(s)"],
      width = "half",
      order = 10,
      hidden = function() return not (trigger.type == "aura"); end,
      disabled = true,
      get = function() return true end
    },
    name1icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[1]] or "", 18, 18 end,
      order = 11,
      disabled = function() return not iconCache[trigger.names[1]] end,
      hidden = function() return not (trigger.type == "aura"); end
    },
    name1 = {
      type = "input",
      name = L["Aura Name"],
      desc = L["Enter an aura name, partial aura name, or spell id"],
      order = 12,
      hidden = function() return not (trigger.type == "aura"); end,
      get = function(info) return trigger.names[1] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[1]) then
            tremove(trigger.names, 1);
          end
        else
          trigger.names[1] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name2space = {
      type = "execute",
      name = L["or"],
      width = "half",
      image = function() return "", 0, 0 end,
      order = 13,
      hidden = function() return not (trigger.type == "aura" and trigger.names[1]); end,
    },
    name2icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[2]] or "", 18, 18 end,
      order = 14,
      disabled = function() return not iconCache[trigger.names[2]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[1]); end,
    },
    name2 = {
      type = "input",
      order = 15,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[1]); end,
      get = function(info) return trigger.names[2] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[2]) then
            tremove(trigger.names, 2);
          end
        else
          trigger.names[2] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name3space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 16,
      hidden = function() return not (trigger.type == "aura" and trigger.names[2]); end,
    },
    name3icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[3]] or "", 18, 18 end,
      order = 17,
      disabled = function() return not iconCache[trigger.names[3]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[2]); end,
    },
    name3 = {
      type = "input",
      order = 18,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[2]); end,
      get = function(info) return trigger.names[3] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[3]) then
            tremove(trigger.names, 3);
          end
        else
          trigger.names[3] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name4space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 19,
      hidden = function() return not (trigger.type == "aura" and trigger.names[3]); end,
    },
    name4icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[4]] or "", 18, 18 end,
      order = 20,
      disabled = function() return not iconCache[trigger.names[4]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[3]); end,
    },
    name4 = {
      type = "input",
      order = 21,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[3]); end,
      get = function(info) return trigger.names[4] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[4]) then
            tremove(trigger.names, 4);
          end
        else
          trigger.names[4] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name5space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 22,
      disabled = function() return not iconCache[trigger.names[5]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[4]); end,
    },
    name5icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[5]] or "", 18, 18 end,
      order = 23,
      hidden = function() return not (trigger.type == "aura" and trigger.names[4]); end,
    },
    name5 = {
      type = "input",
      order = 24,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[4]); end,
      get = function(info) return trigger.names[5] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[5]) then
            tremove(trigger.names, 5);
          end
        else
          trigger.names[5] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name6space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 25,
      hidden = function() return not (trigger.type == "aura" and trigger.names[5]); end,
    },
    name6icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[6]] or "", 18, 18 end,
      order = 26,
      disabled = function() return not iconCache[trigger.names[6]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[5]); end,
    },
    name6 = {
      type = "input",
      order = 27,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[5]); end,
      get = function(info) return trigger.names[6] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[6]) then
            tremove(trigger.names, 6);
          end
        else
          trigger.names[6] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name7space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 28,
      hidden = function() return not (trigger.type == "aura" and trigger.names[6]); end,
    },
    name7icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[7]] or "", 18, 18 end,
      order = 29,
      disabled = function() return not iconCache[trigger.names[7]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[6]); end,
    },
    name7 = {
      type = "input",
      order = 30,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[6]); end,
      get = function(info) return trigger.names[7] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[7]) then
            tremove(trigger.names, 7);
          end
        else
          trigger.names[7] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name8space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 31,
      hidden = function() return not (trigger.type == "aura" and trigger.names[7]); end,
    },
    name8icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[8]] or "", 18, 18 end,
      order = 32,
      disabled = function() return not iconCache[trigger.names[8]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[7]); end,
    },
    name8 = {
      type = "input",
      order = 33,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[7]); end,
      get = function(info) return trigger.names[8] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[8]) then
            tremove(trigger.names, 8);
          end
        else
          trigger.names[8] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    name9space = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return "", 0, 0 end,
      order = 34,
      hidden = function() return not (trigger.type == "aura" and trigger.names[8]); end,
    },
    name9icon = {
      type = "execute",
      name = "",
      width = "half",
      image = function() return iconCache[trigger.names[9]] or "", 18, 18 end,
      order = 35,
      disabled = function() return not iconCache[trigger.names[9]] end,
      hidden = function() return not (trigger.type == "aura" and trigger.names[8]); end,
    },
    name9 = {
      type = "input",
      order = 36,
      name = "",
      hidden = function() return not (trigger.type == "aura" and trigger.names[8]); end,
      get = function(info) return trigger.names[9] end,
      set = function(info, v)
        if(v == "") then
          if(trigger.names[9]) then
            tremove(trigger.names, 9);
          end
        else
          trigger.names[9] = WeakAuras.CorrectAuraName(v);
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.UpdateDisplayButton(data);
      end,
    },
    useUnit = {
      type = "toggle",
      name = L["Unit"],
      order = 40,
      disabled = true,
      hidden = function() return not (trigger.type == "aura"); end,
      get = function() return true end
    },
    unit = {
      type = "select",
      name = L["Unit"],
      order = 41,
      values = unit_types,
      hidden = function() return not (trigger.type == "aura"); end
    },
    useGroup_count = {
      type = "toggle",
      name = L["Group Member Count"],
      disabled = true,
      hidden = function() return not (trigger.type == "aura" and trigger.unit == "group"); end,
      get = function() return true; end,
      order = 45
    },
    group_countOperator = {
      type = "select",
      name = L["Operator"],
      order = 46,
      width = "half",
      values = operator_types,
      hidden = function() return not (trigger.type == "aura" and trigger.unit == "group"); end,
      get = function() return trigger.group_countOperator; end
    },
    group_count = {
      type = "input",
      name = L["Count"],
      desc = function()
        local groupType = unit_types[trigger.unit or "group"] or "|cFFFF0000error|r";
        return L["Group aura count description"]:format(groupType, groupType, groupType, groupType, groupType, groupType, groupType);
      end,
      order = 47,
      width = "half",
      hidden = function() return not (trigger.type == "aura" and trigger.unit == "group"); end,
      get = function() return trigger.group_count; end,
      set = function(info, v) if(WeakAuras.ParseNumber(v)) then trigger.group_count = v; else trigger.group_count = ""; end end
    },
    hideAlone = {
      type = "toggle",
      name = L["Hide When Not In Group"],
      order = 48,
      width = "double",
      hidden = function() return not (trigger.type == "aura" and trigger.unit == "group"); end,
    },
    useDebuffType = {
      type = "toggle",
      name = L["Aura Type"],
      order = 50,
      disabled = true,
      hidden = function() return not (trigger.type == "aura"); end,
      get = function() return true end
    },
    debuffType = {
      type = "select",
      name = L["Aura Type"],
      order = 51,
      values = debuff_types,
      hidden = function() return not (trigger.type == "aura"); end
    },
    useCount = {
      type = "toggle",
      name = L["Stack Count"],
      hidden = function() return not (trigger.type == "aura"); end,
      order = 60
    },
    countOperator = {
      type = "select",
      name = L["Operator"],
      order = 62,
      width = "half",
      values = operator_types,
      disabled = function() return not trigger.useCount; end,
      hidden = function() return not trigger.type == "aura"; end,
      get = function() return trigger.useCount and trigger.countOperator or nil end
    },
    count = {
      type = "input",
      name = L["Stack Count"],
      order = 65,
      width = "half",
      disabled = function() return not trigger.useCount; end,
      hidden = function() return not trigger.type == "aura"; end,
      get = function() return trigger.useCount and trigger.count or nil end
    },
    ownOnly = {
      type = "toggle",
      name = L["Own Only"],
      desc = "Only match auras cast by the player",
      order = 70,
      hidden = function() return not (trigger.type == "aura"); end
    },
    inverse = {
      type = "toggle",
      name = L["Inverse"],
      desc = "Activate when the given aura(s) |cFFFF0000can't|r be found",
      order = 75,
      hidden = function() return not (trigger.type == "aura"); end
    }
  };
  
  local trigger_options = {
    addTrigger = {
      type = "execute",
      name = "Add Trigger",
      order = 0,
      disabled = function() return data.additional_triggers and #data.additional_triggers >= 9; end,
      func = function()
        if(data.controlledChildren) then
          for index, childId in pairs(data.controlledChildren) do
            local childData = WeakAuras.GetData(childId);
            if(childData) then
              childData.additional_triggers = childData.additional_triggers or {};
              tinsert(childData.additional_triggers, {trigger = {}, untrigger = {}});
              optionTriggerChoices[childId] = #childData.additional_triggers;
              WeakAuras.ReloadTriggerOptions(childData);
            end
          end
        else
          data.additional_triggers = data.additional_triggers or {};
          tinsert(data.additional_triggers, {trigger = {}, untrigger = {}});
          optionTriggerChoices[id] = #data.additional_triggers;
        end
        WeakAuras.ReloadTriggerOptions(data);
      end
    },
    chooseTrigger = {
      type = "select",
      name = "Choose Trigger",
      order = 1,
      values = function()
        local ret = {[0] = L["Main Trigger"]};
        if(data.controlledChildren) then
          for index=1,9 do
            local all, none, any = true, true, false;
            for _, childId in pairs(data.controlledChildren) do
              local childData = WeakAuras.GetData(childId);
              if(childData) then
                none = false;
                if(childData.additional_triggers and childData.additional_triggers[index]) then
                  any = true;
                else
                  all = false;
                end
              end
            end
            if not(none) then
              if(all) then
                ret[index] = L["Trigger "..(index + 1)];
              elseif(any) then
                ret[index] = "|cFF777777"..L["Trigger "..(index + 1)];
              end
            end
          end
        elseif(data.additional_triggers) then
          for index, trigger in pairs(data.additional_triggers) do
            ret[index] = L["Trigger "..(index + 1)];
          end
        end
        return ret;
      end,
      get = function() return optionTriggerChoices[id]; end,
      set = function(info, v)
        if(v == 0 or (data.additional_triggers and data.additional_triggers[v])) then
          optionTriggerChoices[id] = v;
          WeakAuras.ReloadTriggerOptions(data);
        end
      end
    },
    triggerHeader = {
      type = "header",
      name = function(info)
        if(info == "default") then
          return L["Multiple Triggers"];
        else
          if(optionTriggerChoices[id] == 0) then
            return L["Main Trigger"];
          else
            return L["Trigger "..(optionTriggerChoices[id] + 1)];
          end
        end
      end,
      order = 2
    },
    deleteTrigger = {
      type = "execute",
      name = L["Delete Trigger"],
      order = 3,
      width = "double",
      func = function()
        if(data.controlledChildren) then
          for index, childId in pairs(data.controlledChildren) do
            local childData = WeakAuras.GetData(childId);
            if(childData) then
              tremove(childData.additional_triggers, optionTriggerChoices[childId]);
              optionTriggerChoices[childId] = optionTriggerChoices[childId] - 1;
              WeakAuras.ReloadTriggerOptions(childData);
            end
          end
        else
          tremove(data.additional_triggers, optionTriggerChoices[id]);
          optionTriggerChoices[id] = optionTriggerChoices[id] - 1;
        end
        WeakAuras.ReloadTriggerOptions(data);
      end,
      hidden = function() return optionTriggerChoices[id] == 0; end
    },
    typedesc = {
      type = "toggle",
      name = L["Type"],
      order = 5,
      disabled = true,
      get = function() return true end
    },
    type = {
      type = "select",
      name = L["Type"],
      desc = L["The type of trigger"],
      order = 6,
      values = trigger_types
    },
    event = {
      type = "select",
      name = L["Event"],
      order = 7,
      width = "double",
      values = event_types,
      hidden = function() return not (trigger.type == "event"); end
    },
    subeventPrefix = {
      type = "select",
      name = L["Message Prefix"],
      order = 8,
      values = subevent_prefix_types,
      hidden = function() return not (trigger.type == "event" and trigger.event == "Combat Log"); end
    },
    subeventSuffix = {
      type = "select",
      name = L["Message Suffix"],
      order = 9,
      values = subevent_suffix_types,
      hidden = function() return not (trigger.type == "event" and trigger.event == "Combat Log" and subevent_actual_prefix_types[trigger.subeventPrefix]); end
    },
    conditionsHeader = {
      type = "header",
      name = L["Conditions"],
      order = 80
    }
  };
  
  local order = 81;
  for type, condition in pairs(WeakAuras.conditions) do
    trigger_options[type] = {
      type = "toggle",
      name = function(input)
        if(input == "default") then
          return condition.display;
        else
          local value = data.conditions[type];
          if(value == nil) then return condition.display;
          elseif(value == false) then return "|cFFFF0000 "..L["Negator"].." "..condition.display;
          else return "|cFF00FF00"..condition.display; end
        end
      end,
      desc = function()
        local value = data.conditions[type];
        if(value == nil) then return L["This condition will not be tested"];
        elseif(value == false) then return L["This display will only show when |cFFFF0000 Not %s"]:format(condition.display);
        else return L["This display will only show when |cFF00FF00%s"]:format(condition.display); end
      end,
      get = function() 
        local value = data.conditions[type];
        if(value == nil) then return false;
        elseif(value == false) then return "false";
        else return "true"; end
      end,
      set = function(info, v)
        if(v) then
          data.conditions[type] = true;
        else
          local value = data.conditions[type];
          if(value == false) then data.conditions[type] = nil;
          else data.conditions[type] = false end
        end
      end,
      order = order
    };
    order = order + 1;
  end
  
  if(data.controlledChildren) then
    local function options_set(info, ...)
      setAll(data, info, ...);
      WeakAuras.Add(data);
      WeakAuras.SetThumbnail(data);
      WeakAuras.SetIconNames(data);
      WeakAuras.UpdateDisplayButton(data);
      WeakAuras.ReloadTriggerOptions(data);
    end
    
    removeFuncs(displayOptions[id]);
    
    if(optionTriggerChoices[id] >= 0 and getAll(data, {"trigger", "type"}) == "aura") then
      displayOptions[id].args.trigger.args = union(trigger_options, aura_options);
      removeFuncs(displayOptions[id].args.trigger);
      displayOptions[id].args.trigger.args.type.set = options_set;
    elseif(optionTriggerChoices[id] >= 0 and getAll(data, {"trigger", "type"}) == "event") then
      local event = getAll(data, {"trigger", "event"});
      local unevent = getAll(data, {"trigger", "unevent"});
      if(event and WeakAuras.event_prototypes[event]) then
        if(event == "Combat Log") then
          local subeventPrefix = getAll(data, {"trigger", "subeventPrefix"});
          local subeventSuffix = getAll(data, {"trigger", "subeventSuffix"});
          if(subeventPrefix and subeventSuffix) then
            displayOptions[id].args.trigger.args = union(trigger_options, WeakAuras.ConstructOptions(WeakAuras.event_prototypes[event], data, 10, subeventPrefix, subeventSuffix, optionTriggerChoices[id], nil, unevent));
          end
        else
          displayOptions[id].args.trigger.args = union(trigger_options, WeakAuras.ConstructOptions(WeakAuras.event_prototypes[event], data, 10, nil, nil, optionTriggerChoices[id], nil, unevent));
        end
      else
        displayOptions[id].args.trigger.args = union(trigger_options, {});
        removeFuncs(displayOptions[id].args.trigger);
      end
      removeFuncs(displayOptions[id].args.trigger);
      replaceNameDescFuncs(displayOptions[id].args.trigger, data);
      replaceImageFuncs(displayOptions[id].args.trigger, data);
      
      if(displayOptions[id].args.trigger.args.unevent) then
        displayOptions[id].args.trigger.args.unevent.set = options_set;
      end
      if(displayOptions[id].args.trigger.args.subeventPrefix) then
        displayOptions[id].args.trigger.args.subeventPrefix.set = function(info, v)
          if not(subevent_actual_prefix_types[v]) then
            data.trigger.subeventSuffix = "";
          end
          options_set(info, v);
        end
      end
      if(displayOptions[id].args.trigger.args.subeventSuffix) then
        displayOptions[id].args.trigger.args.subeventSuffix.set = options_set;
      end
      
      displayOptions[id].args.trigger.args.type.set = options_set;
      displayOptions[id].args.trigger.args.event.set = options_set;
    else--[[if(getAll(data, {"trigger", "type"}) == nil) then]]
      displayOptions[id].args.trigger.args = trigger_options;
      removeFuncs(displayOptions[id].args.trigger);
    end
    
    displayOptions[id].get = function(info, ...) return getAll(data, info, ...); end;
    displayOptions[id].set = function(info, ...)
      setAll(data, info, ...);
      WeakAuras.Add(data);
      WeakAuras.SetThumbnail(data);
      WeakAuras.ResetMoverSizer();
    end
    displayOptions[id].hidden = function(info, ...) return hiddenAll(data, info, ...); end;
    displayOptions[id].disabled = function(info, ...) return disabledAll(data, info, ...); end;
    
    trigger_options.chooseTrigger.set = options_set;
    trigger_options.type.set = options_set;
    trigger_options.event.set = options_set;
    
    replaceNameDescFuncs(displayOptions[id], data);
    replaceImageFuncs(displayOptions[id], data);
    
    regionOption = regionOptions[data.regionType].create(id, data);
    displayOptions[id].args.group = {
      type = "group",
      name = L["Group"],
      order = 0,
      get = function(info)
        if(info.type == "color") then
          data[info[#info]] = data[info[#info]] or {};
          local c = data[info[#info]];
          return c[1], c[2], c[3], c[4];
        else
          return data[info[#info]];
        end
      end,
      set = function(info, v, g, b, a)
        if(info.type == "color") then
          data[info[#info]] = data[info[#info]] or {};
          local c = data[info[#info]];
          c[1], c[2], c[3], c[4] = v, g, b, a;
        elseif(info.type == "toggle") then
          data[info[#info]] = v;
        else
          data[info[#info]] = (v ~= "" and v) or nil;
        end
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.SetIconNames(data);
        WeakAuras.ResetMoverSizer();
      end,
      hidden = function() return false end,
      disabled = function() return false end,
      args = regionOption
    };
    
    displayOptions[id].args.load.args = WeakAuras.ConstructOptions(WeakAuras.load_prototype, data, 10, nil, nil, optionTriggerChoices[id], "load");
    removeFuncs(displayOptions[id].args.load);
    replaceNameDescFuncs(displayOptions[id].args.load, data);
    replaceImageFuncs(displayOptions[id].args.load, data);
    
    WeakAuras.ReloadGroupRegionOptions(data);
  else
    local function options_set(info, v)
      trigger[info[#info]] = v;
      WeakAuras.Add(data);
      WeakAuras.SetThumbnail(data);
      WeakAuras.SetIconNames(data);
      WeakAuras.UpdateDisplayButton(data);
      WeakAuras.ReloadTriggerOptions(data);
    end
    if(trigger.type == "aura") then
      displayOptions[id].args.trigger.args = union(trigger_options, aura_options);
    elseif(trigger.type == "event") then
      if(WeakAuras.event_prototypes[trigger.event]) then
        if(trigger.event == "Combat Log") then
          displayOptions[id].args.trigger.args = union(trigger_options, WeakAuras.ConstructOptions(WeakAuras.event_prototypes[trigger.event], data, 10, (trigger.subeventPrefix or ""), (trigger.subeventSuffix or ""), optionTriggerChoices[id]));
        else
          displayOptions[id].args.trigger.args = union(trigger_options, WeakAuras.ConstructOptions(WeakAuras.event_prototypes[trigger.event], data, 10, nil, nil, optionTriggerChoices[id]));
        end
        if(displayOptions[id].args.trigger.args.unevent) then
          displayOptions[id].args.trigger.args.unevent.set = options_set;
        end
        if(displayOptions[id].args.trigger.args.subeventPrefix) then
          displayOptions[id].args.trigger.args.subeventPrefix.set = function(info, v)
            if not(subevent_actual_prefix_types[v]) then
              trigger.subeventSuffix = "";
            end
            options_set(info, v);
          end
        end
        if(displayOptions[id].args.trigger.args.subeventSuffix) then
          displayOptions[id].args.trigger.args.subeventSuffix.set = options_set;
        end
      else
        print("No prototype for", trigger.event);
        displayOptions[id].args.trigger.args = union(trigger_options, {});
      end
    else
      displayOptions[id].args.trigger.args = union(trigger_options, {});
    end
    
    displayOptions[id].args.load.args = WeakAuras.ConstructOptions(WeakAuras.load_prototype, data, 10, nil, nil, optionTriggerChoices[id], "load");
    
    trigger_options.type.set = options_set;
    trigger_options.event.set = function(info, v, ...)
      local prototype = WeakAuras.event_prototypes[v];
      if(prototype) then
        if(prototype.automatic or prototype.automaticrequired) then
          trigger.unevent = "auto";
        else
          trigger.unevent = "timed";
        end
      end
      options_set(info, v, ...);
    end
    trigger.event = trigger.event or "Health";
    trigger.subeventPrefix = trigger.subeventPrefix or "SPELL"
    trigger.subeventSuffix = trigger.subeventSuffix or "_CAST_START";
    
    displayOptions[id].args.trigger.get = function(info) return trigger[info[#info]] end;
    displayOptions[id].args.trigger.set = function(info, v)
      trigger[info[#info]] = (v ~= "" and v) or nil;
      WeakAuras.Add(data);
      WeakAuras.SetThumbnail(data);
      WeakAuras.SetIconNames(data);
      WeakAuras.UpdateDisplayButton(data);
    end;
  end
end

function WeakAuras.ReloadGroupRegionOptions(data)
  local regionType;
  local first = true;
  for index, childId in ipairs(data.controlledChildren) do
    local childData = WeakAuras.GetData(childId);
    if(childData) then
      if(first) then
        regionType = childData.regionType;
        first = false;
      else
        if(childData.regionType ~= regionType) then
          regionType = false;
        end
      end
    end
  end
  
  local id = data.id;
  local options = displayOptions[id];
  local regionOption;
  if(regionType) then
    if(regionOptions[regionType]) then
      regionOption = regionOptions[regionType].create(id, data);
    end
  end
  if(regionOption) then
    if(data.regionType == "dynamicgroup") then
      regionOption.selfPoint = nil;
      regionOption.anchorPoint = nil;
      regionOption.anchorPointGroup = nil;
      regionOption.xOffset1 = nil;
      regionOption.xOffset2 = nil;
      regionOption.xOffset3 = nil;
      regionOption.yOffset1 = nil;
      regionOption.yOffset2 = nil;
      regionOption.yOffset3 = nil;
    end
    replaceNameDescFuncs(regionOption, data);
    replaceImageFuncs(regionOption, data);
  else
    regionOption = {
      invalid = {
        type = "description",
        name = L["The children of this group have different display types, so their display options cannot be set as a group."],
        fontSize = "large"
      }
    };
  end
  removeFuncs(regionOption);
  options.args.region.args = regionOption;
end

function WeakAuras.AddPositionOptions(input, id, data)
  local screenWidth, screenHeight = math.ceil(GetScreenWidth() / 20) * 20, math.ceil(GetScreenHeight() / 20) * 20;
  local positionOptions = {
    width = {
      type = "range",
      name = L["Width"],
      order = 60,
      softMin = 0,
      softMax = screenWidth,
      bigStep = 1
    },
    height = {
      type = "range",
      name = L["Height"],
      order = 65,
      softMin = 0,
      softMax = screenHeight,
      bigStep = 1
    },
    selfPoint = {
      type = "select",
      name = L["Anchor"],
      order = 70,
      hidden = function() return data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup"; end,
      values = point_types
    },
    anchorPoint = {
      type = "select",
      name = L["to screen's"],
      order = 75,
      hidden = function() return data.parent; end,
      values = point_types
    },
    anchorPointGroup = {
      type = "select",
      name = L["to group's"],
      order = 75,
      hidden = function() return (not data.parent) or (db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup"); end,
      disabled = true,
      values = {["CENTER"] = L["Anchor Point"]},
      get = function() return "CENTER"; end
    },
    xOffset1 = {
      type = "range",
      name = L["X Offset"],
      order = 80,
      softMin = 0,
      softMax = screenWidth,
      bigStep = 10,
      hidden = function() return (data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") or not data.anchorPoint:find("LEFT") end,
      get = function() return data.xOffset end,
      set = function(info, v)
        data.xOffset = v;
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.ResetMoverSizer();
        if(data.parent) then
          local parentData = WeakAuras.GetData(data.parent);
          if(parentData) then
            WeakAuras.Add(parentData);
            WeakAuras.SetThumbnail(parentData);
          end
        end
      end
    },
    xOffset2 = {
      type = "range",
      name = L["X Offset"],
      order = 80,
      softMin = ((-1/2) * screenWidth),
      softMax = ((1/2) * screenWidth),
      bigStep = 10,
      hidden = function() return (data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") or (data.anchorPoint:find("LEFT") or data.anchorPoint:find("RIGHT")) end,
      get = function() return data.xOffset end,
      set = function(info, v)
        data.xOffset = v;
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.ResetMoverSizer();
        if(data.parent) then
          local parentData = WeakAuras.GetData(data.parent);
          if(parentData) then
            WeakAuras.Add(parentData);
            WeakAuras.SetThumbnail(parentData);
          end
        end
      end
    },
    xOffset3 = {
      type = "range",
      name = L["X Offset"],
      order = 80,
      softMin = (-1 * screenWidth),
      softMax = 0,
      bigStep = 10,
      hidden = function() return (data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") or not data.anchorPoint:find("RIGHT") end,
      get = function() return data.xOffset end,
      set = function(info, v)
        data.xOffset = v;
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.ResetMoverSizer();
        if(data.parent) then
          local parentData = WeakAuras.GetData(data.parent);
          if(parentData) then
            WeakAuras.Add(parentData);
            WeakAuras.SetThumbnail(parentData);
          end
        end
      end
    },
    yOffset1 = {
      type = "range",
      name = L["Y Offset"],
      order = 85,
      softMin = 0,
      softMax = screenHeight,
      bigStep = 10,
      hidden = function() return (data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") or not data.anchorPoint:find("BOTTOM") end,
      get = function() return data.yOffset end,
      set = function(info, v)
        data.yOffset = v;
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.ResetMoverSizer();
        if(data.parent) then
          local parentData = WeakAuras.GetData(data.parent);
          if(parentData) then
            WeakAuras.Add(parentData);
            WeakAuras.SetThumbnail(parentData);
          end
        end
      end
    },
    yOffset2 = {
      type = "range",
      name = L["Y Offset"],
      order = 85,
      softMin = ((-1/2) * screenHeight),
      softMax = ((1/2) * screenHeight),
      bigStep = 10,
      hidden = function() return (data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") or (data.anchorPoint:find("BOTTOM") or data.anchorPoint:find("TOP")) end,
      get = function() return data.yOffset end,
      set = function(info, v)
        data.yOffset = v;
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.ResetMoverSizer();
        if(data.parent) then
          local parentData = WeakAuras.GetData(data.parent);
          if(parentData) then
            WeakAuras.Add(parentData);
            WeakAuras.SetThumbnail(parentData);
          end
        end
      end
    },
    yOffset3 = {
      type = "range",
      name = L["Y Offset"],
      order = 85,
      softMin = (-1 * screenHeight),
      softMax = 0,
      bigStep = 10,
      hidden = function() return (data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") or not data.anchorPoint:find("TOP") end,
      get = function() return data.yOffset end,
      set = function(info, v)
        data.yOffset = v;
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        WeakAuras.ResetMoverSizer();
        if(data.parent) then
          local parentData = WeakAuras.GetData(data.parent);
          if(parentData) then
            WeakAuras.Add(parentData);
            WeakAuras.SetThumbnail(parentData);
          end
        end
      end
    }
  };
  
  return union(input, positionOptions);
end

function WeakAuras.CreateFrame()
  local frame;
  --------Mostly Copied from AceGUIContainer-Frame--------
  frame = CreateFrame("FRAME", nil, UIParent);
	frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  });
	frame:SetBackdropColor(0, 0, 0, 1);
  frame:SetWidth(610);
  frame:SetHeight(492);
  frame:EnableMouse(true);
	frame:SetMovable(true);
	frame:SetFrameStrata("DIALOG");
  frame.window = "default";
  
  local xOffset, yOffset;
  if(db.frame) then
    xOffset, yOffset = db.frame.xOffset, db.frame.yOffset;
  end
  if not(xOffset and yOffset) then
    xOffset = (610 - GetScreenWidth()) / 2;
    yOffset = (492 - GetScreenHeight()) / 2;
  end
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOffset, yOffset);
  frame:Hide();
  
  local close = CreateFrame("Frame", nil, frame);
	close:SetWidth(17)
	close:SetHeight(40)
	close:SetPoint("TOPRIGHT", -30, 12)
  
  local closebg = close:CreateTexture(nil, "BACKGROUND")
	closebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	closebg:SetTexCoord(0.31, 0.67, 0, 0.63)
	closebg:SetAllPoints(close);

	local closebutton = CreateFrame("BUTTON", nil, close)
  closebutton:SetWidth(30);
  closebutton:SetHeight(30);
	closebutton:SetPoint("CENTER", close, "CENTER", 1, -1);
  closebutton:SetNormalTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Up.blp");
  closebutton:SetPushedTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Down.blp");
  closebutton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
	closebutton:SetScript("OnClick", WeakAuras.HideOptions);
  
	local closebg_l = close:CreateTexture(nil, "BACKGROUND")
	closebg_l:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	closebg_l:SetTexCoord(0.235, 0.275, 0, 0.63)
	closebg_l:SetPoint("RIGHT", closebg, "LEFT")
	closebg_l:SetWidth(10)
	closebg_l:SetHeight(40)

	local closebg_r = close:CreateTexture(nil, "BACKGROUND")
	closebg_r:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	closebg_r:SetTexCoord(0.72, 0.76, 0, 0.63)
	closebg_r:SetPoint("LEFT", closebg, "RIGHT")
	closebg_r:SetWidth(10)
	closebg_r:SetHeight(40)
  
  local titlebg = frame:CreateTexture(nil, "OVERLAY")
	titlebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg:SetTexCoord(0.31, 0.67, 0, 0.63)
	titlebg:SetPoint("TOP", 0, 12)
	titlebg:SetWidth(100)
	titlebg:SetHeight(40)

	local titlebg_l = frame:CreateTexture(nil, "OVERLAY")
	titlebg_l:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg_l:SetTexCoord(0.21, 0.31, 0, 0.63)
	titlebg_l:SetPoint("RIGHT", titlebg, "LEFT")
	titlebg_l:SetWidth(30)
	titlebg_l:SetHeight(40)

	local titlebg_r = frame:CreateTexture(nil, "OVERLAY")
	titlebg_r:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg_r:SetTexCoord(0.67, 0.77, 0, 0.63)
	titlebg_r:SetPoint("LEFT", titlebg, "RIGHT")
	titlebg_r:SetWidth(30)
	titlebg_r:SetHeight(40)

	local title = CreateFrame("Frame", nil, frame)
	title:EnableMouse(true)
	title:SetScript("OnMouseDown", function() frame:StartMoving() end)
	title:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing();
    local xOffset = frame:GetRight() - GetScreenWidth();
    local yOffset = frame:GetTop() - GetScreenHeight();
    if(title:GetRight() > GetScreenWidth()) then
      xOffset = xOffset + (GetScreenWidth() - title:GetRight());
    elseif(title:GetLeft() < 0) then
      xOffset = xOffset + (0 - title:GetLeft());
    end
    if(title:GetTop() > GetScreenHeight()) then
      yOffset = yOffset + (GetScreenHeight() - title:GetTop());
    elseif(title:GetBottom() < 0) then
      yOffset = yOffset + (0 - title:GetBottom());
    end
    db.frame = db.frame or {};
    db.frame.xOffset = xOffset;
    db.frame.yOffset = yOffset;
    frame:ClearAllPoints();
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", xOffset, yOffset);
  end);
  title:SetPoint("BOTTOMLEFT", titlebg, "BOTTOMLEFT", -25, 0);
  title:SetPoint("TOPRIGHT", titlebg, "TOPRIGHT", 30, 0);

	local titletext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titletext:SetPoint("TOP", titlebg, "TOP", 0, -14)
  titletext:SetText(L["WeakAuras Options"]);
  --------------------------------------------------------
  

	local minimize = CreateFrame("Frame", nil, frame);
	minimize:SetWidth(17)
	minimize:SetHeight(40)
	minimize:SetPoint("TOPRIGHT", -65, 12)
  
  local minimizebg = minimize:CreateTexture(nil, "BACKGROUND")
	minimizebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	minimizebg:SetTexCoord(0.31, 0.67, 0, 0.63)
	minimizebg:SetAllPoints(minimize);

	local minimizebutton = CreateFrame("BUTTON", nil, minimize)
  minimizebutton:SetWidth(30);
  minimizebutton:SetHeight(30);
	minimizebutton:SetPoint("CENTER", minimize, "CENTER", 1, -1);
  minimizebutton:SetNormalTexture("Interface\\BUTTONS\\UI-Panel-CollapseButton-Up.blp");
  minimizebutton:SetPushedTexture("Interface\\BUTTONS\\UI-Panel-CollapseButton-Down.blp");
  minimizebutton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight.blp");
	minimizebutton:SetScript("OnClick", function()
    if(frame.minimized) then
      frame.minimized = nil;
      frame:SetHeight(500);
      if(frame.window == "default") then
        frame.buttonsContainer.frame:Show();
        frame.container.frame:Show();
      elseif(frame.window == "texture") then
        frame.texturePick.frame:Show();
      elseif(frame.window == "icon") then
        frame.iconPick.frame:Show();
      end
      minimizebutton:SetNormalTexture("Interface\\BUTTONS\\UI-Panel-CollapseButton-Up.blp");
      minimizebutton:SetPushedTexture("Interface\\BUTTONS\\UI-Panel-CollapseButton-Down.blp");
    else
      frame.minimized = true;
      frame:SetHeight(40);
      frame.buttonsContainer.frame:Hide();
      frame.texturePick.frame:Hide();
      frame.iconPick.frame:Hide();
      frame.container.frame:Hide();
      minimizebutton:SetNormalTexture("Interface\\BUTTONS\\UI-Panel-ExpandButton-Up.blp");
      minimizebutton:SetPushedTexture("Interface\\BUTTONS\\UI-Panel-ExpandButton-Down.blp");
    end
  end);
  
	local minimizebg_l = minimize:CreateTexture(nil, "BACKGROUND")
	minimizebg_l:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	minimizebg_l:SetTexCoord(0.235, 0.275, 0, 0.63)
	minimizebg_l:SetPoint("RIGHT", minimizebg, "LEFT")
	minimizebg_l:SetWidth(10)
	minimizebg_l:SetHeight(40)

	local minimizebg_r = minimize:CreateTexture(nil, "BACKGROUND")
	minimizebg_r:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	minimizebg_r:SetTexCoord(0.72, 0.76, 0, 0.63)
	minimizebg_r:SetPoint("LEFT", minimizebg, "RIGHT")
	minimizebg_r:SetWidth(10)
	minimizebg_r:SetHeight(40)
  
  local container = AceGUI:Create("InlineGroup");
  container.frame:SetParent(frame);
  container.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 12);
  container.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 187, -10);
  container.frame:Show();
  container.titletext:Hide();
  frame.container = container;
  
  local texturePick = AceGUI:Create("InlineGroup");
  texturePick.frame:SetParent(frame);
  texturePick.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 12);
  texturePick.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -10);
  texturePick.frame:Hide();
  frame.texturePick = texturePick;
  texturePick.children = {};
  texturePick.categories = {};
  
  local texturePickDropdown = AceGUI:Create("DropdownGroup");
	texturePickDropdown:SetLayout("fill");
	texturePickDropdown.width = "fill";
  texturePickDropdown:SetHeight(390);
	texturePick:SetLayout("flow");
	texturePick:AddChild(texturePickDropdown);
  texturePickDropdown.list = {};
  texturePickDropdown:SetGroupList(texturePickDropdown.list);
  
  local texturePickScroll = AceGUI:Create("ScrollFrame");
  texturePickScroll.width = 370;
  texturePickScroll:SetLayout("flow");
  texturePickDropdown:AddChild(texturePickScroll);
  
  local function texturePickGroupSelected(widget, event, uniquevalue)
    texturePickScroll:ReleaseChildren();
    for texturePath, textureName in pairs(texture_types[uniquevalue]) do
      local textureWidget = AceGUI:Create("WeakAurasTextureButton");
      textureWidget:SetTexture(texturePath, textureName);
      textureWidget:SetClick(function()
        texturePick:Pick(texturePath);
      end);
      local d = texturePick.textureData;
      textureWidget:ChangeTexture(d.r, d.g, d.b, d.a, d.rotate, d.discrete_rotation, d.rotation, d.mirror, d.blendMode);
      texturePickScroll:AddChild(textureWidget);
      table.sort(texturePickScroll.children, function(a, b)
        local aPath, bPath = a:GetTexturePath(), b:GetTexturePath();
        local aNum, bNum = tonumber(aPath:match("%d+")), tonumber(bPath:match("%d+"));
        local aNonNumber, bNonNumber = aPath:match("[^%d]+"), bPath:match("[^%d]+")
        if(aNum and bNum and aNonNumber == bNonNumber) then
          return aNum < bNum;
        else
          return aPath < bPath;
        end
      end);
    end
    texturePick:Pick(texturePick.data[texturePick.field]);
  end
  
  texturePickDropdown:SetCallback("OnGroupSelected", texturePickGroupSelected)
  
  function texturePick.UpdateList(self)
    wipe(texturePickDropdown.list);
    for categoryName, category in pairs(texture_types) do
      local match = false;
      for texturePath, textureName in pairs(category) do
        if(texturePath == self.data[self.field]) then
          match = true;
          break;
        end
      end
      texturePickDropdown.list[categoryName] = (match and "|cFF80A0FF" or "")..categoryName;
    end
    texturePickDropdown:SetGroupList(texturePickDropdown.list);
  end
  
  function texturePick.Pick(self, texturePath)
    local pickedwidget;
    for index, widget in ipairs(texturePickScroll.children) do
      widget:ClearPick();
      if(widget:GetTexturePath() == texturePath) then
        pickedwidget = widget;
      end
    end
    if(pickedwidget) then
      pickedwidget:Pick();
    end
    if(self.data.controlledChildren) then
      setAll(self.data, {"region", self.field}, texturePath);
    else
      self.data[self.field] = texturePath;
    end
    WeakAuras.Add(self.data);
    WeakAuras.SetIconNames(self.data);
    WeakAuras.SetThumbnail(self.data);
    texturePick:UpdateList();
    local status = texturePickDropdown.status or texturePickDropdown.localstatus
    texturePickDropdown.dropdown:SetText(texturePickDropdown.list[status.selected]);
  end
  
  function texturePick.Open(self, data, field)
    self.data = data;
    self.field = field;
    if(data.controlledChildren) then
      self.givenPath = {};
      for index, childId in pairs(data.controlledChildren) do
        local childData = WeakAuras.GetData(childId);
        if(childData) then
          self.givenPath[childId] = childData[field];
        end
      end
      local colorAll = getAll(data, {"region", "color"}) or {1, 1, 1, 1};
      self.textureData = {
        r = colorAll[1] or 1,
        g = colorAll[2] or 1,
        b = colorAll[3] or 1,
        a = colorAll[4] or 1,
        rotate = getAll(data, {"region", "rotate"}),
        discrete_rotation = getAll(data, {"region", "discrete_rotation"}) or 0,
        rotation = getAll(data, {"region", "rotation"}) or 0,
        mirror = getAll(data, {"region", "mirror"}),
        blendMode = getAll(data, {"region", "blendMode"}) or "ADD"
      };
    else
      self.givenPath = data[field];
      data.color = data.color or {};
      self.textureData = {
        r = data.color[1] or 1,
        g = data.color[2] or 1,
        b = data.color[3] or 1,
        a = data.color[4] or 1,
        rotate = data.rotate,
        discrete_rotation =  data.discrete_rotation or 0,
        rotation = data.rotation or 0,
        mirror = data.mirror,
        blendMode = data.blendMode or "ADD"
      };
    end
    frame.container.frame:Hide();
    frame.buttonsContainer.frame:Hide();
    self.frame:Show();
    frame.window = "texture";
    local picked = false;
    for categoryName, category in pairs(texture_types) do
      if not(picked) then
        for texturePath, textureName in pairs(category) do
          if(texturePath == self.givenPath) then
            texturePickDropdown:SetGroup(categoryName);
            self:Pick(self.givenPath);
            picked = true;
            break;
          end
        end
      end
    end
    if not(picked) then
      for categoryName, category in pairs(texture_types) do
        texturePickDropdown:SetGroup(categoryName);
        break;
      end
    end
  end
  
  function texturePick.Close()
    texturePick.frame:Hide();
    frame.buttonsContainer.frame:Show();
    frame.container.frame:Show();
    frame.window = "default";
    AceConfigDialog:Open("WeakAuras", container);
  end
  
  function texturePick.CancelClose()
    if(texturePick.data.controlledChildren) then
      for index, childId in pairs(texturePick.data.controlledChildren) do
        local childData = WeakAuras.GetData(childId);
        if(childData) then
          childData[texturePick.field] = texturePick.givenPath[childId];
          WeakAuras.Add(childData);
          WeakAuras.SetThumbnail(self.data);
          WeakAuras.SetIconNames(self.data);
        end
      end
    else
      texturePick:Pick(texturePick.givenPath);
    end
    texturePick.Close();
  end
  
  local texturePickClose = CreateFrame("Button", nil, texturePick.frame, "UIPanelButtonTemplate")
	texturePickClose:SetScript("OnClick", texturePick.Close)
	texturePickClose:SetPoint("BOTTOMRIGHT", -27, 11)
	texturePickClose:SetHeight(20)
	texturePickClose:SetWidth(100)
	texturePickClose:SetText(L["Okay"])
  
  local texturePickCancel = CreateFrame("Button", nil, texturePick.frame, "UIPanelButtonTemplate")
	texturePickCancel:SetScript("OnClick", texturePick.CancelClose)
	texturePickCancel:SetPoint("RIGHT", texturePickClose, "LEFT", -10, 0)
	texturePickCancel:SetHeight(20)
	texturePickCancel:SetWidth(100)
	texturePickCancel:SetText(L["Cancel"])
  
  local iconPick = AceGUI:Create("InlineGroup");
  iconPick.frame:SetParent(frame);
  iconPick.frame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 12);
  iconPick.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -10);
  iconPick.frame:Hide();
	iconPick:SetLayout("flow");
  frame.iconPick = iconPick;
  
  local iconPickScroll = AceGUI:Create("InlineGroup");
  iconPickScroll:SetWidth(540);
  iconPickScroll:SetLayout("flow");
  iconPickScroll.frame:SetParent(iconPick.frame);
  iconPickScroll.frame:SetPoint("BOTTOMLEFT", iconPick.frame, "BOTTOMLEFT", 10, 30);
  iconPickScroll.frame:SetPoint("TOPRIGHT", iconPick.frame, "TOPRIGHT", -10, -70);
  
  local function iconPickFill(subname, doSort)
    iconPickScroll:ReleaseChildren();

    local distances = {};
    local names = {};

    local num = 0;
    if(subname ~= "") then
      for name, path in pairs(iconCache) do
        local bestDistance = math.huge;
        local bestName;
        if(name:find(subname) or path:find(subname)) then
          if(doSort) then
            local distance = Lev(name, path:sub(17));
            if(distances[path]) then
              if(distance < distances[path]) then
                names[path] = name;
                distances[path] = distance;
              end
            else
              names[path] = name;
              distances[path] = distance;
              num = num + 1;
            end
          else
            if(not names[path]) then
              names[path] = name;
              num = num + 1;
            end
          end
        end

        if(num >= 60) then
          break;
        end
      end

      for path, name in pairs(names) do
        local button = AceGUI:Create("WeakAurasIconButton");
        button:SetName(name);
        button:SetTexture(path);
        button:SetClick(function()
          iconPick:Pick(path);
        end);
        iconPickScroll:AddChild(button);
      end
    end
  end
  
  local iconPickInput = CreateFrame("EDITBOX", nil, iconPick.frame, "InputBoxTemplate");
  iconPickInput:SetScript("OnTextChanged", function(...) iconPickFill(iconPickInput:GetText(), false); end);
  iconPickInput:SetScript("OnEnterPressed", function(...) iconPickFill(iconPickInput:GetText(), true); end);
  iconPickInput:SetScript("OnEscapePressed", function(...) iconPickInput:SetText(""); iconPickFill(iconPickInput:GetText(), true); end);
  iconPickInput:SetWidth(170);
  iconPickInput:SetHeight(15);
  iconPickInput:SetPoint("TOPRIGHT", iconPick.frame, "TOPRIGHT", -12, -65);
  WeakAuras.iconPickInput = iconPickInput;
  
  local iconPickInputLabel = iconPickInput:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  iconPickInputLabel:SetText(L["Search"]);
  iconPickInputLabel:SetJustifyH("RIGHT");
  iconPickInputLabel:SetPoint("BOTTOMLEFT", iconPickInput, "TOPLEFT", 0, 5);
  
  local iconPickIcon = AceGUI:Create("WeakAurasIconButton");
  iconPickIcon.frame:Disable();
  iconPickIcon.frame:SetParent(iconPick.frame);
  iconPickIcon.frame:SetPoint("TOPLEFT", iconPick.frame, "TOPLEFT", 15, -30);
  
  local iconPickIconLabel = iconPickInput:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge");
  iconPickIconLabel:SetNonSpaceWrap("true");
  iconPickIconLabel:SetJustifyH("LEFT");
  iconPickIconLabel:SetPoint("LEFT", iconPickIcon.frame, "RIGHT", 5, 0);
  iconPickIconLabel:SetPoint("RIGHT", iconPickInput, "LEFT", -50, 0);
  
  function iconPick.Pick(self, texturePath)
    if(self.data.controlledChildren) then
      for index, childId in pairs(self.data.controlledChildren) do
        local childData = WeakAuras.GetData(childId);
        if(childData) then
          childData[self.field] = texturePath;
          WeakAuras.Add(childData);
          WeakAuras.SetThumbnail(childData);
          WeakAuras.SetIconNames(childData);
        end
      end
    else
      self.data[self.field] = texturePath;
      WeakAuras.Add(self.data);
      WeakAuras.SetThumbnail(self.data);
      WeakAuras.SetIconNames(self.data);
    end
    local success = iconPickIcon:SetTexture(texturePath) and texturePath;
    if(success) then
      iconPickIconLabel:SetText(texturePath:sub(17));
    else
      iconPickIconLabel:SetText();
    end
  end
  
  function iconPick.Open(self, data, field)
    self.data = data;
    self.field = field;
    if(data.controlledChildren) then
      self.givenPath = {};
      for index, childId in pairs(data.controlledChildren) do
        local childData = WeakAuras.GetData(childId);
        if(childData) then
          self.givenPath[childId] = childData[field];
        end
      end
    else
      self.givenPath = self.data[self.field];
    end
    --iconPick:Pick(self.givenPath);
    frame.container.frame:Hide();
    frame.buttonsContainer.frame:Hide();
    self.frame:Show();
    frame.window = "icon";
    iconPickInput:SetText("");
  end
  
  function iconPick.Close()
    iconPick.frame:Hide();
    frame.container.frame:Show();
    frame.buttonsContainer.frame:Show();
    frame.window = "default";
    AceConfigDialog:Open("WeakAuras", container);
  end
  
  function iconPick.CancelClose()
    if(iconPick.data.controlledChildren) then
      for index, childId in pairs(iconPick.data.controlledChildren) do
        local childData = WeakAuras.GetData(childId);
        if(childData) then
          childData[iconPick.field] = iconPick.givenPath[childId] or childData[iconPick.field];
          WeakAuras.Add(childData);
          WeakAuras.SetThumbnail(childData);
          WeakAuras.SetIconNames(childData);
        end
      end
    else
      iconPick:Pick(iconPick.givenPath);
    end
    iconPick.Close();
  end
  
  local iconPickClose = CreateFrame("Button", nil, iconPick.frame, "UIPanelButtonTemplate");
	iconPickClose:SetScript("OnClick", iconPick.Close);
	iconPickClose:SetPoint("BOTTOMRIGHT", -27, 11);
	iconPickClose:SetHeight(20);
	iconPickClose:SetWidth(100);
	iconPickClose:SetText(L["Okay"]);
  
  local iconPickCancel = CreateFrame("Button", nil, iconPick.frame, "UIPanelButtonTemplate");
	iconPickCancel:SetScript("OnClick", iconPick.CancelClose);
	iconPickCancel:SetPoint("RIGHT", iconPickClose, "LEFT", -10, 0);
	iconPickCancel:SetHeight(20);
	iconPickCancel:SetWidth(100);
	iconPickCancel:SetText(L["Cancel"]);
  
  iconPickScroll.frame:SetPoint("BOTTOM", iconPickClose, "TOP", 0, 10);
  
  local buttonsContainer = AceGUI:Create("InlineGroup");
  buttonsContainer:SetWidth(170);
  buttonsContainer.frame:SetParent(frame);
  buttonsContainer.frame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 12);
  buttonsContainer.frame:SetPoint("TOP", frame, "TOP", 0, -10);
  buttonsContainer.frame:Show();
  frame.buttonsContainer = buttonsContainer;
  
  local buttonsScroll = AceGUI:Create("ScrollFrame");
	buttonsScroll:SetLayout("flow");
	buttonsScroll.width = "fill";
	buttonsScroll.height = "fill";
	buttonsContainer:SetLayout("fill");
	buttonsContainer:AddChild(buttonsScroll);
  buttonsScroll.DeleteChild = function(self, delete)
    for index, widget in ipairs(buttonsScroll.children) do
      if(widget == delete) then
        tremove(buttonsScroll.children, index);
      end
    end
    AceGUI:Release(delete);
    buttonsScroll:DoLayout();
  end
  frame.buttonsScroll = buttonsScroll;
  
  function buttonsScroll:SetScrollPos(top, bottom)
		local status = self.status or self.localstatus;
		local viewheight = self.scrollframe:GetHeight();
		local height = self.content:GetHeight();
		local move;
    
    local viewtop = -1 * status.offset;
    local viewbottom = -1 * (status.offset + viewheight);
    if(top > viewtop) then
      move = top - viewtop;
    elseif(bottom < viewbottom) then
      move = bottom - viewbottom;
    else
      move = 0;
    end
    
    status.offset = status.offset - move;
    
		self.content:ClearAllPoints();
		self.content:SetPoint("TOPLEFT", 0, status.offset);
		self.content:SetPoint("TOPRIGHT", 0, status.offset);
    
    status.scrollvalue = status.offset / ((height - viewheight) / 1000.0);
    
    self:FixScroll();
  end
  
  local moversizer = CreateFrame("FRAME", nil, frame);
  frame.moversizer = moversizer;
  moversizer:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {left = 0, right = 0, top = 0, bottom = 0}
  });
  moversizer:EnableMouse();
  moversizer:SetFrameStrata("HIGH");
  
  moversizer.bl = CreateFrame("FRAME", nil, moversizer);
  moversizer.bl:EnableMouse();
  moversizer.bl:SetWidth(16);
  moversizer.bl:SetHeight(16);
  moversizer.bl:SetPoint("BOTTOMLEFT", moversizer, "BOTTOMLEFT");
  moversizer.bl.l = moversizer.bl:CreateTexture(nil, "OVERLAY");
  moversizer.bl.l:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.bl.l:SetBlendMode("ADD");
  moversizer.bl.l:SetTexCoord(1, 0, 0.5, 0, 1, 1, 0.5, 1);
  moversizer.bl.l:SetPoint("BOTTOMLEFT", moversizer.bl, "BOTTOMLEFT", 3, 3);
  moversizer.bl.l:SetPoint("TOPRIGHT", moversizer.bl, "TOP");
  moversizer.bl.b = moversizer.bl:CreateTexture(nil, "OVERLAY");
  moversizer.bl.b:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.bl.b:SetBlendMode("ADD");
  moversizer.bl.b:SetTexCoord(0.5, 0, 0.5, 1, 1, 0, 1, 1);
  moversizer.bl.b:SetPoint("BOTTOMLEFT", moversizer.bl.l, "BOTTOMRIGHT");
  moversizer.bl.b:SetPoint("TOPRIGHT", moversizer.bl, "RIGHT");
  moversizer.bl.Highlight = function()
    moversizer.bl.l:Show();
    moversizer.bl.b:Show();
  end
  moversizer.bl.Clear = function()
    moversizer.bl.l:Hide();
    moversizer.bl.b:Hide();
  end
  moversizer.bl.Clear();
  
  moversizer.br = CreateFrame("FRAME", nil, moversizer);
  moversizer.br:EnableMouse();
  moversizer.br:SetWidth(16);
  moversizer.br:SetHeight(16);
  moversizer.br:SetPoint("BOTTOMRIGHT", moversizer, "BOTTOMRIGHT");
  moversizer.br.r = moversizer.br:CreateTexture(nil, "OVERLAY");
  moversizer.br.r:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.br.r:SetBlendMode("ADD");
  moversizer.br.r:SetTexCoord(1, 0, 0.5, 0, 1, 1, 0.5, 1);
  moversizer.br.r:SetPoint("BOTTOMRIGHT", moversizer.br, "BOTTOMRIGHT", -3, 3);
  moversizer.br.r:SetPoint("TOPLEFT", moversizer.br, "TOP");
  moversizer.br.b = moversizer.br:CreateTexture(nil, "OVERLAY");
  moversizer.br.b:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.br.b:SetBlendMode("ADD");
  moversizer.br.b:SetTexCoord(0, 0, 0, 1, 0.5, 0, 0.5, 1);
  moversizer.br.b:SetPoint("BOTTOMRIGHT", moversizer.br.r, "BOTTOMLEFT");
  moversizer.br.b:SetPoint("TOPLEFT", moversizer.br, "LEFT");
  moversizer.br.Highlight = function()
    moversizer.br.r:Show();
    moversizer.br.b:Show();
  end
  moversizer.br.Clear = function()
    moversizer.br.r:Hide();
    moversizer.br.b:Hide();
  end
  moversizer.br.Clear();
  
  moversizer.tl = CreateFrame("FRAME", nil, moversizer);
  moversizer.tl:EnableMouse();
  moversizer.tl:SetWidth(16);
  moversizer.tl:SetHeight(16);
  moversizer.tl:SetPoint("TOPLEFT", moversizer, "TOPLEFT");
  moversizer.tl.l = moversizer.tl:CreateTexture(nil, "OVERLAY");
  moversizer.tl.l:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.tl.l:SetBlendMode("ADD");
  moversizer.tl.l:SetTexCoord(0.5, 0, 0, 0, 0.5, 1, 0, 1);
  moversizer.tl.l:SetPoint("TOPLEFT", moversizer.tl, "TOPLEFT", 3, -3);
  moversizer.tl.l:SetPoint("BOTTOMRIGHT", moversizer.tl, "BOTTOM");
  moversizer.tl.t = moversizer.tl:CreateTexture(nil, "OVERLAY");
  moversizer.tl.t:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.tl.t:SetBlendMode("ADD");
  moversizer.tl.t:SetTexCoord(0.5, 0, 0.5, 1, 1, 0, 1, 1);
  moversizer.tl.t:SetPoint("TOPLEFT", moversizer.tl.l, "TOPRIGHT");
  moversizer.tl.t:SetPoint("BOTTOMRIGHT", moversizer.tl, "RIGHT");
  moversizer.tl.Highlight = function()
    moversizer.tl.l:Show();
    moversizer.tl.t:Show();
  end
  moversizer.tl.Clear = function()
    moversizer.tl.l:Hide();
    moversizer.tl.t:Hide();
  end
  moversizer.tl.Clear();
  
  moversizer.tr = CreateFrame("FRAME", nil, moversizer);
  moversizer.tr:EnableMouse();
  moversizer.tr:SetWidth(16);
  moversizer.tr:SetHeight(16);
  moversizer.tr:SetPoint("TOPRIGHT", moversizer, "TOPRIGHT");
  moversizer.tr.r = moversizer.tr:CreateTexture(nil, "OVERLAY");
  moversizer.tr.r:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.tr.r:SetBlendMode("ADD");
  moversizer.tr.r:SetTexCoord(0.5, 0, 0, 0, 0.5, 1, 0, 1);
  moversizer.tr.r:SetPoint("TOPRIGHT", moversizer.tr, "TOPRIGHT", -3, -3);
  moversizer.tr.r:SetPoint("BOTTOMLEFT", moversizer.tr, "BOTTOM");
  moversizer.tr.t = moversizer.tr:CreateTexture(nil, "OVERLAY");
  moversizer.tr.t:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.tr.t:SetBlendMode("ADD");
  moversizer.tr.t:SetTexCoord(0, 0, 0, 1, 0.5, 0, 0.5, 1);
  moversizer.tr.t:SetPoint("TOPRIGHT", moversizer.tr.r, "TOPLEFT");
  moversizer.tr.t:SetPoint("BOTTOMLEFT", moversizer.tr, "LEFT");
  moversizer.tr.Highlight = function()
    moversizer.tr.r:Show();
    moversizer.tr.t:Show();
  end
  moversizer.tr.Clear = function()
    moversizer.tr.r:Hide();
    moversizer.tr.t:Hide();
  end
  moversizer.tr.Clear();
  
  moversizer.l = CreateFrame("FRAME", nil, moversizer);
  moversizer.l:EnableMouse();
  moversizer.l:SetWidth(8);
  moversizer.l:SetPoint("TOPLEFT", moversizer.tl, "BOTTOMLEFT");
  moversizer.l:SetPoint("BOTTOMLEFT", moversizer.bl, "TOPLEFT");
  moversizer.l.l = moversizer.l:CreateTexture(nil, "OVERLAY");
  moversizer.l.l:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.l.l:SetBlendMode("ADD");
  moversizer.l.l:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1);
  moversizer.l.l:SetPoint("BOTTOMLEFT", moversizer.bl, "BOTTOMLEFT", 3, 3);
  moversizer.l.l:SetPoint("TOPRIGHT", moversizer.tl, "TOP", 0, -3);
  moversizer.l.Highlight = function()
    moversizer.l.l:Show();
  end
  moversizer.l.Clear = function()
    moversizer.l.l:Hide();
  end
  moversizer.l.Clear();
  
  moversizer.b = CreateFrame("FRAME", nil, moversizer);
  moversizer.b:EnableMouse();
  moversizer.b:SetHeight(8);
  moversizer.b:SetPoint("BOTTOMLEFT", moversizer.bl, "BOTTOMRIGHT");
  moversizer.b:SetPoint("BOTTOMRIGHT", moversizer.br, "BOTTOMLEFT");
  moversizer.b.b = moversizer.b:CreateTexture(nil, "OVERLAY");
  moversizer.b.b:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.b.b:SetBlendMode("ADD");
  moversizer.b.b:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1);
  moversizer.b.b:SetPoint("BOTTOMLEFT", moversizer.bl, "BOTTOMLEFT", 3, 3);
  moversizer.b.b:SetPoint("TOPRIGHT", moversizer.br, "RIGHT", -3, 0);
  moversizer.b.Highlight = function()
    moversizer.b.b:Show();
  end
  moversizer.b.Clear = function()
    moversizer.b.b:Hide();
  end
  moversizer.b.Clear();
  
  moversizer.r = CreateFrame("FRAME", nil, moversizer);
  moversizer.r:EnableMouse();
  moversizer.r:SetWidth(8);
  moversizer.r:SetPoint("BOTTOMRIGHT", moversizer.br, "TOPRIGHT");
  moversizer.r:SetPoint("TOPRIGHT", moversizer.tr, "BOTTOMRIGHT");
  moversizer.r.r = moversizer.r:CreateTexture(nil, "OVERLAY");
  moversizer.r.r:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.r.r:SetBlendMode("ADD");
  moversizer.r.r:SetPoint("BOTTOMRIGHT", moversizer.br, "BOTTOMRIGHT", -3, 3);
  moversizer.r.r:SetPoint("TOPLEFT", moversizer.tr, "TOP", 0, -3);
  moversizer.r.Highlight = function()
    moversizer.r.r:Show();
  end
  moversizer.r.Clear = function()
    moversizer.r.r:Hide();
  end
  moversizer.r.Clear();
  
  moversizer.t = CreateFrame("FRAME", nil, moversizer);
  moversizer.t:EnableMouse();
  moversizer.t:SetHeight(8);
  moversizer.t:SetPoint("TOPRIGHT", moversizer.tr, "TOPLEFT");
  moversizer.t:SetPoint("TOPLEFT", moversizer.tl, "TOPRIGHT");
  moversizer.t.t = moversizer.t:CreateTexture(nil, "OVERLAY");
  moversizer.t.t:SetTexture("Interface\\BUTTONS\\UI-Listbox-Highlight.blp");
  moversizer.t.t:SetBlendMode("ADD");
  moversizer.t.t:SetPoint("TOPRIGHT", moversizer.tr, "TOPRIGHT", -3, -3);
  moversizer.t.t:SetPoint("BOTTOMLEFT", moversizer.tl, "LEFT", 3, 0);
  moversizer.t.Highlight = function()
    moversizer.t.t:Show();
  end
  moversizer.t.Clear = function()
    moversizer.t.t:Hide();
  end
  moversizer.t.Clear();
  
  local mover = CreateFrame("FRAME", nil, moversizer);
  frame.mover = mover;
  mover:EnableMouse();
  mover.moving = {};
  mover.interims = {};
  mover.selfPointIcon = mover:CreateTexture();
  mover.selfPointIcon:SetTexture("Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons.blp");
  mover.selfPointIcon:SetWidth(16);
  mover.selfPointIcon:SetHeight(16);
  mover.selfPointIcon:SetTexCoord(0, 0.25, 0, 1);
  mover.anchorPointIcon = mover:CreateTexture();
  mover.anchorPointIcon:SetTexture("Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons.blp");
  mover.anchorPointIcon:SetWidth(16);
  mover.anchorPointIcon:SetHeight(16);
  mover.anchorPointIcon:SetTexCoord(0, 0.25, 0, 1);
  
  local moverText = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  mover.text = moverText;
  moverText:Hide();
  
  local sizerText = moversizer:CreateFontString(nil, "OVERLAY", "GameFontNormal");
  moversizer.text = sizerText;
  sizerText:Hide();
  
  moversizer.ScaleCorners = function(self, width, height)
    local limit = math.min(width, height) + 16;
    local size = 16;
    if(limit <= 40) then
      size = limit * (2/5);
    end
    moversizer.bl:SetWidth(size);
    moversizer.bl:SetHeight(size);
    moversizer.br:SetWidth(size);
    moversizer.br:SetHeight(size);
    moversizer.tr:SetWidth(size);
    moversizer.tr:SetHeight(size);
    moversizer.tl:SetWidth(size);
    moversizer.tl:SetHeight(size);
  end
  
  moversizer.SetToRegion = function(self, region, data)
    mover.moving.region = region;
    mover.moving.data = data;
    local xOff, yOff;
    mover.selfPoint, mover.anchor, mover.anchorPoint, xOff, yOff = region:GetPoint(1);
    mover:ClearAllPoints();
    moversizer:ClearAllPoints();
    if(data.regionType == "group") then
      mover:SetWidth(region.trx - region.blx);
      mover:SetHeight(region.try - region.bly);
      mover:SetPoint(mover.selfPoint, mover.anchor, mover.anchorPoint, xOff + region.blx, yOff + region.bly);
    else
      mover:SetWidth(region:GetWidth());
      mover:SetHeight(region:GetHeight());
      mover:SetPoint(mover.selfPoint, mover.anchor, mover.anchorPoint, xOff, yOff);
    end
    moversizer:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", -8, -8);
    moversizer:SetPoint("TOPRIGHT", mover, "TOPRIGHT", 8, 8);
    moversizer:ScaleCorners(region:GetWidth(), region:GetHeight());
    
    mover.startMoving = function()
      WeakAuras.CancelAnimation("display", data.id, true, true, true, true);
      mover:ClearAllPoints();
      if(data.regionType == "group") then
        mover:SetPoint(mover.selfPoint, region, mover.anchorPoint, region.blx, region.bly);
      else
        mover:SetPoint(mover.selfPoint, region, mover.selfPoint);
      end
      region:StartMoving();
      mover.isMoving = true;
      mover.text:Show();
    end
    
    mover.doneMoving = function(self)
      region:StopMovingOrSizing();
      mover.isMoving = false;
      mover.text:Hide();
      
      if(data.xOffset and data.yOffset) then
        local selfX, selfY = mover.selfPointIcon:GetCenter();
        local anchorX, anchorY = mover.anchorPointIcon:GetCenter();
        local dX = selfX - anchorX;
        local dY = selfY - anchorY;
        data.xOffset = dX;
        data.yOffset = dY;
      end
      WeakAuras.Add(data);
      WeakAuras.SetThumbnail(data);
      region:SetPoint(self.selfPoint, self.anchor, self.anchorPoint, data.xOffset, data.yOffset);
      mover.selfPoint, mover.anchor, mover.anchorPoint, xOff, yOff = region:GetPoint(1);
      mover:ClearAllPoints();
      if(data.regionType == "group") then
        mover:SetWidth(region.trx - region.blx);
        mover:SetHeight(region.try - region.bly);
        mover:SetPoint(mover.selfPoint, mover.anchor, mover.anchorPoint, xOff + region.blx, yOff + region.bly);
      else
        mover:SetWidth(region:GetWidth());
        mover:SetHeight(region:GetHeight());
        mover:SetPoint(mover.selfPoint, mover.anchor, mover.anchorPoint, xOff, yOff);
      end
      if(data.parent) then
        local parentData = db.displays[data.parent];
        if(parentData) then
          WeakAuras.Add(parentData);
          WeakAuras.SetThumbnail(parentData);
        end
      end
      AceConfigDialog:Open("WeakAuras", container);
      WeakAuras.Animate("display", data.id, "main", data.animation.main, WeakAuras.regions[data.id].region, false, nil, true);
    end
    
    if(data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") then
      mover:SetScript("OnMouseDown", nil);
	    mover:SetScript("OnMouseUp", nil);
    else
      mover:SetScript("OnMouseDown", mover.startMoving);
      mover:SetScript("OnMouseUp", mover.doneMoving);
    end
    
    if(region:IsResizable()) then
      moversizer.startSizing = function(point)
        mover.isMoving = true;
        WeakAuras.CancelAnimation("display", data.id, true, true, true, true);
        local rSelfPoint, rAnchor, rAnchorPoint, rXOffset, rYOffset = region:GetPoint(1);
        region:StartSizing(point);
        local textpoint, anchorpoint;
        if(point:find("BOTTOM")) then textpoint = "TOP"; anchorpoint = "BOTTOM";
        elseif(point:find("TOP")) then textpoint = "BOTTOM"; anchorpoint = "TOP";
        elseif(point:find("LEFT")) then textpoint = "RIGHT"; anchorpoint = "LEFT";
        elseif(point:find("RIGHT")) then textpoint = "LEFT"; anchorpoint = "RIGHT"; end
        moversizer.text:ClearAllPoints();
        moversizer.text:SetPoint(textpoint, moversizer, anchorpoint);
        moversizer.text:Show();
        mover:SetAllPoints(region);
        moversizer:SetScript("OnUpdate", function()
          moversizer.text:SetText(("(%.2f, %.2f)"):format(region:GetWidth(), region:GetHeight()));
          if(data.width and data.height) then
            data.width = region:GetWidth();
            data.height = region:GetHeight();
          end
          WeakAuras.Add(data);
          region:ClearAllPoints();
          region:SetPoint(rSelfPoint, rAnchor, rAnchorPoint, rXOffset, rYOffset);
          moversizer:ScaleCorners(region:GetWidth(), region:GetHeight());
          AceConfigDialog:Open("WeakAuras", container);
        end);
      end
      
      moversizer.doneSizing = function()
        mover.isMoving = false;
        region:StopMovingOrSizing();
        WeakAuras.Add(data);
        WeakAuras.SetThumbnail(data);
        if(data.parent) then
          local parentData = db.displays[data.parent];
          WeakAuras.Add(parentData);
          WeakAuras.SetThumbnail(parentData);
        end
        moversizer.text:Hide();
        moversizer:SetScript("OnUpdate", nil);
        mover:ClearAllPoints();
        mover:SetWidth(region:GetWidth());
        mover:SetHeight(region:GetHeight());
        mover:SetPoint(mover.selfPoint, mover.anchor, mover.anchorPoint, xOff, yOff);
        WeakAuras.Animate("display", data.id, "main", data.animation.main, WeakAuras.regions[data.id].region, false, nil, true);
      end
      
      moversizer.bl:SetScript("OnMouseDown", function() moversizer.startSizing("BOTTOMLEFT") end);
      moversizer.bl:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.bl:SetScript("OnEnter", moversizer.bl.Highlight);
      moversizer.bl:SetScript("OnLeave", moversizer.bl.Clear);
      moversizer.b:SetScript("OnMouseDown", function() moversizer.startSizing("BOTTOM") end);
      moversizer.b:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.b:SetScript("OnEnter", moversizer.b.Highlight);
      moversizer.b:SetScript("OnLeave", moversizer.b.Clear);
      moversizer.br:SetScript("OnMouseDown", function() moversizer.startSizing("BOTTOMRIGHT") end);
      moversizer.br:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.br:SetScript("OnEnter", moversizer.br.Highlight);
      moversizer.br:SetScript("OnLeave", moversizer.br.Clear);
      moversizer.r:SetScript("OnMouseDown", function() moversizer.startSizing("RIGHT") end);
      moversizer.r:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.r:SetScript("OnEnter", moversizer.r.Highlight);
      moversizer.r:SetScript("OnLeave", moversizer.r.Clear);
      moversizer.tr:SetScript("OnMouseDown", function() moversizer.startSizing("TOPRIGHT") end);
      moversizer.tr:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.tr:SetScript("OnEnter", moversizer.tr.Highlight);
      moversizer.tr:SetScript("OnLeave", moversizer.tr.Clear);
      moversizer.t:SetScript("OnMouseDown", function() moversizer.startSizing("TOP") end);
      moversizer.t:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.t:SetScript("OnEnter", moversizer.t.Highlight);
      moversizer.t:SetScript("OnLeave", moversizer.t.Clear);
      moversizer.tl:SetScript("OnMouseDown", function() moversizer.startSizing("TOPLEFT") end);
      moversizer.tl:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.tl:SetScript("OnEnter", moversizer.tl.Highlight);
      moversizer.tl:SetScript("OnLeave", moversizer.tl.Clear);
      moversizer.l:SetScript("OnMouseDown", function() moversizer.startSizing("LEFT") end);
      moversizer.l:SetScript("OnMouseUp", moversizer.doneSizing);
      moversizer.l:SetScript("OnEnter", moversizer.l.Highlight);
      moversizer.l:SetScript("OnLeave", moversizer.l.Clear);
      
      moversizer.bl:Show();
      moversizer.b:Show();
      moversizer.br:Show();
      moversizer.r:Show();
      moversizer.tr:Show();
      moversizer.t:Show();
      moversizer.tl:Show();
      moversizer.l:Show();
    else
      moversizer.bl:Hide();
      moversizer.b:Hide();
      moversizer.br:Hide();
      moversizer.r:Hide();
      moversizer.tr:Hide();
      moversizer.t:Hide();
      moversizer.tl:Hide();
      moversizer.l:Hide();
    end
    moversizer:Show();
  end
  
  local function EnsureTexture(self, texture)
    if(texture) then
      return texture;
    else
      local ret = self:CreateTexture();
      ret:SetTexture("Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons.blp");
      ret:SetWidth(16);
      ret:SetHeight(16);
      ret:SetTexCoord(0, 0.25, 0, 1);
      ret:SetVertexColor(1, 1, 1, 0.25);
      return ret;
    end
  end
    
  mover:SetScript("OnUpdate", function(self, elaps)
    local region = self.moving.region;
    local data = self.moving.data;
    if not(self.isMoving) then
      self.selfPoint, self.anchor, self.anchorPoint = region:GetPoint(1);
    end
    self.selfPointIcon:ClearAllPoints();
    self.selfPointIcon:SetPoint("CENTER", region, self.selfPoint);
    local selfX, selfY = self.selfPointIcon:GetCenter();
    selfX, selfY = selfX or 0, selfY or 0;
    self.anchorPointIcon:ClearAllPoints();
    self.anchorPointIcon:SetPoint("CENTER", self.anchor, self.anchorPoint);
    local anchorX, anchorY = self.anchorPointIcon:GetCenter();
    anchorX, anchorY = anchorX or 0, anchorY or 0;
    if(data.parent and db.displays[data.parent] and db.displays[data.parent].regionType == "dynamicgroup") then
      self.selfPointIcon:Hide();
      self.anchorPointIcon:Hide();
    else
      self.selfPointIcon:Show();
      self.anchorPointIcon:Show();
    end
    
    local dX = selfX - anchorX;
    local dY = selfY - anchorY;
    local distance = sqrt(dX^2 + dY^2);
    local angle = atan2(dY, dX);
    
    local numInterim = floor(distance/40);
    
    for index, texture in pairs(self.interims) do
      texture:Hide();
    end
    for i = 1, numInterim  do
      local x = (distance - (i * 40)) * cos(angle);
      local y = (distance - (i * 40)) * sin(angle);
      self.interims[i] = EnsureTexture(self, self.interims[i]);
      self.interims[i]:ClearAllPoints();
      self.interims[i]:SetPoint("CENTER", self.anchorPointIcon, "CENTER", x, y);
      self.interims[i]:Show();
    end
    
    self.text:SetText(("(%.2f, %.2f)"):format(dX, dY));
    local midx = (distance / 2) * cos(angle);
    local midy = (distance / 2) * sin(angle);
    self.text:SetPoint("CENTER", self.anchorPointIcon, "CENTER", midx, midy);
    if((midx > 0 and self.text:GetRight() > moversizer:GetLeft()) or (midx < 0 and self.text:GetLeft() < moversizer:GetRight())) then
      if(midy > 0 and self.text:GetTop() > moversizer:GetBottom()) then
        midy = midy - (self.text:GetTop() - moversizer:GetBottom());
      elseif(midy < 0 and self.text:GetBottom() < moversizer:GetTop()) then
        midy = midy + (moversizer:GetTop() - self.text:GetBottom());
      end
    end
    self.text:SetPoint("CENTER", self.anchorPointIcon, "CENTER", midx, midy);
  end);
  
  local newButton = AceGUI:Create("WeakAurasNewHeaderButton");
  newButton:SetText(L["New"]);
  newButton:SetClick(function() frame:PickOption("New") end);
  newButton.frame:SetScript("OnUpdate", function()
    if(pickonupdate) then
      frame:PickDisplay(pickonupdate);
      pickonupdate = nil;
    end
  end);
  frame.newButton = newButton;
  
  local loadedButton = AceGUI:Create("WeakAurasLoadedHeaderButton");
  loadedButton:SetText(L["Loaded"]);
  loadedButton:Disable();
  loadedButton:EnableExpand();
  loadedButton:Expand();
  loadedButton:SetOnExpandCollapse(WeakAuras.SortDisplayButtons);
  loadedButton:SetExpandDescription(L["Expand all loaded displays"]);
  loadedButton:SetCollapseDescription(L["Collapse all loaded displays"]);
  loadedButton:SetViewClick(function()
    if(loadedButton.view.func() == 2) then
      for id, child in pairs(displayButtons) do
        if(loaded[id]) then
          child:PriorityHide(2);
        end
      end
    else
      for id, child in pairs(displayButtons) do
        if(loaded[id]) then
          child:PriorityShow(2);
        end
      end
    end
  end);
  loadedButton:SetViewTest(function()
    local none, all = true, true;
    for id, child in pairs(displayButtons) do
      if(loaded[id]) then
        if(child:GetVisibility() ~= 2) then
          all = false;
        end
        if(child:GetVisibility() ~= 0) then
          none = false;
        end
      end
    end
    if(all) then
      return 2;
    elseif(none) then
      return 0;
    else
      return 1;
    end
  end);
  loadedButton:SetViewDescription(L["Toggle the visibility of all loaded displays"]);
  frame.loadedButton = loadedButton;
  
  local unloadedButton = AceGUI:Create("WeakAurasLoadedHeaderButton");
  unloadedButton:SetText(L["Not Loaded"]);
  unloadedButton:Disable();
  unloadedButton:EnableExpand();
  unloadedButton:Expand();
  unloadedButton:SetOnExpandCollapse(WeakAuras.SortDisplayButtons);
  unloadedButton:SetExpandDescription(L["Expand all non-loaded displays"]);
  unloadedButton:SetCollapseDescription(L["Collapse all non-loaded displays"]);
  unloadedButton:SetViewClick(function()
    if(unloadedButton.view.func() == 2) then
      for id, child in pairs(displayButtons) do
        if not(loaded[id]) then
          child:PriorityHide(2);
        end
      end
    else
      for id, child in pairs(displayButtons) do
        if not(loaded[id]) then
          child:PriorityShow(2);
        end
      end
    end
  end);
  unloadedButton:SetViewTest(function()
    local none, all = true, true;
    for id, child in pairs(displayButtons) do
      if not(loaded[id]) then
        if(child:GetVisibility() ~= 2) then
          all = false;
        end
        if(child:GetVisibility() ~= 0) then
          none = false;
        end
      end
    end
    if(all) then
      return 2;
    elseif(none) then
      return 0;
    else
      return 1;
    end
  end);
  unloadedButton:SetViewDescription(L["Toggle the visibility of all non-loaded displays"]);
  frame.unloadedButton = unloadedButton;
  
  frame.FillOptions = function(self, optionTable)
    AceConfig:RegisterOptionsTable("WeakAuras", optionTable);
    AceConfigDialog:Open("WeakAuras", container);
    container:SetTitle("");
  end
  
  frame.ClearPicks = function(self, except)
    for id, button in pairs(displayButtons) do
      button:ClearPick();
    end
    newButton:ClearPick();
    loadedButton:ClearPick();
    unloadedButton:ClearPick();
    container:ReleaseChildren();
    self.moversizer:Hide();
  end
  
  frame.PickOption = function(self, option)
    self:ClearPicks();
    self.moversizer:Hide();
    if(option == "New") then
      newButton:Pick();
      
      local containerScroll = AceGUI:Create("ScrollFrame");
      containerScroll:SetLayout("flow");
      container:SetLayout("fill");
      container:AddChild(containerScroll);
      
      for regionType, regionData in pairs(regionOptions) do
        local button = AceGUI:Create("WeakAurasNewButton");
        button:SetTitle(regionData.displayName);
        if(type(regionData.icon) == "string") then
          button:SetIcon(regionData.icon);
        elseif(type(regionData.icon) == "function") then
          button:SetIcon(regionData.icon());
        end
        button:SetDescription(regionData.description);
        button:SetClick(function()
          local new_id = "New";
          local num = 2;
          while(db.displays[new_id]) do
            new_id = "New "..num;
            num = num + 1;
          end
          
          local data = {
            id = new_id,
            regionType = regionType,
            trigger = {
              type = "aura",
              unit = "player",
              debuffType = "HELPFUL"
            },
            load = {}
          };
          WeakAuras.Add(data);
          WeakAuras.ScanForLoads();
          WeakAuras.EnsureDisplayButton(db.displays[new_id]);
          WeakAuras.UpdateDisplayButton(db.displays[new_id]);
          if(WeakAuras.regions[new_id].region.SetStacks) then
            WeakAuras.regions[new_id].region:SetStacks(1);
          end
          frame.buttonsScroll:AddChild(displayButtons[new_id]);
          WeakAuras.AddOption(new_id, data);
          WeakAuras.SetIconNames(data);
          WeakAuras.SortDisplayButtons();
          pickonupdate = new_id;
          displayButtons[new_id].rename:Click();
        end);
        containerScroll:AddChild(button);
      end
    else
      error("An options button other than New was selected... but there are no other options buttons!");
    end
  end
  
  frame.PickDisplay = function(self, id)
    self:ClearPicks();
    displayButtons[id]:Pick();
    local data = db.displays[id];
    if(data.controlledChildren) then
      for index, childId in pairs(data.controlledChildren) do
        displayButtons[childId]:PriorityShow(1);
      end
    end
    WeakAuras.ReloadTriggerOptions(data);
    self:FillOptions(displayOptions[id]);
    WeakAuras.regions[id].region:Collapse();
    WeakAuras.regions[id].region:Expand();
    self.moversizer:SetToRegion(WeakAuras.regions[id].region, db.displays[id]);
    local _, _, _, _, yOffset = displayButtons[id].frame:GetPoint(1);
    frame.buttonsScroll:SetScrollPos(yOffset, yOffset - 32);
  end
  
  return frame;
end

function WeakAuras.LayoutDisplayButtons()
  --Make sure there is a button defined for every display
  for id, data in pairs(db.displays) do
    WeakAuras.EnsureDisplayButton(data);
    WeakAuras.UpdateDisplayButton(data);
  end
  
  frame.buttonsScroll:AddChild(frame.newButton);
  frame.buttonsScroll:AddChild(frame.loadedButton);
  
  for id, button in pairs(displayButtons) do
    if(loaded[id]) then
      frame.buttonsScroll:AddChild(button);
    end
  end
  
  frame.buttonsScroll:AddChild(frame.unloadedButton);
  
  for id, button in pairs(displayButtons) do
    if not(loaded[id]) then
      frame.buttonsScroll:AddChild(button);
    end
  end
  
  WeakAuras.SortDisplayButtons();
end

function WeakAuras.SortDisplayButtons()
  wipe(frame.buttonsScroll.children);
  tinsert(frame.buttonsScroll.children, frame.newButton);
  tinsert(frame.buttonsScroll.children, frame.loadedButton);
  local numLoaded = 0;
  local to_sort = {};
  local children = {};
  for id, child in pairs(displayButtons) do
    if(frame.loadedButton:GetExpanded()) then
      child.frame:Show();
      local group = child:GetGroup();
      if(group) then
        if(loaded[group]) then
          if(loaded[id]) then
            child:EnableLoaded();
          else
            child:DisableLoaded();
          end
          children[group] = children[group] or {};
          tinsert(children[group], child);
        end
      else
        if(loaded[id]) then
          child:EnableLoaded();
          tinsert(to_sort, child);
        end
      end
    else
      child.frame:Hide();
    end
  end
  table.sort(to_sort, function(a, b) return a:GetTitle() < b:GetTitle() end);
  for _, child in ipairs(to_sort) do
    tinsert(frame.buttonsScroll.children, child);
    local controlledChildren = children[child:GetTitle()];
    if(controlledChildren) then
      table.sort(controlledChildren, function(a, b) return a:GetGroupOrder() < b:GetGroupOrder(); end);
      for _, groupchild in ipairs(controlledChildren) do
        if(child:GetExpanded()) then
          tinsert(frame.buttonsScroll.children, groupchild);
        else
          groupchild.frame:Hide();
        end
      end
    end
  end
  
  tinsert(frame.buttonsScroll.children, frame.unloadedButton);
  local numUnloaded = 0;
  wipe(to_sort);
  wipe(children);
  for id, child in pairs(displayButtons) do
    if(frame.unloadedButton:GetExpanded()) then
      local group = child:GetGroup();
      if(group) then
        if not(loaded[group]) then
          if(loaded[id]) then
            child:EnableLoaded();
          else
            child:DisableLoaded();
          end
          children[group] = children[group] or {};
          tinsert(children[group], child);
        end
      else
        if not(loaded[id]) then
          child:DisableLoaded();
          tinsert(to_sort, child);
        end
      end
    else
      child.frame:Hide();
    end
  end
  table.sort(to_sort, function(a, b) return a:GetTitle() < b:GetTitle() end);
  for _, child in ipairs(to_sort) do
    tinsert(frame.buttonsScroll.children, child);
    local controlledChildren = children[child:GetTitle()];
    if(controlledChildren) then
      table.sort(controlledChildren, function(a, b) return a:GetGroupOrder() < b:GetGroupOrder(); end);
      for _, groupchild in ipairs(controlledChildren) do
        if(child:GetExpanded()) then
          tinsert(frame.buttonsScroll.children, groupchild);
        else
          groupchild.frame:Hide();
        end
      end
    end
  end
  
  frame.buttonsScroll:DoLayout();
end

WeakAuras.loadFrame:SetScript("OnEvent", function()
  WeakAuras.ScanForLoads();
  if(frame) then
    WeakAuras.SortDisplayButtons();
  end
end);

function WeakAuras.EnsureDisplayButton(data)
  local id = data.id;
  if not(displayButtons[id]) then
    displayButtons[id] = AceGUI:Create("WeakAurasDisplayButton");
  end
end
      
function WeakAuras.UpdateDisplayButton(data)
  local id = data.id;
  local button = displayButtons[id];
  if not(button) then
    error("Button for "..id.." was not found!");
  else
    if(regionOptions[data.regionType]) then
      button:SetIcon(WeakAuras.SetThumbnail(data));
    else
      button:SetIcon("Interface\\Icons\\INV_Misc_QuestionMark");
    end
    
    button:SetTitle(data.id);
    button:SetData(data);
    
    if(frame.copying) then
      if(data.id == frame.copying.id) then
        button:SetClick(function()
          frame.copying = nil;
          for id, data in pairs(db.displays) do
            WeakAuras.EnsureDisplayButton(data)
            WeakAuras.UpdateDisplayButton(data);
          end
          button:ReloadTooltip();
        end);
        button:SetDescription(L["Cancel"], L["Do not copy any settings"]);
      else
        if(data.regionType == frame.copying.regionType) then
          button:SetClick(function()
            WeakAuras.Copy(data.id, frame.copying.id);
            WeakAuras.ScanForLoads();
            WeakAuras.SetIconNames(frame.copying);
            WeakAuras.SortDisplayButtons();
            WeakAuras.AddOption(frame.copying.id, frame.copying);
            frame:PickDisplay(frame.copying.id);
            frame.copying = nil;
            for id, data in pairs(db.displays) do
              WeakAuras.EnsureDisplayButton(data)
              WeakAuras.UpdateDisplayButton(data);
            end
            button:ReloadTooltip();
          end);
          button:SetDescription(data.id, L["Copy settings from %s"]:format(data.id));
        else
          button:Disable();
        end
      end
    elseif(frame.grouping) then
      if(data.id == frame.grouping.id) then
        button:SetClick(function()
          frame.grouping = nil;
          for id, data in pairs(db.displays) do
            WeakAuras.EnsureDisplayButton(data)
            WeakAuras.UpdateDisplayButton(data);
          end
          button:ReloadTooltip();
        end);
        button:SetDescription(L["Cancel"], L["Do not group this display"]);
      else
        if(data.regionType == "group" or data.regionType == "dynamicgroup") then
          button:SetClick(function()
            tinsert(data.controlledChildren, frame.grouping.id);
            displayButtons[frame.grouping.id]:SetGroup(id, data.regionType == "dynamicgroup");
            displayButtons[frame.grouping.id]:SetGroupOrder(#data.controlledChildren, #data.controlledChildren);
            frame.grouping.parent = id;
            WeakAuras.Add(data);
            WeakAuras.Add(frame.grouping);
            frame.grouping = nil;
            WeakAuras.ReloadGroupRegionOptions(data);
            for id, data in pairs(db.displays) do
              WeakAuras.EnsureDisplayButton(data);
              WeakAuras.UpdateDisplayButton(data);
            end
            WeakAuras.SortDisplayButtons();
            button:ReloadTooltip();
            frame:PickDisplay(id);
          end);
          button:SetDescription(data.id, L["Add to group %s"]:format(data.id));
        else
          button:Disable();
        end
      end
    else
      button:SetClick(function()
        frame:PickDisplay(id);
      end);
      local namestable = {};
      if(data.controlledChildren) then
        for index, childId in pairs(data.controlledChildren) do
          tinsert(namestable, {" ", childId});
        end
        if(#namestable > 0) then
          namestable[1][1] = L["Children:"];
        else
          namestable[1] = L["No Children"];
        end
      elseif(data.trigger.type == "aura") then
        for index, name in pairs(data.trigger.names) do
          local icon = iconCache[name] or "Interface\\Icons\\INV_Misc_QuestionMark";
          tinsert(namestable, {" ", name, icon});
        end
        if(#namestable > 0) then
          if(#namestable > 1) then
            namestable[1][1] = L["Auras:"];
          else
            namestable[1][1] = L["Aura:"];
          end
        end
      elseif(data.trigger.type == "event") then
        tinsert(namestable, {L["Trigger:"], (event_types[data.trigger.event] or L["Undefined"])});
        if(data.trigger.event == "Combat Log" and data.trigger.subeventPrefix and data.trigger.subeventSuffix) then
          tinsert(namestable, {L["Message type:"], (subevent_prefix_types[data.trigger.subeventPrefix] or L["Undefined"]).." "..(subevent_suffix_types[data.trigger.subeventSuffix] or L["Undefined"])});
        end
      end
      local regionData = regionOptions[data.regionType or ""]
      local displayName = regionData and regionData.displayName or "";
      button:SetDescription({data.id, displayName}, unpack(namestable));
      button:Enable();
    end
    
    button:SetCopyClick(function()
      frame:PickDisplay(id);
      frame.grouping = nil;
      frame.copying = data;
      for id, data in pairs(db.displays) do
        WeakAuras.EnsureDisplayButton(data);
        WeakAuras.UpdateDisplayButton(data);
      end
    end);
    button:SetDeleteClick(function()
      if(IsShiftKeyDown()) then
        local parentData;
        if(data.parent) then
          parentData = db.displays[data.parent];
        end
        
        if(data.controlledChildren) then
          for index, childId in pairs(data.controlledChildren) do
            local childButton = displayButtons[childId];
            if(childButton) then
              childButton:SetGroup();
            end
            local childData = db.displays[childId];
            if(childData) then
              childData.parent = nil;
            end
          end
        end
        
        WeakAuras.Delete(data);
        frame.buttonsScroll:DeleteChild(displayButtons[id]);
        frame:ClearPicks();
        thumbnails[id].region:Hide();
        thumbnails[id] = nil;
        displayButtons[id] = nil;
        
        if(parentData and parentData.controlledChildren) then
          for index, childId in pairs(parentData.controlledChildren) do
            local childButton = displayButtons[childId];
            if(childButton) then
              childButton:SetGroupOrder(index, #parentData.controlledChildren);
            end
          end
          WeakAuras.Add(parentData);
          WeakAuras.ReloadGroupRegionOptions(parentData);
        end
        
        frame.copying = nil;
        frame.grouping = nil;
        for id, data in pairs(db.displays) do
          WeakAuras.EnsureDisplayButton(data);
          WeakAuras.UpdateDisplayButton(data);
        end
      end
    end);
    if(data.controlledChildren) then
      button:SetViewClick(function()
        if(button.view.func() == 2) then
          for index, childId in ipairs(data.controlledChildren) do
            displayButtons[childId]:PriorityHide(2);
          end
        else
          for index, childId in ipairs(data.controlledChildren) do
            displayButtons[childId]:PriorityShow(2);
          end
        end
      end);
      button:SetViewTest(function()
        local none, all = true, true;
        for index, childId in ipairs(data.controlledChildren) do
          if(displayButtons[childId]) then
            if(displayButtons[childId]:GetVisibility() ~= 2) then
              all = false;
            end
            if(displayButtons[childId]:GetVisibility() ~= 0) then
              none = false;
            end
          end
        end
        if(all) then
          return 2;
        elseif(none) then
          return 0;
        else
          return 1;
        end
      end);
    else
      if(WeakAuras.regions[data.id]) then
        button:SetViewRegion(WeakAuras.regions[data.id].region);
      else
        error("SetViewRegion fault: "..data.id);
      end
    end
    button:SetRenameAction(function(newid)
      local oldid = data.id;
      frame.buttonsScroll:DeleteChild(displayButtons[id]);
      frame:ClearPicks();
      thumbnails[oldid].region:Hide();
      thumbnails[oldid] = nil;
      displayButtons[oldid] = nil;
      WeakAuras.Rename(data, newid);
      WeakAuras.ScanForLoads();
      WeakAuras.EnsureDisplayButton(db.displays[newid]);
      WeakAuras.UpdateDisplayButton(db.displays[newid]);
      frame.buttonsScroll:AddChild(displayButtons[newid]);
      WeakAuras.AddOption(newid, data);
      WeakAuras.SetIconNames(data);
      pickonupdate = newid;
      
      frame.copying = nil;
      frame.grouping = nil;
      WeakAuras.Add(data);
      for id, data in pairs(db.displays) do
        WeakAuras.EnsureDisplayButton(data);
        WeakAuras.UpdateDisplayButton(data);
      end
      WeakAuras.SortDisplayButtons();
    end);
    button:SetIds(db.displays);
    button:SetGroupClick(function()
      frame:PickDisplay(id);
      frame.copying = nil;
      frame.grouping = data;
      for id, data in pairs(db.displays) do
        WeakAuras.EnsureDisplayButton(data);
        WeakAuras.UpdateDisplayButton(data);
      end
    end);
    if(data.controlledChildren) then
      button:DisableGroup();
      button:SetOnExpandCollapse(WeakAuras.SortDisplayButtons);
      if(#data.controlledChildren == 0) then
        button:DisableExpand();
      else
        button:EnableExpand();
      end
    else
      button:EnableGroup();
    end
    button:SetUngroupClick(function()
      local parentData = db.displays[data.parent];
      local index;
      for childIndex, childId in pairs(parentData.controlledChildren) do
        if(childId == id) then
          index = childIndex;
          break;
        end
      end
      if(index) then
        tremove(parentData.controlledChildren, index);
        WeakAuras.Add(parentData);
        WeakAuras.ReloadGroupRegionOptions(parentData);
      else
        error("Display thinks it is a member of a group which does not control it");
      end
      button:SetGroup();
      data.parent = nil;
      WeakAuras.Add(data);
      for id, data in pairs(db.displays) do
        WeakAuras.EnsureDisplayButton(data);
        WeakAuras.UpdateDisplayButton(data);
      end
      WeakAuras.SortDisplayButtons();
      pickonupdate = id;
    end);
    button:SetUpGroupClick(function()
      if(data.parent) then
        pickonupdate = data.parent;
        parentData = db.displays[data.parent];
        local index;
        for childIndex, childId in pairs(parentData.controlledChildren) do
          if(childId == id) then
            index = childIndex;
            break;
          end
        end
        if(index) then
          if(index <= 1) then
            error("Attempt to move up the first element in a group");
          else
            tremove(parentData.controlledChildren, index);
            tinsert(parentData.controlledChildren, index - 1, id);
            WeakAuras.Add(parentData);
            button:SetGroupOrder(index - 1, #parentData.controlledChildren);
            otherbutton = displayButtons[parentData.controlledChildren[index]];
            otherbutton:SetGroupOrder(index, #parentData.controlledChildren);
            WeakAuras.SortDisplayButtons();
            local updata = {duration = 0.15, type = "custom", use_translate = true, x = 0, y = -32};
            local downdata = {duration = 0.15, type = "custom", use_translate = true, x = 0, y = 32};
            WeakAuras.Animate("button", parentData.controlledChildren[index-1], "main", updata, button.frame, true, function() WeakAuras.SortDisplayButtons() end);
            WeakAuras.Animate("button", parentData.controlledChildren[index], "main", downdata, otherbutton.frame, true, function() WeakAuras.SortDisplayButtons() end);
          end
        else
          error("Display thinks it is a member of a group which does not control it");
        end
      else
        error("This display is not in a group. You should not have been able to click this button");
      end
      for id, data in pairs(db.displays) do
        WeakAuras.EnsureDisplayButton(data);
        WeakAuras.UpdateDisplayButton(data);
      end
    end);
    button:SetDownGroupClick(function()
      if(data.parent) then
        pickonupdate = data.parent;
        parentData = db.displays[data.parent];
        local index;
        for childIndex, childId in pairs(parentData.controlledChildren) do
          if(childId == id) then
            index = childIndex;
            break;
          end
        end
        if(index) then
          if(index >= #parentData.controlledChildren) then
            error("Attempt to move down the last element in a group");
          else
            tremove(parentData.controlledChildren, index);
            tinsert(parentData.controlledChildren, index + 1, id);
            WeakAuras.Add(parentData);
            button:SetGroupOrder(index + 1, #parentData.controlledChildren);
            otherbutton = displayButtons[parentData.controlledChildren[index]];
            otherbutton:SetGroupOrder(index, #parentData.controlledChildren);
            WeakAuras.SortDisplayButtons()
            local updata = {duration = 0.15, type = "custom", use_translate = true, x = 0, y = -32};
            local downdata = {duration = 0.15, type = "custom", use_translate = true, x = 0, y = 32};
            WeakAuras.Animate("button", parentData.controlledChildren[index+1], "main", downdata, button.frame, true, function() WeakAuras.SortDisplayButtons() end);
            WeakAuras.Animate("button", parentData.controlledChildren[index], "main", updata, otherbutton.frame, true, function() WeakAuras.SortDisplayButtons() end);
          end
        else
          error("Display thinks it is a member of a group which does not control it");
        end
      else
        error("This display is not in a group. You should not have been able to click this button");
      end
      for id, data in pairs(db.displays) do
        WeakAuras.EnsureDisplayButton(data);
        WeakAuras.UpdateDisplayButton(data);
      end
      WeakAuras.SortDisplayButtons();
    end);
    
    if(data.parent) then
      parentData = db.displays[data.parent];
      local index;
      for childIndex, childId in pairs(parentData.controlledChildren) do
        if(childId == id) then
          index = childIndex;
          break;
        end
      end
      if(index) then
        button:SetGroup(data.parent);
        button:SetGroupOrder(index, #parentData.controlledChildren);
      else
        error("Display \""..id.."\" thinks it is a member of group \""..data.parent.."\" which does not control it");
      end
    end
  end
end

function WeakAuras.SetThumbnail(data)
  local regionType = data.regionType;
  local regionTypes = WeakAuras.regionTypes;
  if not(regionType) then
    error("Improper arguments to WeakAuras.SetThumbnail - regionType not defined");
  else
    if(regionTypes[regionType]) then
      local id = data.id;
      if not(id) then
        error("Improper arguments to WeakAuras.SetThumbnail - id not defined");
      else
        local button = displayButtons[id];
        local thumbnail, region;
        if(regionOptions[regionType].createThumbnail and regionOptions[regionType].modifyThumbnail) then
          if((not thumbnails[id]) or (not thumbnails[id].region) or thumbnails[id].regionType ~= regionType) then
            thumbnail = regionOptions[regionType].createThumbnail(button.frame, regionTypes[regionType].create);        
            thumbnails[id] = {
              regionType = regionType,
              region = thumbnail
            };
          else
            thumbnail = thumbnails[id].region;
          end
          WeakAuras.validate(data, regionTypes[regionType].default);
          regionOptions[regionType].modifyThumbnail(button.frame, thumbnail, data, regionTypes[regionType].modify);
        else
          thumbnail = regionOptions[regionType].icon;
        end
        
        return thumbnail;
      end
    else
      error("Improper arguments to WeakAuras.SetThumbnail - regionType \""..data.regionType.."\" is not supported and no custom region was supplied");
    end
  end
end

function WeakAuras.OpenTexturePick(data, field)
  frame.texturePick:Open(data, field);
end

function WeakAuras.OpenIconPick(data, field)
  frame.iconPick:Open(data, field);
end

function WeakAuras.ResetMoverSizer()
  if(frame and frame.mover and frame.moversizer and frame.mover.moving.region and frame.mover.moving.data) then
    frame.moversizer:SetToRegion(frame.mover.moving.region, frame.mover.moving.data);
  end
end

function WeakAuras.CorrectAuraName(input)
  local spellId = tonumber(input);
  if(spellId) then
    local name, _, icon = GetSpellInfo(spellId);
    if(name) then
      iconCache[name] = iconCache[name] or icon;
      return name;
    else
      return "Invalid Spell ID";
    end
  else
    local ret = WeakAuras.BestKeyMatch(input, iconCache);
    if(ret == "") then
      return "No Match Found";
    else
      return ret;
    end
  end
end

function WeakAuras.CorrectSpellName(input)
  local link;
  if(input:sub(1,1) == "\124") then
    link = input;
  else
    link = GetSpellLink(input);
  end
  if(link) then
    local itemId = link:match("spell:(%d+)");
    return tonumber(itemId);
  else
    return nil;
  end
end

function WeakAuras.CorrectItemName(input)
  local inputId = tonumber(input);
  if(inputId) then
    local name = GetItemInfo(inputId);
    if(name) then
      return inputId;
    else
      return nil;
    end
  else
    local _, link = GetItemInfo(input);
    if(link) then
      local itemId = link:match("item:(%d+)");
      return tonumber(itemId);
    else
      return nil;
    end
  end
end
    

function WeakAuras.BestKeyMatch(nearkey, table)
  for key, value in pairs(table) do
    if(nearkey:lower() == key:lower()) then
      return key;
    end
  end
  local bestKey = "";
  local bestDistance = math.huge;
  local partialMatches = {};
  for key, value in pairs(table) do
    if(key:lower():find(nearkey:lower())) then
      partialMatches[key] = value;
    end
  end
  for key, value in pairs(partialMatches) do
    local distance = Lev(nearkey, key);
    if(distance < bestDistance) then
      bestKey = key;
      bestDistance = distance;
    end
  end
  return bestKey;
end