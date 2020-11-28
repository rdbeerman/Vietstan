    --  Name:                           ACT_Chernobyl
    --  Author:                         Activity
    --  Last Modified On:               16/11/2020
    --  Dependencies:                   Mist.lua
    --  Description:
    --      Simulates radioactive doses in chernobyl like helicopter operations
    --  Usage:
    --      1. Set zones

chbl = {}
-- Settings
chbl.reactorPos = mist.vec.add(mist.utils.zoneToVec3("reactorCore"), {x= 0, y = 40, z = 0})
chbl.zoneCore = "reactorCore"
chbl.zonePlume = "reactorPlume"
chbl.zoneInner = "reactorInner"
chbl.zoneMedium = "reactorMedium"
chbl.zoneOuter = "reactorOuter"
chbl.zoneInit = "reactorInit"

chbl.zoneStatic = "tower"

chbl.coreDose = 50 -- In roentgen per second at core roof
chbl.backgroundDose = 0.02
chbl.coreZoneDose = 2   -- Added dose if directly over core
chbl.plumeDoze = 1      -- Added dose if in plume

chbl.reportInterval = 60 -- Interval between reporting dose for all helicopters in log
chbl.enableDebug = false

-- Declaration
chbl.unitsInZone = {}
chbl.groupsInZone = {}
chbl.groupsZoneNew = {}
chbl.groupsZoneOld = {}

chbl.groupsDose = {}

function chbl.detectInZone()
    chbl.unitsInZone = mist.getUnitsInZones(mist.makeUnitTable({"[blue][helicopter]"}), {chbl.zoneInit})

    for i = 1, #chbl.unitsInZone do
        _unit = chbl.unitsInZone[i]
        _group = _unit:getGroup()

        if _group == nil then
            break
        end
        
        chbl.groupsInZone[_group:getName()] = _group:getName()

        _distance = mist.utils.get2DDist(chbl.reactorPos, mist.getLeadPos(_group:getName()))
        chbl.groupsZoneOld[_group:getName()] = chbl.groupsZoneNew[_group:getName()]

        chbl.dosimeter(_group)

        if _distance >= trigger.misc.getZone(chbl.zoneOuter).radius then       --Radius bigger than outer, so in init zone
            chbl.debug(_unit:getPlayerName().." is in init Zone ")
            chbl.groupsZoneNew[_group:getName()] = chbl.zoneInit
            
        elseif _distance >= trigger.misc.getZone(chbl.zoneMedium).radius then     --Radius is more than medium, so outer zone
            chbl.groupsZoneNew[_group:getName()] = chbl.zoneOuter
            
            if chbl.groupsZoneNew[_group:getName()] ~= chbl.groupsZoneOld[_group:getName()] then
                chbl.debug(_unit:getPlayerName().." entered Outer zone ")
                trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerLow.wav" )
                timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
            end
        
        elseif _distance >= trigger.misc.getZone(chbl.zoneInner).radius and     --Radius between inner and medium, so medium zone
                _distance <= trigger.misc.getZone(chbl.zoneOuter).radius then
            chbl.groupsZoneNew[_group:getName()] = chbl.zoneMedium
            if chbl.groupsZoneNew[_group:getName()] ~= chbl.groupsZoneOld[_group:getName()] then
                chbl.debug(_unit:getPlayerName().." entered Medium zone ")
                trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerMed.wav" )
                timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
            end

        elseif _distance <= trigger.misc.getZone(chbl.zoneInner).radius and 
            _distance >= trigger.misc.getZone(chbl.zoneCore).radius then        --Radius between Inner and Core, so inner zone
            chbl.groupsZoneNew[_group:getName()] = chbl.zoneInner
            if chbl.groupsZoneNew[_group:getName()] ~= chbl.groupsZoneOld[_group:getName()] then
                chbl.debug(_unit:getPlayerName().." entered Inner zone ")
                if chbl.groupsZoneOld[_group:getName()] == chbl.zoneCore then
                    trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerHigh.wav" )
                else
                    trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerMedToHigh.wav" )
                end
                timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
            end

        elseif _distance <= trigger.misc.getZone(chbl.zoneCore).radius then        --Radius less than core, so core
            chbl.groupsZoneNew[_group:getName()] = chbl.zoneCore
            if chbl.groupsZoneNew[_group:getName()] ~= chbl.groupsZoneOld[_group:getName()] then
                chbl.debug(_unit:getPlayerName().." entered Core zone ")
                    trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerCore.wav" )
                    timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
            end
        end
    
    end
    timer.scheduleFunction(chbl.detectInZone, nil, timer.getTime() + 1)         --TODO: decouple sound and pos check (updateaudio function)
end

function chbl.geiger(_group) -- check oldzone vs newzone here too, if same, reschedule, if not, stop
    local _zoneNew = chbl.groupsZoneNew[_group:getName()]
    local _zoneOld = chbl.groupsZoneOld[_group:getName()]

    if _zoneNew == _zoneOld and _zoneNew == chbl.zoneOuter then
        trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerLow.wav" )
        timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
    elseif _zoneNew == _zoneOld and _zoneNew == chbl.zoneMedium then
        trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerMed.wav" )
        timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
    elseif _zoneNew == _zoneOld and _zoneNew == chbl.zoneInner then
        trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerHigh.wav" )
        timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
    elseif _zoneNew == _zoneOld and _zoneNew == chbl.zoneCore then
        trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerCore.wav" )
        timer.scheduleFunction(chbl.geiger, _group, timer.getTime() + 5)
    end
end

function chbl.dosimeter(_group)
    local _zone = chbl.groupsZoneNew[_group:getName()]
    
    local _corePos = chbl.reactorPos
    
    local _distance = mist.utils.get3DDist(chbl.reactorPos, mist.getLeadPos(_group:getName()))

    local _dose = chbl.coreDose  / ( _distance/10 * _distance/10 ) + chbl.backgroundDose
    
    if chbl.groupsDose[_group:getName()] == nil then
        chbl.groupsDose[_group:getName()] = 0
    end
    

    if _zone == chbl.zoneCore then
        _dose = _dose + chbl.coreZoneDose
    end

    chbl.groupsDose[_group:getName()] = chbl.groupsDose[_group:getName()] + _dose + chbl.backgroundDose

    _dosePrint = math.floor(_dose*1000)/1000
    _doseTotal = math.floor(chbl.groupsDose[_group:getName()]*1000)/1000

    local _message = "Current reading: ".._dosePrint.." R/s \nTotal Dose: ".._doseTotal.." Roentgen"
    trigger.action.outTextForGroup(_group:getID(), _message, 1, true)
end

function chbl.printDoses()
    debug("DOSE REPORT: ")
    for i = 1, #chbl.unitsInZone do
        local _unit = chbl.unitsInZone[i]
        local _group = _unit:getGroup()
        local _doseTotal = chbl.groupsDose[_group:getName()] 
        
        chbl.debug(_unit.getPlayerName(_unit).." : "..tostring(_doseTotal).." R.")
    end
    timer.scheduleFunction(chbl.printDoses, nil, timer.getTime() + chbl.reportInterval)
end

function chbl.debug(_string)
    local _string = tostring(_string) 
    if _string ~= nil then
        if chbl.enableDebug == true then
            trigger.action.outText(_string, 5)
        end
        env.error("__Chernobyl__ : ".._string, false)
    elseif _string == nil then
        if chbl.enableDebug == true then
            trigger.action.outText("debug got passed nil", 5)
        end
        env.error("__Chernobyl__ : debug got passed nil", false)
    end
end

function chbl.spawnTower()
    _vec2 = mist.utils.makeVec2(mist.utils.zoneToVec3(chbl.zoneStatic))
    mist.dynAddStatic {
        type = "Comms tower M", 
        country = "USA", 
        category = "Fortifications", 
        x = _vec2.x, 
        y = _vec2.y,  
        heading = 140,
    }
end

do 
    chbl.detectInZone()
    chbl.spawnTower()

    timer.scheduleFunction(chbl.printDoses, nil, timer.getTime() + chbl.reportInterval)
end