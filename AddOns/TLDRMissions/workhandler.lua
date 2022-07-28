local addonName = ...
local addon = _G[addonName]


local frame = CreateFrame("Frame")
local timeElapsed = 0
local hasWork
local alreadyWorking
local isPaused = 0

local batches = {{}, {}, {}, {}}
-- structure: [1] = {["func"] = function, ["args"] = {arg1, arg2, ...}}, [2] = ...

local notifyCallback = function() end
local function notifyWorkStepComplete()
    notifyCallback()
end

function addon:registerWorkStepCallback(callback)
    notifyCallback = callback
end

frame:HookScript("OnUpdate", function(self, elapsed)
    if (not C_Garrison.IsAtGarrisonMissionNPC()) and (not addon.db.profile.allowProcessingAnywhere) then return end -- player starts simulations, walks away without stopping it, makes post on reddit complaining that my addon killed their FPS in Oribos... zzzzz
    if isPaused > 0 then return end
    if not hasWork then return end
    if alreadyWorking then return end
    alreadyWorking = true
    timeElapsed = timeElapsed + elapsed
	if (timeElapsed > 0.001) then
		timeElapsed = 0
        
        local workPerFrame = addon.db.profile.workPerFrame
        repeat
            repeat
                addon.dontWait = false
                if (table.getn(batches[1]) > 0) then
                    if (table.getn(batches[1][1]) > 0) then 
                        local currentWork = table.remove(batches[1][1], 1)
                        
                        currentWork.func(unpack(currentWork.args))
                        notifyWorkStepComplete()
                    else
                        table.remove(batches[1], 1)
                        addon.dontWait = true
                    end
                elseif (table.getn(batches[2]) > 0) then
                    if (table.getn(batches[2][1]) > 0) then
                        local currentWork = table.remove(batches[2][1], 1)
                        
                        currentWork.func(unpack(currentWork.args))
                        notifyWorkStepComplete()
                    else
                        table.remove(batches[2], 1)
                        addon.dontWait = true
                    end
                elseif (table.getn(batches[3]) > 0) then
                    if (table.getn(batches[3][1]) > 0) then
                        local currentWork = table.remove(batches[3][1], 1)
                        
                        currentWork.func(unpack(currentWork.args))
                        notifyWorkStepComplete()
                    else
                        table.remove(batches[3], 1)
                        addon.dontWait = true
                    end
                elseif (table.getn(batches[4]) > 0) then
                    if (table.getn(batches[4][1]) > 0) then
                        local currentWork = table.remove(batches[4][1], 1)
                        
                        currentWork.func(unpack(currentWork.args))
                        notifyWorkStepComplete()
                    else
                        table.remove(batches[4], 1)
                        addon.dontWait = true
                    end
                else
                    hasWork = false
                end
            until (not addon.dontWait)
        
            workPerFrame = workPerFrame - 1
        until workPerFrame < 1
	end
    alreadyWorking = false
end)

function addon:pauseWorker()
    isPaused = isPaused + 1
end

function addon:unpauseWorker()
    isPaused = isPaused - 1
end

function addon:isWorkerPaused()
    return (isPaused > 0)
end

function addon:createWorkBatch(priority)
    local batch = {}
    table.insert(batches[priority], batch) 
    return batch
end

function addon:addWork(batch, func, ...)
    table.insert(batch, {["func"] = func, ["args"] = {...}})
    hasWork = true
end

function addon:clearWork()
    wipe(batches[1])
    wipe(batches[2])
    wipe(batches[3])
    wipe(batches[4])
    hasWork = false
end

function addon:isCurrentWorkBatchEmpty()
    return (table.getn(batches[1]) == 0) and (table.getn(batches[2]) == 0) and (table.getn(batches[3]) == 0) and (table.getn(batches[4]) == 0)
end

function addon:getCurrentWorkBatchSize()
    print(table.getn(batches[1]), table.getn(batches[2]), table.getn(batches[3]), table.getn(batches[4]))
    if table.getn(batches[1]) > 0 then
        print(table.getn(batches[1][1]))
    end
    if table.getn(batches[2]) > 0 then
        print(table.getn(batches[2][1]))
    end
    if table.getn(batches[3]) > 0 then
        print(table.getn(batches[3][1]))
    end
    if table.getn(batches[4]) > 0 then
        print(table.getn(batches[4][1]))
    end
end