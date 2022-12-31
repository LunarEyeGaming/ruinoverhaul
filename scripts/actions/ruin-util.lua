require "/scripts/util.lua"
require "/scripts/behavior/bdata.lua"

--[[
  Returns a table containing the given value in each behavior tree data type.
  value: The value to use
]]
function _ruin_anyTypeTable(value)
  results = {}
  for _, dataType in pairs(ListTypes) do
    results[dataType] = value
  end
  return results
end

--[[
  Returns a random element from a list.
  param list
  output value
]]
function ruin_randomFromList(args, board)
  if args.list == nil or next(args.list) == nil then return false end
  return true, _ruin_anyTypeTable(util.randomFromList(args.list))
end