--------------------------------------------------------------------------------
-- MicrobeComponent
--
-- Holds data common to all microbes. You probably shouldn't use this directly,
-- use the Microbe class (below) instead.
--------------------------------------------------------------------------------
class 'MicrobeComponent' (Component)

COMPOUND_PROCESS_DISTRIBUTION_INTERVAL = 100 -- quantity of physics time between each loop distributing compounds to organelles. TODO: Modify to reflect microbe size.

BANDWIDTH_PER_ORGANELLE = 1 -- amount the microbes maxmimum bandwidth increases with per organelle added. This is a temporary replacement for microbe surface area

BANDWIDTH_REFILL_DURATION = 1000 -- The amount of time it takes for the microbe to regenerate an amount of bandwidth equal to maxBandwidth

STORAGE_EJECTION_THRESHHOLD = 0.8

EXCESS_COMPOUND_COLLECTION_INTERVAL = 1000 -- The amount of time between each loop to maintaining a fill level below STORAGE_EJECTION_THRESHHOLD and eject useless compounds


function MicrobeComponent:__init()
    Component.__init(self)
    self.organelles = {}
    self.storageOrganelles = {}
    self.processOrganelles = {}
    self.movementDirection = Vector3(0, 0, 0)
    self.facingTargetPoint = Vector3(0, 0, 0)
    self.capacity = 0
    self.stored = 0
    self.compounds = {}
    self.initialized = false
    self.maxBandwidth = 0
    self.remainingBandwidth = 0
    self.compoundCollectionTimer = EXCESS_COMPOUND_COLLECTION_INTERVAL
end


function MicrobeComponent:load(storage)
    Component.load(self, storage)
    local organelles = storage:get("organelles", {})
    for i = 1,organelles:size() do
        local organelleStorage = organelles:get(i)
        local organelle = Organelle.loadOrganelle(organelleStorage)
        local q = organelle.position.q
        local r = organelle.position.r
        local s = encodeAxial(q, r)
        self.organelles[s] = organelle
    end
    local storedCompoundIds = storage:get("storedCompoundIds", {})
    local storedCompoundAmounts = storage:get("storedCompoundAmounts", {})
    for i = 1,storedCompoundIds:size() do
        local id = storedCompoundIds:get(i)
        local amount = storedCompoundAmounts:get(i)
        self.compounds[id] = amount
        self.stored = self.stored + amount
    end
end


function MicrobeComponent:storage()
    local storage = Component.storage(self)
    -- Organelles
    local organelles = StorageList()
    for _, organelle in pairs(self.organelles) do
        local organelleStorage = organelle:storage()
        organelles:append(organelleStorage)
    end
    storage:set("organelles", organelles)
    local storedCompoundIds = StorageList()
    for id, _ in pairs(self.compounds) do
        storedCompounds:append(id)
    end
    storage:set("storedCompoundIds", storedCompoundIds)
    local storedCompoundAmounts = StorageList()
    for _, amount in pairs(self.compounds) do
        storedCompounds:append(amount)
    end
    storage:set("storedCompoundAmounts", storedCompoundAmounts)
    return storage
end

REGISTER_COMPONENT("MicrobeComponent", MicrobeComponent)


--------------------------------------------------------------------------------
-- Microbe class
--
-- This class serves mostly as an interface for manipulating microbe entities
--------------------------------------------------------------------------------
class 'Microbe'


-- Creates a new microbe with all required components
--
-- @param name
-- The entity's name. If nil, the entity will be unnamed.
--
-- @returns microbe
-- An object of type Microbe
function Microbe.createMicrobeEntity(name, aiControlled)
    local entity
    if name then
        entity = Entity(name)
    else
        entity = Entity()
    end
    local rigidBody = RigidBodyComponent()
    rigidBody.properties.shape = CompoundShape()
    rigidBody.properties.linearDamping = 0.5
    rigidBody.properties.friction = 0.2
    rigidBody.properties.linearFactor = Vector3(1, 1, 0)
    rigidBody.properties.angularFactor = Vector3(0, 0, 1)
    rigidBody.properties:touch()
    local compoundEmitter = CompoundEmitterComponent() -- Emitter for excess compounds
    compoundEmitter.emissionRadius = 5
    compoundEmitter.minInitialSpeed = 1
    compoundEmitter.maxInitialSpeed = 3
    compoundEmitter.particleLifetime = 5000
    local reactionHandler = CollisionComponent()
    reactionHandler:addCollisionGroup("microbe")
    local components = {
        CompoundAbsorberComponent(),
        OgreSceneNodeComponent(),
        MicrobeComponent(),
        reactionHandler,
        rigidBody,
        compoundEmitter
    }
    if aiControlled then
        local aiController = MicrobeAIControllerComponent()
        table.insert(components, aiController)
    end
    for _, component in ipairs(components) do
        entity:addComponent(component)
    end
    return Microbe(entity)
end

-- I don't feel like checking for each component separately, so let's make a
-- loop do it with an assert for good measure (see Microbe.__init)
Microbe.COMPONENTS = {
    compoundAbsorber = CompoundAbsorberComponent.TYPE_ID,
    microbe = MicrobeComponent.TYPE_ID,
    rigidBody = RigidBodyComponent.TYPE_ID,
    sceneNode = OgreSceneNodeComponent.TYPE_ID,
    compoundEmitter = CompoundEmitterComponent.TYPE_ID,
    collisionHandler = CollisionComponent.TYPE_ID
}


-- Constructor
--
-- Requires all necessary components (see Microbe.COMPONENTS) to be present in
-- the entity.
--
-- @param entity
-- The entity this microbe wraps
function Microbe:__init(entity)
    self.entity = entity
    self.gatheredDistributionTime = 0
    for key, typeId in pairs(Microbe.COMPONENTS) do
        local component = entity:getComponent(typeId)
        assert(component ~= nil, "Can't create microbe from this entity, it's missing " .. key)
        self[key] = entity:getComponent(typeId)
    end
    if not self.microbe.initialized then
        self:_initialize()
    end
    self:_updateCompoundAbsorber()
end


-- Adds a new organelle
--
-- The space at (q,r) must not be occupied by another organelle already.
--
-- @param q,r
-- Offset of the organelle's center relative to the microbe's center in
-- axial coordinates.
--
-- @param organelle
-- The organelle to add
function Microbe:addOrganelle(q, r, organelle)
    local s = encodeAxial(q, r)
    if self.microbe.organelles[s] then
        assert(false)
        return false
    end
    self.microbe.organelles[s] = organelle
    organelle.microbe = self
    local x, y = axialToCartesian(q, r)
    local translation = Vector3(x, y, 0)
    -- Collision shape
    self.rigidBody.properties.shape:addChildShape(
        translation,
        Quaternion(Radian(0), Vector3(1,0,0)),
        organelle.collisionShape
    )
    -- Scene node
    organelle.sceneNode.parent = self.entity
    organelle.sceneNode.transform.position = translation
    organelle.sceneNode.transform:touch()
    organelle:onAddedToMicrobe(self, q, r)
    self:_updateAllHexColours()
    self.microbe.maxBandwidth = self.microbe.maxBandwidth + BANDWIDTH_PER_ORGANELLE -- Temporary solution for increasing max bandwidth
    self.microbe.remainingBandwidth = self.microbe.maxBandwidth
    return true
end


-- Adds a storage organelle
-- This will be called automatically by storage organelles added with addOrganelle(...)
--
-- @param organelle
--   An object of type StorageOrganelle
function Microbe:addStorageOrganelle(storageOrganelle)
    assert(storageOrganelle.capacity ~= nil)
    
    self.microbe.capacity = self.microbe.capacity + storageOrganelle.capacity
    table.insert(self.microbe.storageOrganelles, storageOrganelle)
    return #self.microbe.storageOrganelles
end

-- Removes a storage organelle
--
-- @param organelle
--   An object of type StorageOrganelle
function Microbe:removeStorageOrganelle(storageOrganelle)
    self.microbe.capacity = self.microbe.capacity - storageOrganelle.capacity
    table.remove(self.microbe.storageOrganelles, storageOrganelle.parentId)
end

-- Adds a process organelle
-- This will be called automatically by process organelles added with addOrganelle(...)
--
-- @param processOrganelle
--   An object of type ProcessOrganelle
function Microbe:addProcessOrganelle(processOrganelle)
    table.insert(self.microbe.processOrganelles, processOrganelle)
end


-- Retrieves the organelle occupying a hex cell
--
-- @param q, r
-- Axial coordinates, relative to the microbe's center
--
-- @returns organelle
-- The organelle at (q,r) or nil if the hex is unoccupied
function Microbe:getOrganelleAt(q, r)
    for _, organelle in pairs(self.microbe.organelles) do
        local localQ = q - organelle.position.q
        local localR = r - organelle.position.r
        if organelle:getHex(localQ, localR) ~= nil then
            return organelle
        end
    end
    return nil
end


-- Removes the organelle at a hex cell
--
-- @param q, r
-- Axial coordinates of the organelle's center
--
-- @returns success
-- True if an organelle has been removed, false if there was no organelle
-- at (q,r)
function Microbe:removeOrganelle(q, r)
    local index = nil
    local s = encodeAxial(q, r)
    local organelle = table.remove(self.microbe.organelles, index)
    if not organelle then
        return false
    end
    organelle.position.q = 0
    organelle.position.r = 0
    organelle:onRemovedFromMicrobe(self)
    self:_updateAllHexColours()
    self.microbe.maxBandwidth = self.maxBandwidth - BANDWIDTH_PER_ORGANELLE -- Temporary solution for decreasing max bandwidth
    self.microbe.remainingBandwidth = self.maxBandwidth
    return true
end


-- Queries the currently stored amount of an compound
--
-- @param compoundId
-- The id of the compound to query
--
-- @returns amount
-- The amount stored in the microbe's storage oraganelles
function Microbe:getCompoundAmount(compoundId)
    if self.microbe.compounds[compoundId] == nil then
        return 0
    else
        return self.microbe.compounds[compoundId]
    end
end


-- Stores an compound in the microbe's storage organelles
--
-- @param compoundId
-- The compound to store
--
-- @param amount
-- The amount to store
--
-- @param bandwidthLimited
-- Determines if the storage operation is to be limited by the bandwidth of the microbe
function Microbe:storeCompound(compoundId, amount, bandwidthLimited)
    local storedAmount = 0
    if bandwidthLimited then
        storedAmount = math.min(self.microbe.remainingBandwidth, amount)
    else
        storedAmount = amount
    end
    if self.microbe.compounds[compoundId] == nil then
        self.microbe.compounds[compoundId] = 0
    end
    self.microbe.compounds[compoundId] = self.microbe.compounds[compoundId] + storedAmount
    self.microbe.remainingBandwidth = self.microbe.remainingBandwidth - storedAmount
    self.microbe.stored = self.microbe.stored + storedAmount
    local remainingAmount = amount - storedAmount
    self:_updateCompoundAbsorber()
    if remainingAmount > 0 then -- If there is excess compounds, we will eject them
        local particleCount = 1
        if remainingAmount >= 3 then
            particleCount = 3
        end
        local i
        for i = 1, particleCount do
            self:ejectCompound(compoundId, remainingAmount/particleCount)
        end
    end
end


-- Removes an compound from the microbe's storage organelles
--
-- @param compoundId
-- The compound to remove
--
-- @param maxAmount
-- The maximum amount to take
--
-- @returns amount
-- The amount that was actually taken, between 0.0 and maxAmount.
function Microbe:takeCompound(compoundId, maxAmount)
    if self.microbe.compounds[compoundId] == nil then
        return 0
    else
        local takenAmount = math.min(maxAmount, self.microbe.compounds[compoundId])
        self.microbe.compounds[compoundId] = self.microbe.compounds[compoundId] - takenAmount    
        self:_updateCompoundAbsorber()
        self.microbe.stored = self.microbe.stored - takenAmount
        return takenAmount
    end
end


-- Ejects compounds from the microbes behind position, into the enviroment
-- Note that the compounds ejected are created in this function and not taken from the microbe
--
-- @param compoundId
-- The compound type to create and eject
--
-- @param amount
-- The amount to eject
function Microbe:ejectCompound(compoundId, amount)
    local yAxis = self.sceneNode.transform.orientation:yAxis()
    local angle = math.atan2(-yAxis.x, -yAxis.y)
    if (angle < 0) then
        angle = angle + 2*math.pi
    end
    angle = angle * 180/math.pi
    local minAngle = angle - 30 -- over and underflow of angles are handled automatically
    local maxAngle = angle + 30
    self.compoundEmitter.minEmissionAngle = Degree(minAngle)
    self.compoundEmitter.maxEmissionAngle = Degree(maxAngle)
    self.compoundEmitter:emitCompound(compoundId, amount)
end




-- Updates the microbe's state
function Microbe:update(milliseconds)
    -- StorageOrganelles
   
    -- Regenerate bandwidth
    self.microbe.remainingBandwidth = math.min(self.microbe.remainingBandwidth + milliseconds * self.microbe.maxBandwidth / BANDWIDTH_REFILL_DURATION, self.microbe.maxBandwidth)
    -- Attempt to absorb queued compounds
    for compound in CompoundRegistry.getCompoundList() do
        -- Check for compounds to store
        local amount = self.compoundAbsorber:absorbedCompoundAmount(compound)
        if amount > 0.0 then
            self:storeCompound(compound, amount, true)
        end
    end
    
    -- Distribute compounds to Process Organelles
    self.gatheredDistributionTime = self.gatheredDistributionTime + milliseconds
    while self.gatheredDistributionTime > COMPOUND_PROCESS_DISTRIBUTION_INTERVAL do -- For every COMPOUND_DISTRIBUTION_INTERVAL passed
        for compound in CompoundRegistry.getCompoundList() do -- Foreach compound type.
            if self:getCompoundAmount(compound) > 0 then -- If microbe contains the compound
                local candidateIndices = {} -- Indices of organelles that want the compound
                for i, processOrg in ipairs(self.microbe.processOrganelles) do
                    if processOrg:wantsInputCompound(compound) then
                        table.insert(candidateIndices, i) -- Organelle has determined that it is interrested in obtaining the compound
                    end
                end
                if #candidateIndices > 0 then -- If there were any candidates, pick a random winner.
                    local chosenProcessOrg = self.microbe.processOrganelles[candidateIndices[rng:getInt(1,#candidateIndices)]]
                    chosenProcessOrg:storeCompound(compound, self:takeCompound(compound, 1))
                end
            end
        end
        self.gatheredDistributionTime = self.gatheredDistributionTime - COMPOUND_PROCESS_DISTRIBUTION_INTERVAL
    end
    
    self.microbe.compoundCollectionTimer = self.microbe.compoundCollectionTimer + milliseconds
    while self.microbe.compoundCollectionTimer > EXCESS_COMPOUND_COLLECTION_INTERVAL do -- For every COMPOUND_DISTRIBUTION_INTERVAL passed
        -- Temporary solution for priorities, should be replaced with a dynamic system
        local compoundPriorityTable = {}
        compoundPriorityTable[CompoundRegistry.getCompoundId("glucose")] = 5
        compoundPriorityTable[CompoundRegistry.getCompoundId("co2")] = 0
        compoundPriorityTable[CompoundRegistry.getCompoundId("oxygen")] = 6
        compoundPriorityTable[CompoundRegistry.getCompoundId("atp")] = 10
        -- Gather excess compounds that are the compounds that the storage organelles automatically emit to stay less than full
        local excessCompounds = {}
        while self.microbe.stored/self.microbe.capacity > STORAGE_EJECTION_THRESHHOLD+0.01 do
            -- Find lowest priority compound type contained in the microbe
            local lowestPriorityId = nil
            local lowestPriority = math.huge
            for compoundId,_ in pairs(self.microbe.compounds) do
                assert(compoundPriorityTable[compoundId] ~= nil, "Compound priority table was missing compound")
                if self.microbe.compounds[compoundId] > 0  and compoundPriorityTable[compoundId] < lowestPriority then
                    lowestPriority = compoundPriorityTable[compoundId]
                    lowestPriorityId = compoundId
                end
            end
            assert(lowestPriorityId ~= nil, "The microbe didn't seem to contain any compounds but was over the threshold")
            assert(self.microbe.compounds[lowestPriorityId] ~= nil, "Microbe storage was over threshold but didn't have any valid compounds to expell")
            -- Return an amount that either is how much the microbe contains of the compound or until it goes to the threshhold
            local amountInExcess
            
            amountInExcess = math.min(self.microbe.compounds[lowestPriorityId],self.microbe.stored - self.microbe.capacity * STORAGE_EJECTION_THRESHHOLD)
            excessCompounds[lowestPriorityId] = self:takeCompound(lowestPriorityId, amountInExcess)
        end
        -- Expell compounds of priority 0 periodically
        for compoundId,_ in pairs(self.microbe.compounds) do
            if compoundPriorityTable[compoundId] == 0 then
                local uselessCompoundAmount
                uselessCompoundAmount = math.min(self.microbe.compounds[compoundId], self.microbe.remainingBandwidth)
                self.microbe.remainingBandwidth = self.microbe.remainingBandwidth - uselessCompoundAmount
                if excessCompounds[compoundId] ~= nil then
                    excessCompounds[compoundId] = excessCompounds[compoundId] + self:takeCompound(compoundId, uselessCompoundAmount)
                else
                    excessCompounds[compoundId] = self:takeCompound(compoundId, uselessCompoundAmount)
                end
            end
        end 
        for compoundId, amount in pairs(excessCompounds) do
            if amount > 0 then
                self:ejectCompound(compoundId, amount)
            end
        end
        self.microbe.compoundCollectionTimer = self.microbe.compoundCollectionTimer - EXCESS_COMPOUND_COLLECTION_INTERVAL
    end
    -- Other organelles
    for _, organelle in pairs(self.microbe.organelles) do
        organelle:update(self, milliseconds)
    end
end


-- Private function for initializing a microbe's components
function Microbe:_initialize()
    self.rigidBody.properties.shape:clear()
    -- Organelles
    for s, organelle in pairs(self.microbe.organelles) do
        organelle.microbe = self
        local q = organelle.position.q
        local r = organelle.position.r
        local x, y = axialToCartesian(q, r)
        local translation = Vector3(x, y, 0)
        -- Collision shape
        self.rigidBody.properties.shape:addChildShape(
            translation,
            Quaternion(Radian(0), Vector3(1,0,0)),
            organelle.collisionShape
        )
        -- Scene node
        organelle.sceneNode.parent = self.entity
        organelle.sceneNode.transform.position = translation
        organelle.sceneNode.transform:touch()
        organelle:onAddedToMicrobe(self, q, r)
    end
    self:_updateAllHexColours()
    self.microbe.initialized = true
end


-- Private function for updating the compound absorber
--
-- Toggles the absorber on and off depending on the remaining storage
-- capacity of the storage organelles.
function Microbe:_updateCompoundAbsorber()
    --quick and dirty method
    if self.microbe.stored >= self.microbe.capacity then
        for compound in CompoundRegistry.getCompoundList() do
            self.compoundAbsorber:setCanAbsorbCompound(compound, false)
        end 
    else
        for compound in CompoundRegistry.getCompoundList() do
            self.compoundAbsorber:setCanAbsorbCompound(compound, true)
        end
    end
end


-- Private function for updating the colours of the organelles
--
-- The simple coloured hexes are a placeholder for proper models.
function Microbe:_updateAllHexColours()
    for s, organelle in pairs(self.microbe.organelles) do
        organelle:updateHexColours()
    end
end

function Microbe:getComponent(typeid)
    return self.entity:getComponent(typeid)
end

function Microbe:destroy()
    self.entity:destroy()
end

--------------------------------------------------------------------------------
-- MicrobeSystem
--
-- Updates microbes
--------------------------------------------------------------------------------

class 'MicrobeSystem' (System)

function MicrobeSystem:__init()
    System.__init(self)
    self.entities = EntityFilter(
        {
            CompoundAbsorberComponent,
            MicrobeComponent,
            OgreSceneNodeComponent,
            RigidBodyComponent,
            CollisionComponent
        },
        true
    )
    self.microbes = {}
end


function MicrobeSystem:init(gameState)
    System.init(self, gameState)
    self.entities:init(gameState)
end


function MicrobeSystem:shutdown()
    self.entities:shutdown()
end


function MicrobeSystem:update(milliseconds)
    for entityId in self.entities:removedEntities() do
        self.microbes[entityId] = nil
    end
    for entityId in self.entities:addedEntities() do
        local microbe = Microbe(Entity(entityId))
        self.microbes[entityId] = microbe
    end
    self.entities:clearChanges()
    for _, microbe in pairs(self.microbes) do
        microbe:update(milliseconds)
    end
end

