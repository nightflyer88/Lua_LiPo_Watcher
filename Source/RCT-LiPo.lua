--[[
    ---------------------------------------------------------
    LiPo Watcher takes flight pack voltage and calculates
    cell-voltage from that. Cell-voltage is then used to
    determine LiPo-charge. 
    
    Voltage is moothed heavily to eliminate spikes generating
    false alarms.
    
    User has a possibility to set an alarm with desired point
    with audio-file if desired.
    
    Requires DC/DS-14/16/24 with firmware 4.22 or up.
    ---------------------------------------------------------
    LiPo Watcher is part of RC-Thoughts Jeti Tools.
    ---------------------------------------------------------
    Released under MIT-license by Tero @ RC-Thoughts.com 2017
    ---------------------------------------------------------
--]]
collectgarbage()
----------------------------------------------------------------------
-- Locals for the application
local roll,voltTot,cellVolt,cellPerc,playDone=0,0,0,-1,false
local sensId,sensPa,cellCnt,alarmVal,avgValue,alarmFile=0,0,0,0,80,false
local altList={}
----------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng=system.getLocale()
    local file=io.readall("Apps/Lang/RCT-LiPo.jsn")
    local obj=json.decode(file)
    if(obj) then
        trans19=obj[lng] or obj[obj.default]
    end
    collectgarbage()
end
----------------------------------------------------------------------
local function LiPoGauge(percentage,ox,oy)
    -- Fuel bar 
    lcd.drawRectangle (8+ox,53+oy,30,11)
    lcd.drawRectangle (8+ox,41+oy,30,11)  
    lcd.drawRectangle (8+ox,29+oy,30,11)  
    lcd.drawRectangle (8+ox,17+oy,30,11)  
    lcd.drawRectangle (8+ox,5+oy,30,11)
    -- Bar chart
    if(cellPerc >= 0) then
        local nSolidBar=math.floor(percentage / 20)
        local nFracBar=(percentage-nSolidBar * 20) / 20
        local i
        -- Solid bars
        for i=0,nSolidBar-1,1 do 
            lcd.drawFilledRectangle (8+ox,53-i*12+oy,30,11) 
        end  
        -- Fractional bar
        local y=math.floor( 53-nSolidBar*12+(1-nFracBar)*11+0.5)
        lcd.drawFilledRectangle (8+ox,y+oy,30,11*nFracBar)
    end
    collectgarbage()
end
----------------------------------------------------------------------
-- Draw the telemetry windows
local function dispLiPo(width,height)
    if(height==69)then -- Big window
        lcd.drawText(140-lcd.getTextWidth(FONT_MINI,string.format(trans19.winLabel)),3,string.format(trans19.winLabel),FONT_MINI)
        if (cellPerc==-1) then
            lcd.drawText(140-lcd.getTextWidth(FONT_MAXI,"-%"),14,"-%",FONT_MAXI)
            lcd.drawText(140-lcd.getTextWidth(FONT_MINI,"RC-Thoughts.com"),53,"RC-Thoughts.com",FONT_MINI)
            else
            lcd.drawText(140-lcd.getTextWidth(FONT_MAXI,string.format("%s%%",cellPerc)),14,string.format("%s%%",cellPerc),FONT_MAXI)
            lcd.drawText(140-lcd.getTextWidth(FONT_MINI,string.format("%s %.2fV",trans19.lipoLabel,cellVolt)),53,string.format("%s %.2fV",trans19.lipoLabel,cellVolt),FONT_MINI)
        end
        -- Do the LiPo bar only in big window
        LiPoGauge(cellPerc,1,0)
        else -- Small window
        if (cellPerc==-1) then
            lcd.drawText(145-lcd.getTextWidth(FONT_BIG,"-%"),1,"-%",FONT_BIG)
            else
            lcd.drawText(145-lcd.getTextWidth(FONT_BIG,string.format("%s%%",cellPerc)),1,string.format("%s%%",cellPerc),FONT_BIG)
        end
    end
    collectgarbage()
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

local function averageValueChanged(value)
    avgValue=value
    system.pSave("avgValue",avgValue)
    roll = rollingAverage(avgValue)
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
    -- List sensors only if menu is active to preserve memory at runtime 
    -- (measured up to 25% save if menu is not opened)
    sensorsAvailable={}
    local sensors=system.getSensors()
    local sensList={}
    local curIndex=-1
    local descr=""
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
    collectgarbage()
    
    local form,addRow,addLabel=form,form.addRow,form.addLabel
    local addIntbox,addSelectbox=form.addIntbox,form.addSelectbox
    local addInputbox,addCheckbox=form.addInputbox,form.addCheckbox
    local addAudioFilebox,setButton=form.addAudioFilebox,form.setButton
    local addTextbox=form.addTextbox
    
    addRow(1)
    addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})
    
    addRow(1)
    addLabel({label=trans19.labelSensor,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=trans19.sensorSel})
    addSelectbox(sensList,curIndex,true,sensorChanged)
    
    addRow(2)
    addLabel({label=trans19.cellCount,width=220})
    addIntbox(cellCnt,0,24,0,0,1,cellCntChanged)
    
    addRow(2)
    addLabel({label=trans19.averageValue,width=220})
    addIntbox(avgValue,2,300,80,0,1,averageValueChanged)
    
    addRow(1)
    addLabel({label=trans19.labelAlarm,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=trans19.alarmValue,width=220})
    addIntbox(alarmVal,0,99,0,0,1,alarmValChanged)
    
    form.addRow(2)
    addLabel({label=trans19.voiceFile})
    addAudioFilebox(alarmFile,alarmFileChanged)
    
    addRow(1)
    addLabel({label="Powered by RC-Thoughts.com-"..lipoVersion.." ",font=FONT_MINI,alignRight=true})
    
    formID=1
    collectgarbage()
end
----------------------------------------------------------------------
-- Table for binding cell-voltage to percentage
local percentList={{3,0},{3.093,1},{3.196,2},{3.301,3},{3.401,4},{3.477,5},{3.544,6},{3.601,7},{3.637,8},{3.664,9},{3.679,10},{3.683,11},{3.689,12},{3.692,13},{3.705,14},{3.71,15},{3.713,16},{3.715,17},{3.72,18},{3.731,19},{3.735,20},{3.744,21},{3.753,22},{3.756,23},{3.758,24},{3.762,25},{3.767,26},{3.774,27},{3.78,28},{3.783,29},{3.786,30},{3.789,31},{3.794,32},{3.797,33},{3.8,34},{3.802,35},{3.805,36},{3.808,37},{3.811,38},{3.815,39},{3.818,40},{3.822,41},{3.825,42},{3.829,43},{3.833,44},{3.836,45},{3.84,46},{3.843,47},{3.847,48},{3.85,49},{3.854,50},{3.857,51},{3.86,52},{3.863,53},{3.866,54},{3.87,55},{3.874,56},{3.879,57},{3.888,58},{3.893,59},{3.897,60},{3.902,61},{3.906,62},{3.911,63},{3.918,64},{3.923,65},{3.928,66},{3.939,67},{3.943,68},{3.949,69},{3.955,70},{3.961,71},{3.968,72},{3.974,73},{3.981,74},{3.987,75},{3.994,76},{4.001,77},{4.007,78},{4.014,79},{4.021,80},{4.029,81},{4.036,82},{4.044,83},{4.052,84},{4.062,85},{4.074,86},{4.085,87},{4.095,88},{4.105,89},{4.111,90},{4.116,91},{4.12,92},{4.125,93},{4.129,94},{4.135,95},{4.145,96},{4.176,97},{4.179,98},{4.193,99},{4.2,100}}
----------------------------------------------------------------------
-- Count percentage from cell voltage
function percCell(cellVoltage)
    result=0
    if(cellVoltage > 4.2 or cellVoltage < 3.00)then
        if(cellVoltage > 4.2)then
            result=100
        end
        if(cellVoltage < 3.00)then
            result=0
        end
        else
        for i,v in ipairs(percentList) do
            if(v[1] >= cellVoltage)then
                result=v[2]
                break
            end
        end
    end
    collectgarbage()
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
    collectgarbage()
    return average
end
----------------------------------------------------------------------
-- Runtime functions,read sensor,convert to percentage
local function loop()
    local sensor=system.getSensorByID(sensId,sensPa)
    if(sensor and sensor.valid) then
        voltTot=sensor.value
        -- Count rolling average on total voltage and divide to cell-voltage
        cellVolt = (roll(voltTot)/cellCnt)
        -- Calculate cell-percentage from LiPo-table
        cellPerc=percCell(cellVolt)
        -- Take care of alarm if alarm is enabled, make sure it plays only once
        if(not playDone and alarmVal > 0 and cellPerc <= alarmVal and alarmFile ~= "...") then
            system.playFile(alarmFile,AUDIO_QUEUE)
            system.playNumber(cellPerc,0,"%")
            playDone=true   
        end
        else
        -- If we have no sensor set cell-percentage to -1 for screen-identification
        cellPerc=-1
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
    avgValue=pLoad("avgValue",80)
    alarmVal=pLoad("alarmVal",0)
    alarmFile=pLoad("alarmFile","...")
    table.insert(altList,trans19.neg)
    table.insert(altList,trans19.pos)
    registerForm(1,MENU_APPS,trans19.appName,initForm)
    registerTelemetry(1,trans19.appName,0,dispLiPo)
    -- Set average-calculation
    roll = rollingAverage(avgValue)
    collectgarbage()
end
----------------------------------------------------------------------
lipoVersion="v.1.1"
setLanguage()
collectgarbage()
return {init=init,loop=loop,author="RC-Thoughts",version=lipoVersion,name=trans19.appName}
