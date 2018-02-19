--[[
    ---------------------------------------------------------
    Rx Battery Monitor displays the receiver battery voltage 
    in percent, and displays it in a bar graph.
    
    Voltage is moothed heavily to eliminate spikes generating
    false alarms.
    
    User has a possibility to set an alarm with desired point
    with audio-file if desired.
    
    Requires DC/DS-14/16/24 with firmware 4.22 or up.
    ---------------------------------------------------------

    V1.5beta19.02.18    add Li-ion cells
    V1.4    26.12.17    Rename to RxBattMon, small changes
    V1.3    02.11.17    Rx sensors are supported, Nixx cells are supported
    V1.2    01.11.17    forked from RCT LiPo Watcher

--]]

----------------------------------------------------------------------
-- Locals for the application
local rxBattversion="1.5b"
local lang
local roll,voltTot,cellVolt,cellPerc,playDone=0,0,0,-1,false
local sensId,sensPa,cellCnt,alarmVal,alarmFile=0,0,0,0,false
local timeNow,timeLast,timeFill=0,0,0
local cellTyp,voltageDisplay
local cellTypList={"LiPo","Li-ion","Nixx"}
local percentList={}
----------------------------------------------------------------------
-- Table for binding cell-voltage to percentage
local function readPercentList(index)
    if index==1 then        --LiPo
        percentList =                                                
        {
        {3.000, 0},           
        {3.380, 5},
        {3.580, 10},
        {3.715, 15},
        {3.747, 20},
        {3.769, 25},
        {3.791, 30},
        {3.802, 35},
        {3.812, 40},
        {3.826, 45},
        {3.839, 50},
        {3.861, 55},
        {3.883, 60},
        {3.910, 65},
        {3.936, 70},
        {3.986, 75},
        {3.999, 80},
        {4.042, 85},
        {4.085, 90},
        {4.142, 95},
        {4.170, 97},
        {4.200, 100}            
        }
    elseif index==2 then    --Li-ion
        percentList =
        {
        {3.500, 0}, 
        {3.528, 5},
        {3.565, 10},
        {3.600, 15},
        {3.630, 20},
        {3.665, 25},
        {3.700, 30},
        {3.755, 40},
        {3.885, 60},
        {3.986, 75},
        {4.010, 80},
        {4.020, 85},
        {4.035, 90},
        {4.050, 95},
        {4.100, 100} 
        }
    elseif index==3 then    --Nixx
        percentList =                                                
        {
        {0.900, 0},           
        {0.970, 5},
        {1.040, 10},
        {1.090, 15},
        {1.120, 20},
        {1.140, 25},
        {1.155, 30},
        {1.175, 40},
        {1.205, 60},
        {1.220, 75},
        {1.230, 80},
        {1.250, 85},
        {1.280, 90},
        {1.330, 95},
        {1.420, 100}            
        }
    end
end
----------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng=system.getLocale()
    local file=io.readall("Apps/RxBattMon/RxBattMon.jsn")
    local obj=json.decode(file)
    if(obj) then
        lang=obj[lng] or obj[obj.default]
    end
end
----------------------------------------------------------------------
local function BigGauge(ox,oy)
    -- Fuel bar 
    lcd.drawRectangle (8+ox,53+oy,30,11)
    lcd.drawRectangle (8+ox,41+oy,30,11)  
    lcd.drawRectangle (8+ox,29+oy,30,11)  
    lcd.drawRectangle (8+ox,17+oy,30,11)  
    lcd.drawRectangle (8+ox,5+oy,30,11)
    -- Bar chart
    if(cellPerc >= 0) then
        if cellPerc > 50 then
            lcd.setColor(0,200,0)  -- green 
        elseif cellPerc > 20 then
            lcd.setColor(255,128,0)  -- orange
        else
            lcd.setColor(200,0,0)  -- red
        end
        local nSolidBar=math.floor(cellPerc / 20)
        local nFracBar=(cellPerc-nSolidBar * 20) / 20
        local i
        -- Solid bars
        for i=0,nSolidBar-1,1 do 
            lcd.drawFilledRectangle (9+ox,54-i*12+oy,28,9) 
        end  
        -- Fractional bar
        local y=math.ceil(54-nSolidBar*12+(1-nFracBar)*9)
        lcd.drawFilledRectangle (9+ox,y+oy,28,9*nFracBar)
    end
end

local function SmallGauge(ox,oy)
    -- Fuel bar 
    lcd.drawRectangle (67+ox,3+oy,15,18)
    lcd.drawRectangle (51+ox,3+oy,15,18)  
    lcd.drawRectangle (35+ox,3+oy,15,18)  
    lcd.drawRectangle (19+ox,3+oy,15,18)  
    lcd.drawRectangle (3+ox,3+oy,15,18)
    -- Bar chart
    if(cellPerc >= 0) then
        if cellPerc > 50 then
            lcd.setColor(0,200,0)  -- green 
        elseif cellPerc > 20 then
            lcd.setColor(255,128,0)  -- orange
        else
            lcd.setColor(200,0,0)  -- red
        end
        local nSolidBar=math.floor(cellPerc / 20)
        local nFracBar=(cellPerc-nSolidBar * 20) / 20
        local i
        -- Solid bars
        for i=0,nSolidBar-1,1 do 
            lcd.drawFilledRectangle (4+i*16+ox,4+oy,13,16) 
        end  
        -- Fractional bar
        local x=math.floor(4+nSolidBar*16)
        lcd.drawFilledRectangle (x+ox,4+oy,13*nFracBar,16)
    end
end
----------------------------------------------------------------------
-- Draw the telemetry windows
local function dispBatt(width,height)
    if(height==69)then -- Big window
        if (cellPerc==-1) then
            lcd.drawText(140-lcd.getTextWidth(FONT_MAXI,"-%"),10,"-%",FONT_MAXI)
            else
            lcd.drawText(140-lcd.getTextWidth(FONT_MAXI,string.format("%s%%",cellPerc)),10,string.format("%s%%",cellPerc),FONT_MAXI)
            if voltageDisplay==1 then
                lcd.drawText(140-lcd.getTextWidth(FONT_MINI,string.format("%s %s %.2fV",cellTypList[cellTyp],lang.cellLabel,cellVolt)),53,string.format("%s %s %.2fV",cellTypList[cellTyp],lang.cellLabel,cellVolt),FONT_MINI)
            else
                lcd.drawText(140-lcd.getTextWidth(FONT_MINI,string.format("%s %s %.2fV",cellTypList[cellTyp],lang.battLabel,cellVolt*cellCnt)),53,string.format("%s %s %.2fV",cellTypList[cellTyp],lang.battLabel,cellVolt*cellCnt),FONT_MINI)
            end
        end
        BigGauge(1,0)
    else -- Small window
        if (cellPerc==-1) then
            lcd.drawText(145-lcd.getTextWidth(FONT_BIG,"-%"),1,"-%",FONT_BIG)
            else
            lcd.drawText(145-lcd.getTextWidth(FONT_BIG,string.format("%s%%",cellPerc)),1,string.format("%s%%",cellPerc),FONT_BIG)
        end
        SmallGauge(1,0)
    end
end
----------------------------------------------------------------------
-- Store settings when changed by user
local function sensorChanged(value)
    sensId=sensorsAvailable[value].id
    sensPa=sensorsAvailable[value].param
    system.pSave("sensId",sensId)
    system.pSave("sensPa",sensPa)
end

local function cellCntChanged(value)
    cellCnt=value
    system.pSave("cellCnt",cellCnt)
end

local function cellTypChanged(value)
    cellTyp=value
    system.pSave("cellTyp",cellTyp)
    readPercentList(cellTyp)
end

local function voltageDisplayChanged(value)
    voltageDisplay=value
    system.pSave("voltageDisplay",voltageDisplay)
end

local function alarmValChanged(value)
    alarmVal=value
    system.pSave("alarmVal",alarmVal)
end

local function alarmFileChanged(value)
    alarmFile=value
    system.pSave("alarmFile",alarmFile)
end
----------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm(subform)
    -- List of Battery display
    local voltageDisplayList={lang.singleCell,lang.totalBattery}
    
    -- List sensors only if menu is active to preserve memory at runtime 
    -- (measured up to 25% save if menu is not opened)
    sensorsAvailable={}
    local sensors=system.getSensors()
    local sensList={}
    local curIndex=-1
    local descr=""
    -- Add some of RX Telemetry items to beginning in list of sensors, get name from translation
    sensList[#sensList + 1] = string.format("%s",lang.sensorRx1)
    sensorsAvailable[#sensorsAvailable + 1] = {["unit"] = "V", ["param"] = 1,["id"] = 999,["label"] = lang.sensorRx1}
    sensList[#sensList + 1] = string.format("%s",lang.sensorRx2)
    sensorsAvailable[#sensorsAvailable + 1] = {["unit"] = "V", ["param"] = 2,["id"] = 999,["label"] = lang.sensorRx2}
    sensList[#sensList + 1] = string.format("%s",lang.sensorRxB)
    sensorsAvailable[#sensorsAvailable + 1] = {["unit"] = "V", ["param"] = 3,["id"] = 999,["label"] = lang.sensorRxB}
    if(sensId == 999) then
        curIndex = sensPa
    end
    -- Add sensors
    for index,sensor in ipairs(sensors) do 
        if(sensor.param==0) then
            descr=sensor.label
            else
            sensList[#sensList+1]=string.format("%s-%s",descr,sensor.label)
            sensorsAvailable[#sensorsAvailable+1]=sensor
            if(sensor.id==sensId and sensor.param==sensPa) then
                curIndex =# sensorsAvailable
            end
        end
    end
    
    local form,addRow,addLabel=form,form.addRow,form.addLabel
    local addIntbox,addSelectbox=form.addIntbox,form.addSelectbox
    local addInputbox,addCheckbox=form.addInputbox,form.addCheckbox
    local addAudioFilebox,setButton=form.addAudioFilebox,form.setButton
    local addTextbox=form.addTextbox
    
    addRow(1)
    addLabel({label=lang.labelSensor,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=lang.sensorSel})
    addSelectbox(sensList,curIndex,true,sensorChanged)
    
    addRow(2)
    addLabel({label=lang.cellCount,width=220})
    addIntbox(cellCnt,0,24,0,0,1,cellCntChanged)
    
    addRow(2)
    addLabel({label=lang.batteryTyp,width=220})
    addSelectbox(cellTypList,cellTyp,true,cellTypChanged)
    
    addRow(2)
    addLabel({label=lang.voltageDisplay,width=170})
    addSelectbox(voltageDisplayList,voltageDisplay,false,voltageDisplayChanged)
    
    addRow(1)
    addLabel({label=lang.labelAlarm,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=lang.alarmValue,width=220})
    addIntbox(alarmVal,0,99,0,0,1,alarmValChanged)
    
    addRow(2)
    addLabel({label=lang.voiceFile})
    addAudioFilebox(alarmFile,alarmFileChanged)
    
    addRow(1)
    addLabel({label="Powered by M.Lehmann V"..rxBattversion.." ",font=FONT_MINI,alignRight=true})
    
    formID=1
end

----------------------------------------------------------------------
-- Count percentage from cell voltage
local function percCell(cellVoltage)
    local result = 0
    local cellfull, cellempty = percentList[#percentList][1], percentList[1][1]
    
    if(cellVoltage >= cellfull)then                                            
      result = 100
    elseif(cellVoltage <= cellempty)then
      result = 0
    else
        for i, v in ipairs(percentList) do     
            -- Interpolate values                             
            if v[ 1 ] >= cellVoltage and i > 1 then
                local lastVal = percentList[i-1]
                result = (cellVoltage - lastVal[1]) / (v[1] - lastVal[1])
                result = result * (v[2] - lastVal[2]) + lastVal[2]
                break
            end
        end
    end
    result = math.modf(result)
    return result
end

----------------------------------------------------------------------
-- Create a rolling average of voltage to prevent false alarms
function rollingAverage(period)
    local t={}
    function sum(a,...)
        if a then return a+sum(...) else return 0 end
    end
    function average(n)
        if #t==period then table.remove(t,1) end
        t[#t+1]=n
        return sum(table.unpack(t)) / #t
    end
    return average
end
----------------------------------------------------------------------
-- Runtime functions,read sensor,convert to percentage
local function loop()
    local sensor = {}
    if(sensId == 999) then
        local sensorTx = system.getTxTelemetry()
        sensor.valid = true
        sensor.unit = "V"
        if(sensPa == 1) then
            sensor.value = sensorTx.rx1Voltage
        elseif (sensPa == 2) then
            sensor.value = sensorTx.rx2Voltage
        elseif (sensPa == 3) then
            sensor.value = sensorTx.rxBVoltage
        end
        else
        sensor=system.getSensorByID(sensId,sensPa)
    end
    
    local timeNow = system.getTimeCounter()
    if(sensor and sensor.valid) then
        voltTot=sensor.value 
        -- Fill table at start
        if(timeFill == 0 or voltTot==0) then
            timeFill = timeNow + 2000
        end
        if(timeNow <= timeFill) then
            cellVolt = (roll(voltTot)/cellCnt)
        end 
        if(timeNow >= timeLast + 1000) then
            cellVolt = (roll(voltTot)/cellCnt)
            timeLast = timeNow
        end
        
        -- Calculate cell-percentage from LiPo-table
        cellPerc=percCell(cellVolt)
        -- Take care of alarm if alarm is enabled, make sure it plays only once
        if(not playDone and alarmVal > 0 and cellPerc <= alarmVal and alarmFile ~= "..." and timeNow>timeFill) then
            system.playFile(alarmFile,AUDIO_QUEUE)
            system.playNumber(cellPerc,0,"%")
            playDone=true   
        end
    else
        -- If we have no sensor set cell-percentage to -1 for screen-identification
        cellPerc = -1
        timeFill = 0
    end   
    -- If percentage is above alarm-level enable alarm
    if(cellPerc > alarmVal) then
        playDone=false
    end
    collectgarbage()
end
----------------------------------------------------------------------
-- Application initialization
local function init()
    local pLoad,registerForm,registerTelemetry=system.pLoad,system.registerForm,system.registerTelemetry
    sensId=pLoad("sensId",0)
    sensPa=pLoad("sensPa",0)
    cellCnt=pLoad("cellCnt",0)
    cellTyp=pLoad("cellTyp",1)
    readPercentList(cellTyp)
    voltageDisplay=pLoad("voltageDisplay",1)
    alarmVal=pLoad("alarmVal",0)
    alarmFile=pLoad("alarmFile","...")
    registerForm(1,MENU_APPS,lang.appName,initForm)
    registerTelemetry(1,lang.appName,0,dispBatt)
    -- Set average-calculation
    roll = rollingAverage(10)
    collectgarbage()
end
----------------------------------------------------------------------
setLanguage()
return {init=init,loop=loop,author="M.Lehmann",version=rxBattversion,name=lang.appName}
