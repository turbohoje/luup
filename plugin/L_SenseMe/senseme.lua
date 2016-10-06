local SENSEME = {
  SENSEME_DEVICES = {
    {
      ID = "1",
      MAC = "20:F8:5E:AB:31:1B",
      NAME = "Spa Room Fan",
      TYPE = "FAN",
      VID = 0, -- will be assigned during matching
    },
    {
      ID = "2",
      MAC = "20:F8:5E:AB:31:1B",
      NAME = "Spa Room Fan Light",
      TYPE = "DIMMER",
      VID = 0, -- will be assigned during matching
    },
  },
  -- compile a list of configured devices and store in upnp variable
  buildDeviceSummary = function(self)
    debug("(" .. PLUGIN.NAME .. "::buildDeviceSummary): building device summary.", 2)

    local html = ""
    if ((PLUGIN.FILES_VALIDATED == false) and (PLUGIN.OPENLUUP == false)) then
      html = html .. "<h2>Installation error</h2><p>Mismatched Files</p>"
      html = html .. "<ul><li>" .. PLUGIN.mismatched_files_list:gsub(",", "</li><li>") .. "</li></ul><br>"
    end
    if (self.SENSEME_DEVICES and (#self.SENSEME_DEVICES > 0) and self.SENSEME_DEVICES[1]) then
      html = html .. "<h2>Devices:</h2><ul class='devices'>"
      -- add devices
      for k, DEV in pairs(self.SENSEME_DEVICES) do

        -- display the devices
        debug("(" .. PLUGIN.NAME .. "::buildDeviceSummary): Scanning device [" .. DEV.MAC .. "].")
        if (DEV.TYPE == "Gateway") then
        elseif (DEV.TYPE == "KEYPAD") then
          html = html .. "<li class='wDevice'><b>Vera ID:" .. DEV.VID .. " [" .. DEV.TYPE .. "] " .. DEV.NAME .. "</b><br>"
          html = html .. "<table><tr><td>Model:</td><td>" .. DEV.MODEL .. "</td><td>&nbsp;&nbsp;</td><td>Serial:</td><td>" .. DEV.SERIAL .. "</td></tr>"
          html = html .. "<tr><td>LEAP/LIP ID:</td><td>" .. DEV.ID .. "/" .. DEV.LIPid .. "</td><td>&nbsp;&nbsp;</td><td>Button Group:</td><td>" .. DEV.BUTTON .. "</td></tr></table>"
          html = html .. "</li>"
        elseif ((DEV.TYPE == "DIMMER") or (DEV.TYPE == "SWITCH")) then
          html = html .. "<li class='wDevice'><b>Vera ID:" .. DEV.VID .. " [" .. DEV.TYPE .. "] " .. DEV.NAME .. "</b><br>"
          html = html .. "<table><tr><td>Model:</td><td>" .. DEV.MODEL .. "</td><td>&nbsp;&nbsp;</td><td>Serial:</td><td>" .. DEV.SERIAL .. "</td></tr>"
          html = html .. "<tr><td>LEAP/LIP ID:</td><td>" .. DEV.ID .. "/" .. DEV.LIPid .. "</td><td>&nbsp;&nbsp;</td><td>Zone: </td><td>" .. DEV.ZONE .. "</td></tr></table>"
          html = html .. "</li>"
        else
          html = html .. "<li class='wDevice'><b>Vera ID:" .. DEV.VID .. " [" .. DEV.TYPE .. "] " .. DEV.NAME .. "</b><br>"
          html = html .. "<table><tr><td>Model:</td><td>" .. DEV.MODEL .. "</td><td>&nbsp;&nbsp;</td><td>Serial:</td><td>" .. DEV.SERIAL .. "</td></tr>"
          html = html .. "<tr><td>LEAP/LIP ID:</td><td>" .. DEV.ID .. "/" .. DEV.LIPid .. "</td><td>&nbsp;&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr></table>"
          html = html .. "</li>"
        end
      end
      html = html .. "</ul><br>"
      -- add scenes
      html = html .. "<h2>Scenes:</h2><ul class='scenes'>"
      for k, DEV in pairs(self.SCENES) do
        -- display the scenes
        debug("(" .. PLUGIN.NAME .. "::buildDeviceSummary): Scanning scene [" .. DEV.ID .. "].")
        html = html .. "<li class='wDevice'><b>Vera ID:" .. DEV.VID .. " [" .. DEV.TYPE .. "] " .. DEV.NAME .. "</b><br>"
        html = html .. "<table><tr><td>ID:</td><td>" .. DEV.ID .. "</td><td>&nbsp;&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr></table>"
        html = html .. "</li>"
      end
      html = html .. "</ul><br>"
    else
      -- error with installation
      if (PLUGIN.BRIDGE_STATUS == "User Intervention Required...") then
        html = html .. "<h2>Bridge device not selected.</h2>"
      elseif (PLUGIN.BRIDGE_STATUS == "No Bridge Found") then
        if (PLUGIN.mqttParameters == nil) then
          html = html .. "<h2>Bridge not found.</h2>"
        else
          html = html .. "<h2>Bridge specified by Lutron Account not found on local network.</h2>"
        end
      elseif (PLUGIN.BRIDGE_STATUS == "Failed to load bridge config") then
        html = html .. "<h2>Could not load Bridge Configuration.</h2>"
      elseif (PLUGIN.BRIDGE_STATUS == "Startup Failed!") then
        html = html .. "<h2>Could not process Bridge Configuration.</h2>"
      else
        html = html .. "<h2>An unspecified error occurred.</h2>"
      end
    end

    debug("(" .. PLUGIN.NAME .. "::buildDeviceSummary): Device summary html [" .. html .. "].")
    UTILITIES:setVariable(VERA.SID["SENSEME"], "DEVICE_SUMMARY", html)
  end,
  appendDevices = function(self, device)
    log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): Preparing for update/append of Vera devices...", 2)
    local added = false
    local veraDevices = {}

    -- add/update devices - cache the scan results before committing in case of error

    for idx, dev in pairs(self.SENSEME_DEVICES) do
      debug("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices):   Processing device [" .. (dev.NAME or "NIL") .. "] type [" .. (dev.TYPE or "NIL") .. "]")
      local devId = "SenseMe_" .. dev.TYPE .. "_" .. dev.ID
      if (VERA.DEVTYPE[dev.TYPE] ~= nil) then -- TODO make sure DEVTYPE is set properly
        local devParams = ""
        if (dev.TYPE == "DIMMER") then
          devParams = "urn:upnp-org:serviceId:Dimming1,RampTime=0"
        end
        veraDevices[#veraDevices + 1] = { devId, dev.NAME, VERA.DEVTYPE[dev.TYPE][1], VERA.DEVTYPE[dev.TYPE][2], "", devParams, false }
        if (dev.VID == 0) then
          added = true
        else
          if (dev.TYPE == "DIMMER") then
            UTILITIES:setVariableDefault(VERA.SID["DIMMER"],"RampTime",0,dev.VID)
          end
        end
      else
        log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): ERROR : Unknown device type [" .. (dev.TYPE or "NIL") .. "]!")
        return false
      end
    end

    -- scan is complete - do the actual updates
    log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): veraDevices count [" .. #veraDevices .. "] veraDevices [" .. UTILITIES:print_r(veraDevices) .. "].", 2)
    if (#veraDevices > 0) then
      log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): Attempting to update/append Vera devices...", 2)
      local ptr = luup.chdev.start(device)
      for idx, params in pairs(veraDevices) do
        luup.chdev.append(device, ptr, params[1], params[2], params[3], params[4], params[5], params[6], params[7])
      end
      luup.chdev.sync(device, ptr)
      log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): Updated/Appended Vera devices...", 2)
    else
      debug("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): Configuration error - No devices to process.", 1)
      return false, false
    end

    if (added) then
      log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): Device(s) added. RESTART pending!", 1)
    else
      log("(" .. PLUGIN.NAME .. "::SENSEME::appendDevices): Device(s) updated", 2)
    end
    return true, added
  end,
  findDeviceIndex = function(self, devNum)
    for idx,dev in pairs(self.SENSEME_DEVICES) do
     if (tonumber(dev.ID,10) == tonumber(devNum,10)) then
        return idx
      end
    end
    return  0
  end,
  associateDevices = function(self, device)

    debug("("..PLUGIN.NAME.."::SENSEME::associateDevices): Scanning child devices.")

    -- match reported devices to vera devices

    for idx,vDev in pairs(luup.devices) do
      if (vDev.device_num_parent == lug_device) then
        debug("("..PLUGIN.NAME.."::SENSEME::associateDevices):  Processing device ["..(idx or "NIL").."] id ["..(vDev.id or "NIL").."].")
        local _,_, devType, devNum = vDev.id:find("Caseta_(%w-)_(%d-)")

        if ((devType == nil) and (devNum == nil)) then
          _,_,devNum = vDev.id:find("(%d-)")
          devType = ""
        end
        debug("("..PLUGIN.NAME.."::SENSEME::associateDevices):    Scanned device ["..(idx or "NIL").."] id ["..(vDev.id or "NIL").."] - type ["..(devType or "NIL").."] num ["..(devNum or "NIL").."].")
        if ((devType ~= nil) and (devNum ~= nil)) then
          -- detect a physical device
          local dIdx = self:findDeviceIndex(devNum)
          debug("("..PLUGIN.NAME.."::SENSEME::associateDevices):        Found SenseMe device ["..(dIdx or "NIL").."].")
          if (dIdx > 0) then
            self.DEVICES[dIdx].VID = idx
            debug("("..PLUGIN.NAME.."::SENSEME::associateDevices):        Updated SenseMe device ["..(dIdx or "NIL").."] with Vera id ["..(idx or "NIL").."].")
          end
        end
      end
    end
  end,
}
