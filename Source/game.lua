-- levels always have 2 rings per pick, and optionally random picks 
local DIFFICULTY_LEVEL <const> = {
    [0] = {
        -- novice
        rings=2,
        randomPicks={count=0},
        pick={2,2,2,3} -- pick size distribution
    },
    [1] = {
        -- advanced
        rings=2,
        randomPicks={count=2,sizes={2,3}},
        pick={2,2,2,3,3,4}
    },
    [2] = {
        -- expert
        rings=3,
        randomPicks={count=3,sizes={1,2,2,3,3}},
        pick={1,2,3,4}
    },
    [3] = {
        -- master
        rings=4,
        randomPicks={count=4,sizes={1,2,2,2,3,3,3}},
        pick={1,2,3,4}
    },
}

-- keep generated picks in order and not rotate them
local CHEATING <const> = false

---Converts a list of bits to a 32-bit integer
---@param bits integer[] set bits, LSB is 0
---@return integer # 32-bit value
function bitsToValue(bits)
  local value = 0
  for _, bit in ipairs(bits) do
    value = value | (1 << bit)
  end
  return value
end

---Return a list of bits set in a 32-bit integer
---@param value integer 32 bit integer
---@return integer[] # set bits
function valueToBits(value)
  local bits = {}
  for bit = 0, 31 do
    if value & (1 << bit) ~= 0 then
      table.insert(bits, bit)
    end
  end
  return bits
end

---Check if a ring fits a pick
---@param ring integer
---@param pick integer[]
---@return boolean
function fitTest(ring, pick)
  local pickValue = bitsToValue(pick)
  if pickValue == 0 then
    return false
  end
  local holes = ~ring
  local filled = pickValue & holes
  return filled == pickValue
end

---Rotates a pick
---@param pick integer[]
---@param by integer
---@return integer[]
function offsetPick(pick, by)
  local newPick = {}
  for i=1,#pick do
    newPick[i] = (pick[i] + by) % 32
  end
  return newPick
end

---Generates a new pick for a ring.
---@param size integer number of bits of the pick
---@param ring integer current value of the ring (32-bit integer)
---@return integer[]
local function makePick(size, ring)
  local pick = {}
  while #pick < size do
    local availableBits = valueToBits(ring & 0x55555555)
    local newBit = availableBits[math.random(#availableBits)]
    table.insert(pick, newBit)
  end
  return pick
end

---Shuffles the elements in a table
---@param t table
local function shuffle(t)
  local nt = {}
  while #t > 0 do
    table.insert(nt, table.remove(t))
  end
  while #nt > 0 do
    table.insert(t, table.remove(nt, math.random(#nt)))
  end
end

function createLevel(difficulty)
  local rings = {}
  local picks = {}

  -- create initial rings
  local setup = DIFFICULTY_LEVEL[difficulty]
  while #rings < setup.rings do
    table.insert(rings, 0xffffffff)
  end

  -- set up picks
  for r = 1, setup.rings do
    -- 2 picks per ring
    for p = 1, 2 do
      -- choose size of pick
      local pickSize = setup.pick[math.random(#setup.pick)]
      -- if last size was 1, choose a different one
      if difficulty >= 2 and pickSize == 1 and #picks > 0 and #picks[#picks] == 1 then
        pickSize = math.random(2, 3)
      end

      local pick = makePick(pickSize, rings[r])
      rings[r] = rings[r] ~ bitsToValue(pick)
      -- randomly rotate pick
      if CHEATING then
        table.insert(picks, pick)
      else
        table.insert(picks, offsetPick(pick, math.random(32)))
      end
    end
  end

  -- add random picks
  for p = 1, setup.randomPicks.count do
    local pickSize = setup.randomPicks.sizes[math.random(#setup.randomPicks.sizes)]
    local pick = makePick(pickSize, 0xffffffff)
    table.insert(picks, pick)
  end

  if not CHEATING then
    shuffle(picks)
  end

  return picks, rings
end