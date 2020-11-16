    --  Name:                           ACT_Chernobyl
    --  Author:                         Activity
    --  Last Modified On:               16/11/2020
    --  Dependencies:                   Mist.lua
    --  Description:
    --      Simulates radioactive doses in chernobyl like helicopter operations
    --  Usage:
    --      1. Set zones

chbl = {}

chbl.unitsInZone = {}
chbl.groupsInZone = {}

-- Settings
chbl.reactorPos = mist.utils.zoneToVec3("reactorInner")
chbl.zoneInner = "reactorInner"
chbl.zoneMedium = "reactorMedium"
chbl.zoneOuter = "reactorOuter"

chbl.zoneStatic = "tower"

function chbl.detectCargo()
    -- detect cargo in zone
end

function chbl.detectInZone()
    chbl.unitsInZone = mist.getUnitsInZones(mist.makeUnitTable({"[blue][helicopter]"}), {"reactorOuter"})

    for i = 1, #chbl.unitsInZone do
        _unit = chbl.unitsInZone[i]
        _group = _unit:getGroup()
        
        _distance = mist.utils.get2DDist(chbl.reactorPos, mist.getLeadPos(_group:getName()))
        
        if _distance >= trigger.misc.getZone(chbl.zoneMedium).radius then       --Radius is more than medium, so outer zone
            trigger.action.outTextForGroup(_group:getID(), "Outer Zone", 1, true)
            trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerLow.wav" )
        elseif _distance >= trigger.misc.getZone(chbl.zoneInner).radius and     --Radius between inner and medium, so medium zone
                _distance <= trigger.misc.getZone(chbl.zoneOuter).radius then
            trigger.action.outTextForGroup(_group:getID(), "Medium Zone", 1, true)
            trigger.action.outSoundForGroup(_group:getID(), "l10n/DEFAULT/geigerMed.wav" )
        else                                                                    --Last option left is inner zone
            trigger.action.outTextForGroup(_group:getID(), "Inner Zone", 1, true)
        end 
    end
    timer.scheduleFunction(chbl.detectInZone, nil, timer.getTime() + 2)         --TODO: decouple sound and pos check (updateaudio function)
end

function chbl.geigerCounter(_group)
    --Play sound if in zone, after clip length passes play again if still in zone
end

function chbl.dosimeter()
    --counts if in zones, summarizes
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
end