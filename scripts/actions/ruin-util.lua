require "/scripts/util.lua"
require "/scripts/behavior/bdata.lua"

function _anyTypeTable(value)
  results = {}
  for _, dataType in pairs(ListTypes) do
    results[dataType] = value
  end
  return results
end

-- param list list
-- output AnyType value

function randomFromList(args, board)
  if args.list == nil or next(args.list) == nil then return false end
  return true, _anyTypeTable(util.randomFromList(args.list))
end