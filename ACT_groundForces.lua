    --  Name:                           ACT_groundForces
    --  Author:                         Activity
    --  Last Modified On:               28/02/2020
    --  Dependencies:                   Moose.lua
    --  Description:
    --      Spawns and controls groundforces for Vietstan mission
    --  Usage:
    --      1. Place zoneEngagement for engagements to be spawned
    --      2. Place zoneAmbush for for random ambushes within said zone
    --      3. Place zoneLZ for generated medevac

-- Define Settings
infantryBlueTemplates = {"blueInfantry"}
infantryRedTemplates  = {"redInfantry"}
ambushRedTemplates = {"redAmbush"}

artyGroup = "artyGroup"
bombGroup = "bombGroup"

artyCooldownTimer = 300                                 --Not in use
bombCooldownTimer = 600                                 --Not in use

engagementZones = {"zoneEngagement-1", "zoneEngagement-2"}
ambushZones = {"zoneAmbush-1", "zoneAmbush-2"}

enableDebug = true

redAmountPerZone = 4

refreshTimer = 300

engDistanceOuter = 480 
engDistanceInner = 100  

destThreshold = 0.7                                     --if a group falls below this amount of its inital strenght, it gets destroyed

facGroup = {"FACA - Yak-52", "FACA - F-86F", "FACA - L-39ZA", "FACA - TF-51D"}

-- Declarations
blueVec3array = {}
blueNameArray = {}
redVec3array = {}
redNameArray = {}
engagementStates = {}
ambushStates = {}
facID = {}
facF10 = {}

spawnIndex = 1

artyCooldown = false
bombCooldown = false
--Event handlers
markEventHandler = {}

for i = 1, #facGroup, 1 do
    facF10[i] = true
end

for i = 1, #engagementZones, 1 do
    engagementStates[i] = false
end

for i = 1, #ambushZones, 1 do
    ambushStates[i] = false
end

function spawnEngagements()
    for i = 1, #engagementZones, 1 do
        if engagementStates[i] == false then
            spawnBlueInZone(engagementZones[i])
            spawnRedAtVec3(blueVec3array[i], redAmountPerZone)
        end
    end
end

function debug(string)
    if enableDebug == true then
        trigger.action.outText(string, 5)
    end
    env.error("ACT_groundForces: "..string, false)
end

function arraySlice(array, slicedEntry)
	local sliced = {}
	for i = 1, #array, 1 do
    	if array[i] ~= slicedEntry then
    		sliced[#sliced+1] = array[i]
    	end
	end
	return sliced
end

function spawnBlueInZone(zoneString)
    local template = infantryBlueTemplates[math.random(1,#infantryBlueTemplates)] --Pick random template
    local groupTemp = Group.getByName(template)                     --Get template object
    local countryId = groupTemp:getUnit(1):getCountry()             --Get countryID of template
    local countryName = country.name[countryId]                     --Get country Name
    local groupString = countryName.." gnd "..tostring(spawnIndex)  --Put above together to make groupName
    
    mist.cloneInZone(template, zoneString)                          --Spawn template group in zone

    blueVec3 = mist.getLeadPos(groupString)                         --Get pos of leader
    blueVec3array[#blueVec3array + 1] =  blueVec3                   --Array length doubles as counter
    blueNameArray[#blueNameArray + 1] = groupString
    spawnIndex = spawnIndex + 1

    local group = Group.getByName(groupString)
    local controller = group:getController()
    
    local setImmortal = { id = 'SetImmortal', params = {value = true}}
    controller:setCommand(setImmortal)

    debug("Spawned blue infantry")
end

function Surround(vec3Blue)                                         --generates valid vec2Point
    vec3Red = mist.utils.makeVec3GL(mist.getRandPointInCircle(vec3Blue, engDistanceOuter, engDistanceInner))
    if land.isVisible(vec3Red, vec3Blue) == true then
        debug("LOS Check passed")      
        return vec3Red                                              --return valid vec3
    elseif losCounter > 40 then
        debug("losCounter exceeded, returning last vec3")
        return vec3Red 
    else        
        debug("LOS Check failed, trying again..")
        losCounter = losCounter + 1 
        return                                                      --Point in invalid, return nil
    end 
end

function spawnRedAtVec3(vec3Blue, amount)                           --Spawns amount Red inf. to surround last spawned blue inf.
    for i = 1, amount, 1 do                                         --Runs for amount given
        losCounter = 0
        vec3Red = Surround(vec3Blue)
        while vec3Red == nil do
            vec3Red = Surround(vec3Blue)                            --Add a counter for max iters
        end

        local template = infantryRedTemplates[math.random(1,#infantryRedTemplates)] --Pick random template
        local groupTemp = Group.getByName(template)                 --Get template object
        local countryId = groupTemp:getUnit(1):getCountry()         --Get countryID of template
        local countryName = country.name[countryId]                 --Get country Name
        local groupString = countryName.." gnd "..tostring(spawnIndex)
        
        mist.teleportToPoint {
            groupName = template,
            point = vec3Red,
            action = "clone",
            disperse = false,
        }

        redVec3array[#redVec3array + 1] =  vec3Red
        redNameArray[#redNameArray + 1] = groupString
        spawnIndex = spawnIndex + 1  

        params = {}
        params["groupString"] = groupString
        params["blueIndex"] = #blueVec3array

        timer.scheduleFunction(taskRed, params, timer.getTime() + 2)

        debug("Spawned red infantry "..tostring(#redVec3array))
        
    end
end

function checkHealth(groupName)
    for i = 1, #redNameArray do
        if redNameArray[i] == groupName then
            local initialSize = Group.getByName(groupName):getInitialSize()
            local currentSize = Group.getByName(groupName):getSize()

            debug(groupName .. ": " .. "initial size: " .. initialSize .. "; current size " .. currentSize) --is current size is off by +1 for some reason
            if (currentSize-1) / initialSize <= destThreshold then      --checks if a unit is below the destruction threshold. the -1 is because DCS seems to report them offset by one, debugs shows the "true" numbers.
                destroyRedGroup(groupName)
            end
        end
    end
end

function destroyRedGroup(groupName)
    Group.getByName(groupName):destroy()                                  --destroys the red group
    redNameArray = arraySlice(redNameArray, groupName)                    --removes the entry of the group from the redNameArray                                  
    debug(groupName .. " destroyed!")
end

--TODO: Write function that destroys old engagement and spawn new one elsewere

function taskRed(args)
    local group = Group.getByName(args["groupString"])
    local vec3Red = mist.getLeadPos(args["groupString"])
    local vec3Blue = blueVec3array[args["blueIndex"]]
    
    local dx = vec3Red.x - vec3Blue.x
    local dz = vec3Red.z - vec3Blue.z
    
    fireVec2 = {
        x = vec3Red.x - dx/10,
        y = vec3Red.z - dz/10
    }
   
    local controller = group:getController()    
        
    local fireTask = {                                         
        id = 'FireAtPoint', 
        params = {
        point = fireVec2,                  
        radius = 100, 
        expendQty = 1e10,
        expendQtyEnabled = true,
        }
       } 
    controller:pushTask(fireTask)
end

function markBlueForces()
    for i = 1, #blueNameArray, 1 do
        local group = Group.getByName(blueNameArray[i])
        local vec3 = mist.getLeadPos(blueNameArray[i])
        trigger.action.smoke(vec3, 2)
        --Audio file
        debug("Marking blue forces") 
    end
end

function markRedForces()
    for i = 1, #redVec3array, 1 do
        if math.random(0,4) == 4 then
            trigger.action.smoke(redVec3array[i])
            --Audio file
        end
    end
end

function genAmbush()
    for i = 1, #ambushZones, 1 do
        if ambushStates[i] == false and math.random(0,1) == 1 then
            local template = ambushRedTemplates[math.random(1,#ambushRedTemplates)] --Pick random template
            local groupTemp = Group.getByName(template)                 --Get template object
            local countryId = groupTemp:getUnit(1):getCountry()         --Get countryID of template
            local countryName = country.name[countryId]                 --Get country Name
            local groupString = countryName.." gnd "..tostring(spawnIndex)--Put above together to make groupName
    
            mist.cloneInZone(template, ambushZones[i])                   --Spawn template group in zone
            spawnIndex = spawnIndex + 1
            debug("Spawned Ambush") 
        end
    end
end

function taskArty(vec2)                                                 --Add support for cooldown 
    local group = Group.getByName(artyGroup)                            --User provides rounds, ammo
    local controller = group:getController()

    --mist.fixedWing.buildWP inbetween vec2 and unit pos
    --push wp to unit using mist.goRoute

    local fireTask = { 
        id = 'FireAtPoint', 
        params = {
        point = vec2,
        radius = 200,
        expendQty = 10,
        expendQtyEnabled = true, 
        }
    } 
    controller:setTask(fireTask)                                        
    --Audio file
    debug("Arty tasked")
end

function taskBombing(vec2)
    mist.cloneGroup(bombGroup,true)
    local group = Group.getByName('USA air 1')
    local controller = group:getController()
    
    local bombTask = { 
        id = 'CarpetBombing', 
        params = { 
        attackType = "Carpet",
        carpetLength = 300,
        point = vec2,
        weaponType = 16, 
        expend = "ALL",
        attackQty = 1, 
        groupAttack = false, 
        altitude = 3000,
        altitudeEnabled = false,
        } 
    }
    controller:pushTask(bombTask)

    debug("Bomber tasked") 
end

do
    debug("Starting init")
-- Add event Handlers
    local old_onEvent = world.onEvent
    world.onEvent = function(event)
        if (26 == event.id) then
            if event.text == "arty" then --could be possible to add initiator requirement
                taskArty(mist.utils.makeVec2(event.pos))  
            elseif event.text == "bomb" then
                taskBombing(mist.utils.makeVec2(event.pos))
            end
        elseif (15 == event.id) then
            local group = event.initiator:getGroup()
            local groupName = event.initiator:getName()
            for i = 1, #facGroup, 1 do
                if groupName == facGroup[i] and facF10[i] == true then
                    local groupID = group:getID()
                    facMenu = missionCommands.addSubMenuForGroup(groupID, "FAC Commands")
                    missionCommands.addCommandForGroup(groupID, "Smoke blue forces", facMenu, markBlueForces)
                    missionCommands.addCommandForGroup(groupID, "Smoke red forces", facMenu, markRedForces)
                    debug("Added FAC F10")
                    facF10[i] = false
                end
            end
            
        elseif (8 == event.id) then --unit dead event
            --maybe check for red coalition
            debug("Unit destroyed: " .. event.initiator:getGroup():getName())
            checkHealth(event.initiator:getGroup():getName())
        end

        return old_onEvent(event)
    end

-- Init scripts
    spawnEngagements()
    genAmbush()

    debug("Completed init")
end