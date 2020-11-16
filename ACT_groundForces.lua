    --  Name:                           ACT_groundForces
    --  Author:                         Activity, Tony, Markus, Tim
	-- assert(loadfile('C:\\Users\\username\\Saved Games\\DCS.openbeta\\Missions\\ACT_groundForces.lua'))()
    --  Last Modified On:               22/10/2020
    --  Dependencies:                   Mist.lua
    --  Description:
    --      Spawns and controls groundforces for Vietstan mission
    --  Usage:
    --      1. Place zoneEngagement for engagements to be spawned
    --      2. Place zoneAmbush for for random ambushes within said zone
    --      3. Place zoneLZ for generated medevac
	
--[[List of outstanding work to do
    1. Sep templates for blue boys in centre of zone
    2. task Blue to fire at point when no LOS
]]--	
	
	

-- Define Settings
infantryBlueTemplates = {}
infantryBlueCentreTemplates = {}

infantryRedTemplates  = {}
ambushRedTemplates = {}

artyGroup = "artyGroup"
bombGroup = "bombGroup"											

engagementZones = {}
ambushZones = {}
pickupZones = {}

enableDebug = false

refreshTimer = 300

engDistance = 500 

engStartTime = 600                                                 --Time between mission start and first engagement

engDurationMin = 2700                                               --Min engagement duration
engDurationMax = 3600                                               --Max engagement duration

redRespawnCounter = 30
redRespawnOffset = 400
redRespawnTimerMin = 200
redRespawnTimerMax = 600

medevacTimerMin = 600                                              --Time between medevac spawning
medevacTimerMax = 1000

-- Declarations
ACT = {}
ACT.medevacState = false
ACT.medevacEnd =   false

blueVec3array = {}
blueNameArray = {}
redVec3array = {}
redNameArray = {}
redTypeArray = {}
engagementStates = {}
ambushStates = {}
engTime = 0
engTimeOld = 0

medevacCount = 0
medevacFlag = 100

spawnIndex = 1

function spawnEngagements(amount)
    for i = 1, #engagementZones, 1 do
        debug("Spawning engagement")
        local vec3Zone = mist.utils.zoneToVec3(engagementZones[i])
        spawnBlueCentre(vec3Zone)                                 --Spawn blue at zone centre, spawns normal template for now
        engTimeOld = engTime
        engTime = math.random(engDurationMin, engDurationMax)    
        
        local vec2BlueOffset = {                                  --Offset vector with zone radius
            x = trigger.misc.getZone(engagementZones[i]).radius,
            y = 0,
        }
        local vec2RedOffset = {                                   --Offset vector with zone radius + engDistance 
            x = trigger.misc.getZone(engagementZones[i]).radius + engDistance,
            y = 0,
        }

        local angle = 2*math.pi/amount
            
        for i = 0, amount-1 do
            local vec2BlueRotated = mist.vec.rotateVec2(vec2BlueOffset, angle*i )--rotate offset with angle * i
            local vec3Blue = mist.vec.add(vec3Zone, mist.utils.makeVec3GL(vec2BlueRotated))
                
            local vec2RedRotated = mist.vec.rotateVec2(vec2RedOffset, angle*i)
            local vec3Red = mist.vec.add(vec3Zone, mist.utils.makeVec3GL(vec2RedRotated))  
            local vec3Red = mist.getRandPointInCircle(vec3Red, engDistance/3) --Add some randomization to spice it up
                
            spawnBlueAtVec3(vec3Blue, false, vec3Red)               --Spawn blue
            spawnRedAtVec3(vec3Red)                                 --Spawn red
        end
        engagementStates[i] = false
    end
end

function debug(string)
    if string ~= nil then
        if enableDebug == true then
            trigger.action.outText(string, 5)
        end
        env.error("__VIETSTAN__ : "..string, false)
    elseif string == nil then
        if enableDebug == true then
            trigger.action.outText("debug got passed nil", 5)
        end
        env.error("__VIETSTAN__ : debug got passed nil", false)
    end
end

function spawnBlueAtVec3(vec3Blue, tasking, vec3Red)
    local template = infantryBlueTemplates[math.random(1,#infantryBlueTemplates)] --Pick random template
    local groupTemp = Group.getByName(template)                     --Get template object
    local countryId = groupTemp:getUnit(1):getCountry()             --Get countryID of template
    local countryName = country.name[countryId]                     --Get country Name
    local groupString = countryName.." gnd "..tostring(spawnIndex)  --Put above together to make groupName
    
    mist.teleportToPoint {
        groupName = template,
        point = vec3Blue,
        action = "clone",
        disperse = false,
    }

    blueVec3 = mist.getLeadPos(groupString)                         --Get pos of leader
    blueVec3array[#blueVec3array + 1] =  blueVec3                   --Array length doubles as counter
    blueNameArray[#blueNameArray + 1] = groupString
    spawnIndex = spawnIndex + 1

    local group = Group.getByName(groupString)
    local controller = group:getController()
    
    local setImmortal = { id = 'SetImmortal', params = {value = true}}
    controller:setCommand(setImmortal)
    controller:setOption(0, 4)                                      --Set hold fire on start

    if tasking == true then
        paramsBlue = {}
        paramsBlue["groupString"] = groupString
        paramsBlue["vec3Red"] = vec3Red
        debug("Blue Task sent @"..tostring(vec3Red))
        local timing = engStartTime + (engTimeOld*#engagementStates)
        debug("Tasking scheduled at: "..tostring(timing))
        debug("Engagement duration is: "..tostring(engTime))
        timer.scheduleFunction(taskBlue, paramsBlue, timer.getTime() + timing)
    end

    debug("Spawned blue infantry")
end

function spawnBlueCentre(vec3Blue)
    local template = infantryBlueCentreTemplates[math.random(1,#infantryBlueCentreTemplates)] --Pick random template
    local groupTemp = Group.getByName(template)                     --Get template object
    local countryId = groupTemp:getUnit(1):getCountry()             --Get countryID of template
    local countryName = country.name[countryId]                     --Get country Name
    local groupString = countryName.." gnd "..tostring(spawnIndex)  --Put above together to make groupName
    
    mist.teleportToPoint {
        groupName = template,
        point = vec3Blue,
        action = "clone",
        disperse = false,
    }

    blueVec3 = mist.getLeadPos(groupString)                         --Get pos of leader
    blueVec3array[#blueVec3array + 1] =  blueVec3                   --Array length doubles as counter
    blueNameArray[#blueNameArray + 1] = groupString
    spawnIndex = spawnIndex + 1

    timer.scheduleFunction(genMedevac, blueVec3, timer.getTime() + engStartTime + math.random(medevacTimerMin, medevacTimerMax))
end

function spawnRedAtVec3(vec3Red)                                   --Spawns amount Red inf. to surround last spawned blue inf.
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
    redTypeArray[#redTypeArray + 1] = 1
    spawnIndex = spawnIndex + 1  

    local group = Group.getByName(groupString)
    local controller = group:getController()

    controller:setOption(0, 4)                                      --Set hold fire on start

    for i = 1, #blueVec3array do 
        local distance =  mist.utils.get2DDist(vec3Red, blueVec3array[i])
        if distance <= engDistance + 100 then
            blueIndex = i
        end
    end 

    if blueIndex == nil then
        blueIndex = 1
    end
    
    params = {}
    params["groupString"] = groupString
    params["blueIndex"] = blueIndex
    params["engDuration"] = engTime

    local timing = engStartTime -- + (engTimeOld*#engagementStates)
    debug("Tasking scheduled at: "..tostring(timing))
    debug("Engagement duration is: "..tostring(engTime))
    timer.scheduleFunction(taskRed, params, timer.getTime() + timing)

    debug("Spawned red infantry "..tostring(#redVec3array))
end

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
    controller:setOption(0, 2)                                         --Set open fire
    
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

    timer.scheduleFunction(stopEngagement, args["groupString"], timer.getTime() + math.random(engDurationMin, engDurationMax))
end

function taskBlue(args)
    local group = Group.getByName(args["groupString"])
    local vec3Blue = mist.getLeadPos(args["groupString"])
    local vec3Red = args["vec3Red"]

    local dx = vec3Red.x - vec3Blue.x
    local dz = vec3Red.z - vec3Blue.z
    
    fireVec2 = {
        x = vec3Blue.x + dx/10,
        y = vec3Blue.z + dz/10
    }
   
    local controller = group:getController()    
    controller:setOption(0, 2)                                         --Set open fire
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
    
    timer.scheduleFunction(stopEngagement, args["groupString"], timer.getTime() + math.random(engDurationMin, engDurationMax))
end

function stopEngagement(groupName)
    debug("Stopping engagement")
    local group = Group.getByName(groupName)
    local controller = group:getController()

    controller:setOption(0, 4)                                          -- Set hold fire
    controller.popTask(controller)

    ACT.medevacEnd = true
end

function stopMission()
    for i = 1, #redNameArray do
        stopEngagement(redNameArray[i])
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

            redVec3array[#redVec3array + 1] =  mist.utils.zoneToVec3(ambushZones[i])
            redNameArray[#redNameArray + 1] = groupString
            redTypeArray[#redTypeArray + 1] = 0
            spawnIndex = spawnIndex + 1

            debug("Spawned Ambush") 
        end
    end
end

function genMedevac(vec3Input)
    trigger.action.smoke(vec3Input, 2)
    ctld.spawnGroupAtPoint("blue", 1, vec3Input, 0)
    trigger.action.outText("Immediate medevac requested at white smoke!", 5)
    debug("Generated Medevac")

    args = {}
    args["vec3Input"] = vec3Input
    args["index"] = spawnIndex

    timer.scheduleFunction(checkMedevac, args, timer.getTime() + 5)
    spawnIndex = spawnIndex + 1
    ACT.medevacState = true
    medevacCount = medevacCount + 1
end

function checkMedevac(args)
    local group = Group.getByName(ctld.droppedTroopsBLUE[#ctld.droppedTroopsBLUE])

    if group ~= nil then                        --If the dropped group exists, task to hold
        local controller = group:getController()
        local holdTask = { 
            id = 'Hold', 
            params = { 
            } 
        }

        controller:pushTask(holdTask)
    end
    
    if ACT.medevacState == false then
        trigger.action.outText("Medevac dropped off", 5)
        timer.scheduleFunction(genMedevac, args["vec3Input"], timer.getTime() + math.random(medevacTimerMin, medevacTimerMax ))
    elseif ACT.medevacEnd == false then
        timer.scheduleFunction(checkMedevac, args, timer.getTime() + 5)
    end
end

function checkHealth(groupName)
    for i = 1, #redNameArray do
        if redNameArray[i] == groupName then
            local initialSize = Group.getByName(groupName):getInitialSize()
            local currentSize = Group.getByName(groupName):getSize()

            debug(groupName .. ": " .. "initial size: " .. initialSize .. "; current size " .. currentSize) --is current size is off by +1 for some reason
            if (currentSize-1) / initialSize <= destThreshold then      --checks if a unit is below the destruction threshold. the -1 is because DCS seems to report them offset by one, debugs shows the "true" numbers.

                local _redVec3temp = redVec3array[i]
                local _redTypeTemp = redTypeArray[i]
                redVec3array = arraySlice(redVec3array, _redVec3temp)
                destroyRedGroup(groupName, i)

                if _redTypeTemp == 1 then
                    respawnRedGroup(_redVec3temp)
                end
            end
        end
    end
end

function destroyRedGroup(groupName, index)
    Group.getByName(groupName):destroy()                                  --destroys the red group
    redNameArray = arraySlice(redNameArray, groupName)                    --removes the entry of the group from the redNameArray
    redTypeArray = indexSlice(redTypeArray, index)
    debug(groupName .. " destroyed!")
end

function respawnRedGroup(vec3, target)
    if redRespawnCounter >= 1 then
        local vec3new = mist.getRandPointInCircle(vec3, redRespawnOffset) --Add some randomization to spice it up
        timer.scheduleFunction(spawnRedAtVec3, vec3new, timer.getTime() + math.random(redRespawnTimerMin, redRespawnTimerMax)) 
        redRespawnCounter = redRespawnCounter - 1
        debug("respawned group. New Respawncounter = " .. redRespawnCounter)
    else
        debug("no respawns available. Respawncounter = " .. redRespawnCounter)
    end
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

function indexSlice(array, slicedIndex)
	local sliced = {}
	for i = 1, #array, 1 do
    	if i ~= slicedIndex then
    		sliced[#sliced+1] = array[i]
    	end
	end
	return sliced
end

function templateArrayBuilder(type, arrayName, nameString) --1: groups; 2: zones
    local i = 1
    local _var = true
    if type == 1 then --check for groups
        while _var == true do
            local groupName = nameString .. tostring(i)
            if Group.getByName(groupName) ~= nil then
                debug (groupName .. " exists")
                arrayName[i] = groupName
                i = i + 1
            else
                _var = false
            end
        end
    elseif type == 2 then --check for zones
        while _var == true do
            local zoneName = nameString .. tostring(i)
            if trigger.misc.getZone(zoneName) ~= nil then
                debug (zoneName .. " exists")
                arrayName[i] = zoneName
                i = i + 1
            else
                _var = false
            end
        end
    end
end

do
    debug("Starting init")

-- Init scripts
    --build templateArrays
    --group Templates
    templateArrayBuilder(1, infantryBlueTemplates, "blueInfantry-")
    templateArrayBuilder(1, infantryBlueCentreTemplates, "blueInfantryCentre-")
    templateArrayBuilder(1, infantryRedTemplates, "redInfantry-")
    templateArrayBuilder(1, ambushRedTemplates, "redAmbush-")

    --zone Templates
    templateArrayBuilder(2, engagementZones, "zoneEngagement-")
    templateArrayBuilder(2, ambushZones, "zoneAmbush-")
    templateArrayBuilder(2, pickupZones, "infPickup-")

    --must be down here, not a great solution.     
    for i = 1, #ambushZones, 1 do
        ambushStates[i] = false
    end

    spawnEngagements(4)
    genAmbush()

    debug("Completed init")
end