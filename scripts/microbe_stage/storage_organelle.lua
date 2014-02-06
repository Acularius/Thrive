--------------------------------------------------------------------------------
-- A storage organelle class
--------------------------------------------------------------------------------
class 'StorageOrganelle' (Organelle)

STORAGE_EJECTION_THRESHHOLD = 0.8

-- Constructor
--
-- @param bandwidth
-- The rate of transfer of this organelle
--
-- @param capacity
-- The maximum stored amount
function StorageOrganelle:__init(bandwidth, capacity)
    Organelle.__init(self)
    self.capacity = capacity
    self.compounds = {}
    self.stored = 0
    self.parentIndex = 0
end


function StorageOrganelle:load(storage)
    Organelle.load(self, storage)
    self.capacity = storage:get("capacity", 100)
end


function StorageOrganelle:storage()
    local storage = Organelle.storage(self)
    storage:set("capacity", self.capacity)
    return storage
end

-- Overridded from Organelle:onAddedToMicrobe
function StorageOrganelle:onAddedToMicrobe(microbe, q, r)
    Organelle.onAddedToMicrobe(self, microbe, q, r)
    parentIndex = microbe:addStorageOrganelle(self)
end

-- Overridded from Organelle:onRemovedFromMicrobe
function StorageOrganelle:onRemovedFromMicrobe(microbe, q, r)
    Organelle.onRemovedFromMicrobe(self, microbe, q, r)
    microbe:removeStorageOrganelle(self)
end

-- Stores as much of the compound as possible, returning the amount that was stored
--
-- @param compoundId
-- The compound type to store
--
-- @param amount
-- The amount to attempt to store
--
-- @param mayFill
-- Determines if the organelle may be filled to the brink or if it should stay below its threshold
--
-- @return storedAmount
function StorageOrganelle:storeCompound(compoundId, amount, mayFill)
    local canFit = self.capacity - self.stored -- default capacity is max full
    if mayFill == false then
        canFit = self.capacity * STORAGE_EJECTION_THRESHHOLD - self.stored
        
        if canFit <= 0 then
            return 0 -- Nothing could be stored without going above threshhold
        end
    end
    local canFitCompound = canFit/CompoundRegistry.getCompoundUnitVolume(compoundId)
    if mayFill == false then
    end
    local amountToStore = math.min(amount, canFitCompound)
    if self.compounds[compoundId] == nil then
        self.compounds[compoundId] = amountToStore
    else
        self.compounds[compoundId] = self.compounds[compoundId] + amountToStore
    end
    self.stored = self.stored + amountToStore*CompoundRegistry.getCompoundUnitVolume(compoundId)
    
    return amountToStore
end

--Ejects as much of the compound as possible, returning how much was taken
--
-- @param compoundId
-- The compound type to take
--
-- @param amount
-- The amount to attempt to take
--
-- @return takenAmount
function StorageOrganelle:takeCompound(compoundId, amount)
    if self.compounds[compoundId] ~= nil then
        local drainAmount = math.min(amount, self.compounds[compoundId])
        self.compounds[compoundId] = self.compounds[compoundId] - drainAmount
        self.stored = self.stored - drainAmount
        return drainAmount
    else
        return 0
    end
end

-- Returns a table containing compounds the organelle wants to eject due to being over threshhold
--
-- @param compoundPriorityTable
--  A table containing the priorities of each compound in the parent microbe (specific to microbe)
--
-- @param gatherLimit
--  The maximum amount that may be gathered from organelle, set to nil if unlimited.
--
-- @return excessCompounds
function StorageOrganelle:gatherExcessCompounds(compoundPriorityTable, gatherLimit)
    local excessCompounds = {}
    local remainingGatherLimit = gatherLimit

    while self.stored/self.capacity > STORAGE_EJECTION_THRESHHOLD do
        
        -- Find lowest priority compound type and eject that
        local lowestPriorityId = nil
        local lowestPriority = math.huge
       -- for compoundId,_ in ipairs(self.compounds) do -- This should work but for some reason does not iterate over Glucose (and possibly others)
        for compoundId in CompoundRegistry.getCompoundList() do    
            if self.compounds[compoundId] ~= nil and self.compounds[compoundId] > 0  and compoundPriorityTable[compoundId] ~= nil and compoundPriorityTable[compoundId] < lowestPriority then
                lowestPriority = compoundPriorityTable[compoundId]
                lowestPriorityId = compoundId
            end
        end
        assert(lowestPriorityId ~= nil, "The microbe didn't seem to contain any compounds but was over the threshold")
        assert(self.compounds[lowestPriorityId] ~= nil, "Organelle was over threshold but didn't have any valid compounds to expell")
        -- Return an amount that either is how much the organelle contains of the compound or until it goes to the threshhold
        local amountInExcess
        
        if gatherLimit ~= nil then
            if remainingGatherLimit == 0 then
                break -- We are not allowed to eject any more compounds for now, have to wait
            end
            amountInExcess = math.min(self.compounds[lowestPriorityId],self.stored - self.capacity * STORAGE_EJECTION_THRESHHOLD, remainingGatherLimit)
            remainingGatherLimit = remainingGatherLimit - amountInExcess
        else
            amountInExcess = math.min(self.compounds[lowestPriorityId],self.stored - self.capacity * STORAGE_EJECTION_THRESHHOLD)
        end
        excessCompounds[lowestPriorityId] = amountInExcess
        self.stored = self.stored - amountInExcess*CompoundRegistry.getCompoundUnitVolume(lowestPriorityId)
        self.compounds[lowestPriorityId] = self.compounds[lowestPriorityId] - amountInExcess
    end
    -- Expell compounds of priority 0 periodically
    -- for compoundId,_ in ipairs(self.compounds) do -- Should work but doesnt
    for compoundId in CompoundRegistry.getCompoundList() do
        if self.compounds[compoundId] ~= nil and compoundPriorityTable[compoundId] ~= nil and compoundPriorityTable[compoundId] == 0 then
            local uselessCompoundAmount
            if gatherLimit ~= nil then
                uselessCompoundAmount = math.min(self.compounds[compoundId], remainingGatherLimit)
                remainingGatherLimit = remainingGatherLimit - uselessCompoundAmount
            else
                uselessCompoundAmount = self.compounds[compoundId]
            end
            self.stored = self.stored - uselessCompoundAmount
            self.compounds[compoundId] = self.compounds[compoundId] - uselessCompoundAmount
            if self.compounds[compoundId] == 0 then
                self.compounds[compoundId] = nil
            end
            if excessCompounds[compoundId] ~= nil then
                excessCompounds[compoundId] = excessCompounds[compoundId] + uselessCompoundAmount
            else
                excessCompounds[compoundId] = uselessCompoundAmount
            end
        end
    end
    return excessCompounds
end

function StorageOrganelle:update(microbe, milliseconds)
    Organelle.update(self, microbe, milliseconds)
end

