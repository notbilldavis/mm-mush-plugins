function getTableIndex(t, item)
  res = nil

  for i = 1, #t do
    if (string.lower(t[i]) == string.lower(item)) then
      res = i
      break
    end
  end

  return res
end

function addToTable(t, item)
  local i = getTableIndex(t, item)
  if (not i) then
    t[#t + 1] = item
    table.sort(t)
  end
end

function removeFromTable(t, item)
  local i = getTableIndex(t, item)
  if (i) then
    table.remove(t, i)
  end
end

function getTableIndexForContains(t, item)
  res = nil

  for i = 1, #t do
    if (string.find(string.lower(t[i]), string.lower(item), 1, true) ~= nil) then
      res = i
      break
    end
  end

  return res
end

function moveEntry(t, fromIndex, toIndex)
    if fromIndex == toIndex or fromIndex < 1 or toIndex < 1 or
       fromIndex > #t or toIndex > #t then
        return -- Do nothing if invalid indices
    end

    local value = t[fromIndex]

    if fromIndex < toIndex then
        -- Shift elements left from fromIndex+1 to toIndex
        for i = fromIndex, toIndex - 1 do
            t[i] = t[i + 1]
        end
    else
        -- Shift elements right from fromIndex-1 down to toIndex
        for i = fromIndex, toIndex + 1, -1 do
            t[i] = t[i - 1]
        end
    end

    t[toIndex] = value
end