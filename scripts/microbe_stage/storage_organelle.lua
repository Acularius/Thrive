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
    self.bandwidth = bandwidth
    self.bandwidthTimer = 0
    self.remainingBandwidth = bandwidth  -- Bandwidth is limited by time passing, every 1 second the remaining bandwidth is reset
    self.capacity = capacity
    self.compounds = {}
    self.stored = 0
    self.parentIndex = 0
end


function StorageOrganelle:load(storage)
    Organelle.load(self, storage)
    self.bandwidth = storage:get("bandwidth", 10)
    self.remainingBandwidth = storage:get("remainingBandwidth", self.bandwidth)
    self.bandwidthTimer = storage:get("bandwidthTimer", 0)
    self.capacity = storage:get("capacity", 100)
end


function StorageOrganelle:storage()
    local storage = Organelle.storage(self)
    storage:set("bandwidth", self.bandwidth)
    storage:set("capacity", self.capacity)
    storage:set("remainingBandwidth", self.remainingBandwidth)
    storage:set("bandwidthTimer", self.bandwidthTimer)
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

--Stores as much of the compound as possible, returning the amount that wouldn't fit
function StorageOrganelle:storeCompound(compoundId, amount, mayFill)
    local canFit = self.capacity - self.stored -- default to max full
    if mayFill == false then
        canFit = self.capacity * STORAGE_EJECTION_THRESHHOLD - self.stored
        if canFit <= 0 then
            return amount -- Nothing could be stored without going above threshhold
        end
    end
    local canFitCompound = canFit/CompoundRegistry.getCompoundUnitVolume(compoundId)
    local amountToStore = math.min(amount, self.remainingBandwidth, canFitCompound)
    if self.compounds[compoundId] == nil then
        self.compounds[compoundId] = amountToStore
    else
        self.compounds[compoundId] = self.compounds[compoundId] + amountToStore
    end
    self.stored = self.stored + CompoundRegistry.getCompoundUnitVolume(compoundId)*amountToStore
    self.remainingBandwidth = self.remainingBandwidth - amountToStore
    return amount - amountToStore
end

--Ejects as much of the compound as possible, returning how much was ejected
function StorageOrganelle:takeCompound(compoundId, amount)
    if self.compounds[compoundId] ~= nil then
        local drainAmount = math.min(amount, self.compounds[compoundId], self.remainingBandwidth)
        self.compounds[compoundId] = self.compounds[compoundId] - drainAmount
        self.stored = self.stored - drainAmount
        self.remainingBandwidth = self.remainingBandwidth - drainAmount
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
-- @return excessCompounds
function StorageOrganelle:gatherExcessCompounds(compoundPriorityTable)

    local excessCompounds = {}

    while self.stored/self.capacity > STORAGE_EJECTION_THRESHHOLD do
        -- Find lowest priority compound type and eject that
        local lowestPriorityId = nil
        local lowestPriority = math.inf
        for compoundId,_ in ipairs(self.compounds) do
            if compoundPriorityTable[compoundId] ~= nil and compoundPriorityTable[compoundId] < lowestPriority then
                lowestPriority = compoundPriorityTable[compoundId]
                lowestPriorityId = compoundId
            end
        end
        -- Return an amount that either is how much the organelle contains of the compound or until it goes to the threshhold
        local amountInExcess = math.min(self.compounds[lowestPriorityId],self.capacity * STORAGE_EJECTION_THRESHHOLD - self.stored)
        excessCompounds[lowestPriorityId] = amountInExcess
        self.stored = self.stored - amountInExcess
        if self.compounds[lowestPriorityId] ~= amountInExcess then -- If we didn't absorb all the compounds with id lowestPriorityId
           self.compounds[lowestPrioirtyId] = nil
           break
        end
    end
    for compoundId,_ in ipairs(self.compounds) do
        if compoundPriorityTable[compoundId] ~= nil and compoundPriorityTable[compoundId] == 0 then
            local uselessCompoundAmount = math.min(self.compounds[compoundId], self.remainingBandwidth)
            self.remainingBandwidth = self.remainingBandwidth - uselessCompoundAmount
            if excessCompounds[compoundId] ~= nil then
                excessCompounds[compoundId] = excessCompounds[compoundId] + uselessCompoundAmount
            else
                excessCompounds[compoundId] = uselessCompoundAmount
            end
        end
    end
    
    return excessCompounds
       -- Remember

--unit test new functionality
--consider bandwidth in gatherExcessCompounds
end

function StorageOrganelle:update(microbe, milliseconds)
    Organelle.update(self, microbe, milliseconds)
    self.bandwidthTimer = self.bandwidthTimer + milliseconds
    if self.bandwidthTimer > 1000 then
        self.remainingBandwidth = self.bandwidth
        self.bandwidthTimer = self.bandwidthTimer - 1000
    end
end

