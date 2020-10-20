    --  Name:                           ACT_groundForces
    --  Author:                         Activity, Tony, Markus, Tim
	-- assert(loadfile('C:\\Users\\username\\Saved Games\\DCS.openbeta\\Missions\\ACT_groundForces.lua'))()
    --  Last Modified On:               17/10/2020
    --  Dependencies:                   Mist.lua
    --  Description:
    --      Spawns and controls groundforces for Vietstan mission
    --  Usage:
    --      1. Place zoneEngagement for engagements to be spawned
    --      2. Place zoneAmbush for for random ambushes within said zone
    --      3. Place zoneLZ for generated medevac
	
--[[List of outstanding work to do

1. Add in flares on friendly troop locations when requested, instead of smoke
2. Add in flares on mark points instead of smoke, or as an alternative during the night.
3. Add in some randomization on smoke / flare mark point co ords so not perfectly accurate
4. Change default CTLD units we can pickup to consist of
	Recon group - 2 M4 soliders
	Rife chalk - 12 soliders, most m4, one 249
	Mortar team - 3 soliders, or appropritae unit + 1 mortar
	Anti air team - 1 m4 dude, 1 stinger (igla?) dude
	Medical team - Some civies (maybe use USN deck crew?)
	
]]--	
	
	

-- Define Settings
infantryBlueTemplates = {"blueInfantry"}
infantryRedTemplates  = {"redInfantry"}
ambushRedTemplates = {"redAmbush"}

artyGroup = "artyGroup"
bombGroup = "bombGroup"

smokeCooldownTimer = 120                                 --shortest amount of time in seconds a smoke can be called in
smokeTime = timer.getTime()
artyCooldownTimer = 120                                 --shortest amount of time in seconds an arty strike can be called in
artyTime = timer.getTime()
b52CooldownTimer = 600                                  --shortest amount of time in seconds a b52 can be spawned in
b52Time = timer.getTime()								--sets the initial clock runing on the b52 spawner
b52Counter = -1 									    --Global variable for counting the might B52's we spawn
b52vec3 = {}                                            --later used to pass b52 target co 
attackHeading = 0											

engagementZones = {"zoneEngagement-1", "zoneEngagement-2"}
ambushZones = {"zoneAmbush-1", "zoneAmbush-2"}

enableDebug = false

redAmountPerZone = 4

refreshTimer = 300

engDistanceOuter = 480 
engDistanceInner = 100  

destThreshold = 0.65                                     --if a group falls below this amount of its inital strenght, it gets destroyed

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

function arraySlice(array, slicedEntry)
	local sliced = {}
	for i = 1, #array, 1 do
    	if array[i] ~= slicedEntry then
    		sliced[#sliced+1] = array[i]
    	end
	end
	return sliced
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
			redNameArray[#redNameArray + 1] = groupString
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
	
function spawnB52()
	mist.cloneGroup("bombGroup",true) -- clone a new plane, the true preserves the original unit waypoints and action
	b52Counter = b52Counter + 1 -- a new b52 spawned lets increment out counter used in name assigning of bombing points
	debug("Bomber spawned")
end	
	
function taskBombing(b52vec3, attackDirection) --task spawns a late activated unit called bombGroup gives it a waypoint to bomb and blows it up
	local target = {} --empty target arrary
		target.point = {x= b52vec3.x , y= b52vec3.z} --dcs is dumb for which co ordinates are actual x and y
        target.weaponType = 16 -- 16 is iron bombs
        target.expend = "All" --other options, "All" "Half" "Quarter" "Four" "Two" "One"
        target.attackQty = 1
        target.direction = attackDirection
        target.directionEnabled = true			--enforces target direction to be used
		target.altitude = 3000 --min altitude to not go below above ground level (may cause wonky flight and death if set too low)
		target.altitudeEnabled = true -- true if min altitude restrictoin to be enforced
		target.groupAttack = true -- only useful if more than one bomber, will attack together
 local engage = {id = 'Bombing', params = target} -- combine attack type and target for bombing
 if (b52Counter == 0) then --sets the name if the first plane is spawning in
	 unitName = 'USA air'
 else
	 unitName = "USA air " .. b52Counter --otherwise the plane name is USA air X where x is an int that increases
 end
 --notify(unitName,5) --debug print plane name
 Group.getByName(unitName):getController():setTask(engage) --set task to bomber, will expend all bombs and rtb with our settings so no need to push task queue
	--audio file
    debug("Bomber tasked")  
end

function taskSmoke(vec3,colour) --spawn a smoke on a marker
	
	local vec3Rand = mist.getRandPointInCircle(vec3,10,200)
	local vec3RandGL = mist.utils.makeVec3GL(vec3Rand)
	
	if colour == "green" then
		trigger.action.smoke(vec3RandGL,0) --vec3 and colour, 0 = green" 1= red" 2 = white 3 =orange 4= blue
	elseif colour == "red" then	
		trigger.action.smoke(vec3RandGL,1) --vec3 and colour, 0 = green" 1= red" 2 = white 3 =orange 4= blue
	elseif colour == "white" then	
		trigger.action.smoke(vec3RandGL,2) --vec3 and colour, 0 = green" 1= red" 2 = white 3 =orange 4= blue
	elseif colour == "orange" then	
		trigger.action.smoke(vec3RandGL,3) --vec3 and colour, 0 = green" 1= red" 2 = white 3 =orange 4= blue
	elseif colour == "blue" then	
		trigger.action.smoke(vec3RandGL,4) --vec3 and colour, 0 = green" 1= red" 2 = white 3 =orange 4= blue
	end
	notify("Smoke is on the deck",10)
	debug("Smoke mission")
end

function notify(message, displayFor) --activiy notify function
    trigger.action.outText(message, displayFor)
end

function setThreshold(mode)
    local thresholdFactors = { 0.3, 0,4 ,0.5, 0,6, 0,7, 0,8}
    destThreshold = thresholdFactors[mode]
    notify("destThreshold set to: " .. thresholdFactors[mode], 5)
end

do
    debug("Starting init")
-- Add event Handlers
    local old_onEvent = world.onEvent
    world.onEvent = function(event)
        if (26 == event.id) then --this event is detecting mark point on the map
            if event.text == "arty" then --could be possible to add initiator requirement
				if ((artyTime + artyCooldownTimer) <= timer.getTime()) then
					taskArty(mist.utils.makeVec2(event.pos))
                    taskArty(mist.utils.makeVec2(event.pos))  
					taskArty(mist.utils.makeVec2(event.pos))
                    taskArty(mist.utils.makeVec2(event.pos))  
					taskArty(mist.utils.makeVec2(event.pos))
                    taskArty(mist.utils.makeVec2(event.pos))  
					taskArty(mist.utils.makeVec2(event.pos))
                    taskArty(mist.utils.makeVec2(event.pos))  
					taskArty(mist.utils.makeVec2(event.pos))
					notify("Fire mission order received.",10)
					artyTime = timer.getTime()
					debug("Arty mission sent")
				else
					local timeTilArty = (artyTime + artyCooldownTimer) - timer.getTime() --some maths to work out how long the next strike is in seconds
					local timeTilArty = math.floor(timeTilArty+0.5) --sort of round the function super crude but works
					notify("Fire mission not avaliable for another " .. timeTilArty .. " seconds." ,10)
					debug("Arty mission, too soon fail.")
				end	
                 
            elseif string.find (event.text, "bomb") then --if the mark point has the word bomb in it

                if ((b52Time + b52CooldownTimer) <= timer.getTime()) then

                    local attackAzimuthDeg = string.match(event.text, '%d%d%d') --checks for 3 digitis in the message of the mark, if more than 3 digits are entered, it returns the first 3. 
                    debug ("attackAzimuthDeg: " .. attackAzimuthDeg)
                    if tonumber (attackAzimuthDeg) <= 360 then

                        attackHeading = mist.utils.toRadian (tonumber(attackAzimuthDeg)) + 3.14
                        debug("attackHeading(rad): " .. attackHeading)

                        spawnB52()					 --function to spawn a b52
					    b52vec3 = mist.utils.makeVec3GL(event.pos) --makeVec3GL is basically Vec2 at ground level int vec 3, this is the location of the bomber
					    notify("Arc Light strike confirmed, B-52 running in hot.",10)
					    b52Time = timer.getTime() -- reset the clock
                        debug("B-52 mission sent")
                    
                    else
                        notify("Invalid request: Please enter attack direction", 10)
                    end
                    
				else
					local timeTilStrike = (b52Time + b52CooldownTimer) - timer.getTime() --some maths to work out how long the next strike is in seconds
					local timeTilStrike = math.floor(timeTilStrike+0.5) --sort of round the function super crude but works
					notify("Arc Light strike not avaliable for another " .. timeTilStrike .. " seconds." ,10)
					debug("Bomber mission, too soon fail")
                end
                
			elseif (event.text == "green" or event.text == "red" or event.text == "white" or event.text == "orange" or event.text == "blue") then --if the mark point has the word smoke in it
				if ((smokeTime + smokeCooldownTimer) <= timer.getTime()) then
					vec3 = mist.utils.makeVec3GL(event.pos) --makeVec3GL is basically Vec2 at ground level into vec 3
					taskSmoke(vec3,event.text)
					smokeTime = timer.getTime() -- reset the clock
					debug("Smoke mission sent")
				else
					local timeTilStrike = (smokeTime + smokeCooldownTimer) - timer.getTime() --some maths to work out how long the next strike is in seconds
					local timeTilStrike = math.floor(timeTilStrike+0.5) --sort of round the function super crude but works
					notify("Smoke marker unavailable for another " .. timeTilStrike .. " seconds." ,10)
					debug("Smoke mission, too soon fail")
				end
            end
		elseif (3 == event.id and -1 ~= b52Counter) then
			--debug("debug event ID: " .. event.id, 5)
			taskBombing(b52vec3, attackHeading)
            debug("Send B-52 vec3 co ord")
            
		elseif (15 == event.id) then
		if event.initiator:getCategory() == 1 then
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
		end
        elseif (8 == event.id) then --unit dead event
            --debug("Event.initiator category: " .. event.initiator:getCategory())
            if event.initiator:getCategory() == 1 then --checks if the initiator is a unit
                if event.initiator:getCoalition() ==  1 then --checks if the initator is from the red coalition
                    debug("Unit destroyed: " .. event.initiator:getGroup():getName())
                    checkHealth(event.initiator:getGroup():getName())
                end
            end
        end
        return old_onEvent(event)
    end
	

    --balancing test radio things:
    radioBalancingSubMenu = missionCommands.addSubMenu ("set destThreshold:")
    radioBalancingOption1 = missionCommands.addCommand ("destThreshold = 0.3", radioBalancingSubMenu, setThreshold, 1)
    radioBalancingOption2 = missionCommands.addCommand ("destThreshold = 0.4", radioBalancingSubMenu, setThreshold, 2)
    radioBalancingOption3 = missionCommands.addCommand ("destThreshold = 0.5", radioBalancingSubMenu, setThreshold, 3)
    radioBalancingOption4 = missionCommands.addCommand ("destThreshold = 0.6", radioBalancingSubMenu, setThreshold, 4)
    radioBalancingOption5 = missionCommands.addCommand ("destThreshold = 0.7", radioBalancingSubMenu, setThreshold, 5)
    radioBalancingOption6 = missionCommands.addCommand ("destThreshold = 0.8", radioBalancingSubMenu, setThreshold, 6)

-- Init scripts
    spawnEngagements()
    genAmbush()

    debug("Completed init")
end