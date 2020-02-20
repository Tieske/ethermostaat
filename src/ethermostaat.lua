-------------------------------------------------------------------------------
-- This module implements the eThermostaat API in Lua.
--
-- @author Thijs Schreijer, http://www.thijsschreijer.nl
-- @copyright 2014-2015 Thijs Schreijer
-- @release Version 0.1, eThermostaat module for Essent/ICY eThermostaat api


local M = {}
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")


-- logs in and returns the userdata fetched, or nil + error. 
-- returns a table
function login(icy_username, icy_password)
  icy_username = icy_username or "username"
  icy_password = icy_password or "password"
  local timeout = 15
  local resultTable = {}
  local errorText = ""
  
  local request_body= 'username=' .. icy_username .. '&password=' .. icy_password
  local r,c,h = https.request {
          url = 'https://portal.icy.nl/login',
          method = 'POST',
          headers = {
              ["Content-Type"] = "application/x-www-form-urlencoded",
              ["Content-Length"] = string.len(request_body),
          },
          source = ltn12.source.string(request_body),
          sink = ltn12.sink.table(resultTable)
      }
      
  local data = table.concat(resultTable)
  if c ~= 200 then
    if c==400 then
        errorText = "400: Login failed, missing username or password"
    elseif c==401 then
        errorText = "401: Login failed, invalid username or password"
    elseif c==403 then
        errorText = "403: Login failed, too many tries"
    elseif c==503 then
        errorText = "503: Login failed due to technical maintenance"
    else
        errorText = "Unkown error: Network connection failure"
    end
      
    return nil, errorText
  else
    return (json.decode(data))
  end
end

-- reads the current values from the thermostat, token is received when logging in
function readData(token)
  local timeout = 15
  local resultTable = {}
  local request_body= ''

  local r,c,h = https.request {
          url = 'https://portal.icy.nl/data',
          method = 'GET',
          headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Session-token"] = token,
            ["Content-Length"] = string.len(request_body),
          },
          source = ltn12.source.string(request_body),
          sink = ltn12.sink.table(resultTable)
        }

  if(c==200) then
    local json_input=json.decode(table.concat(resultTable))
    icy_data = {}
    icy_data.tempTarget         = json_input.temperature1
    icy_data.tempActual         = json_input.temperature2
    icy_data.deviceStatus       = json_input["device-status"]
    icy_data.firstSeen          = json_input["first-seen"]
    icy_data.lastSeen           = json_input["last-seen"]
    icy_data.controlSettings    = json_input.configuration[1]
    icy_data.nodeSettings       = json_input.configuration[2]
    icy_data.rustPeriod         = json_input.configuration[3]
    icy_data.comfortPeriod      = json_input.configuration[4]
    icy_data.antivorstTemp      = (tonumber(json_input.configuration[5]) or 0)/2
    icy_data.rustTemp           = (tonumber(json_input.configuration[6]) or 0)/2
    icy_data.comfortTemp        = (tonumber(json_input.configuration[7]) or 0)/2
    icy_data.maxTemp            = (tonumber(json_input.configuration[8]) or 0)/2
    icy_data.comfortShorttime   = json_input.configuration[9]
    icy_data.lightsensorProfile = json_input.configuration[10]
    icy_data.heatingProfile     = json_input.configuration[11]
    icy_data.thermostatColor    = json_input.configuration[12]
    --for k,v in pairs(json_input) do print("JSON",k,v) end 
    return icy_data
  else
    local errorText
    if errorCode == 400 then
        errorText = "400: Contact technical support"
    elseif errorCode == 401 then
        errorText = "401: Session expired, please login again"
    elseif errorCode == 403 then
        errorText = "403: Contact technical support"
    elseif errorCode == 503 then
        errorText = "503: Unkown error, contact technical support"
    else
        errorText = "Network connection failure"
    end
    return nil, errorText
  end     
end

-------------------------------------------------------------------------------
-- eThermostat.
-- Besides the field below, all data elements returned by the login 
-- http call and the update http call will be stored directly in this object/table.
-- @type ethermostat

---
-- the api session token, if nil then a new login attempt will be done automatically
-- @field token string

---
-- the value of the last error returned
-- @field lasterror string

-------------------------------------------------------------------------------
-- Creates a new thermostat. Calling on the module table is a shortcut to this function.
-- @param user the username
-- @param pwd the password (plain text)
-- @return a thermostat object. No network calls will be made upon creation.
-- @see update
-- @usage local ethermostat = require("eThermostat")
-- local ts = ethermostat.newThermostat("username", "password")
-- -- which equals
-- local ts = ethermostat("username", "password")
-- -- now login and fetch new values
-- ts:update()
M.newThermostat = function(user, pwd)
  
  local thermostat = {}
  
  -- insert contents of table s into table t
  local inserttable = function(s, t)
    for k,v in pairs(s) do
      assert(type(t[k]) ~= "function", "Cannot overwrite a function!")
      t[k] = v
    end
  end
        
  ---
  -- Fetches new values. If there is no token value, it will first login.
  -- @return the thermostat object (with updated fields), or nil+error on failure
  -- @name thermostat:update
  function thermostat:update()
    if not self.token then
      -- no token is available, so we must login
      local result, err = login(user, pwd)
      if not result then
        self.lasterror = "Login failed with; "..tostring(err)
      else
        inserttable(result, self)
      end
    end

    if not self.token then
      -- login failed, so exit with error
      return nil, self.lasterror
    end
    
    local result, err = readData(self.token)
    if not result then
      self.lasterror = "Read failed with; "..tostring(err)
      self.token = nil  -- reset, so will re-login next time
      return nil, self.lasterror
    else
      inserttable(result, self)
    end
    return self
  end
  
  ---
  -- return the current setpoint
  function thermostat:getsetpoint()
    return self.tempTarget
  end
  
  ---
  -- rounds a setpoint value to the precision this thermostat supports
  function thermostat:roundsetpoint(value)
    return floor(value*2+0.5)/2    -- 0.5 degrees precision
  end
  
  ---
  -- set a new setpoint
  function thermostat:setsetpoint()
print("eThermostaat: setsetpoint not implemented!")    
    return 
  end
  
  ---
  -- return the current room temperature
  function thermostat:getroomtemp()
    return self.tempActual
  end
  
  return thermostat
end

-- return module and make it callable
setmetatable(M, {__call = function(self, ...) return M.newThermostat(...) end })
return M
  
