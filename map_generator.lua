--[[------------- KNOWN UNWANTED BEHAVIOURS ---------------]] 
-------------------------------------------------------------

-- Start an end can end up too close. Could be solved by storing all the rooms in a separate table and checking the distance between the farthest ones.
-- Rooms can sometimes overlap. Is probably connected to the drawing of the walls.
-- Rooms are placed randomly. When overlapping, they are discarded. This could result in some difference in the playtime of the levels.
-- Doors sometimes spawn randomly in rooms.
-- Connected rooms are not validated completely.
-- Height and width are sometimes flipped vs x and y, making some data extractions unnessecarily confusing. 
-- Minimum size of a level is around 30, 30. There is no validation for this on input, the program will just crash at 20 width, probably due to room placement outside of bounds.

--[[------------- DATA ------------------]] 
-------------------------------------------
-- Map data.
local mapData = {}
local maxHeight = 40
local maxWidth = 90
local roomsToSpawn = 20
local doorsPerRoom = 2

-- Tile placement algorithm data.
local doors = {}
local startTile = false
local endTile = false

-- Tile types, initialized to corresponding ASCII characters.
local tiles = {
	["empty"] = "-", 
	["wall"] = "=", 
	["path"] = "p", 
	["room"] = " ", 
	["door"] = "d", 
	["enemy"] = "x", 
	["border"] = "\n", 
	["exit"] = "e", 
	["start"] = "s", 
	["mid"] = "m",
} 

--[[------------- FUNCTIONS -------------]] 
-------------------------------------------

local function generateMapData(height, width, rooms, doors)
	maxHeight = height
	maxWidth = width
	roomsToSpawn = rooms
	doorsPerRoom = doors
end

-- Sets grid size and initializes all tiles to "empty".
local function initializeMap (t)
	for i = 1, maxHeight do
		t[i] = {}
		for j = 1, maxWidth do
			t[i][j] = { x = i, y = j, tile = tiles["empty"], isOccupied = false }
		end
	end
end

-- Generates an outer boundary around the map.
local function generateOutline (t)
	for i = 1, maxHeight do
		for j = 1, maxWidth do
			if i == 1 or i == maxHeight then 
				t[i][j].tile = tiles["wall"]
			end
			if j == 1 or j == maxWidth then 
				t[i][j].tile = tiles["wall"]
			end
		end
	end
end

-- Checks one tile outside x and y for every point of the room before it is placed. 
-- If a point is overlapped, the room is discarded.
local function roomsAreOverlapping(t, x, y, w, h)
	
	return  
	
	-- is top left point overlapping
	t[y - 1][x].tile == tiles["empty"] and
	t[y][x - 1].tile == tiles["empty"] and								
	
	-- is top right point overlapping
	t[y + 1][x + w].tile == tiles["empty"] and
	t[y][x + w + 1].tile == tiles["empty"] and						
	
	-- is bottom left point overlapping
	t[y + h + 1][x].tile == tiles["empty"] and
	t[y + h][x - 1].tile == tiles["empty"] and	

	-- is bottom right point  overlapping					
	t[y + h + 1][x + w].tile == tiles["empty"] and
	t[y + h][x + w + 1].tile == tiles["empty"]				
end

-- Spawns specified amount of rooms randomly on a grid without overlaps.
local function spawnRoom(d, t, amountOfDoors)
	local size_x = math.random(10, 15)
	local size_y = math.floor(size_x / 2)
	local offset_x = math.random(4, maxWidth - size_x - 4)
	local offset_y = math.random(4, maxHeight - size_y - 4)

	-- Checks if the next room placement overlaps with a previous one. 
	-- Discards room if the function returns true.
	if roomsAreOverlapping(t, offset_x, offset_y, size_x, size_y) then
		for i = 1, size_y do
			for j = 1, size_x do
				if i == 1 or i == size_y then 
					t[i + offset_y][j + offset_x].tile = tiles["wall"]
				elseif j == 1 or j == size_x then 
					t[i + offset_y][j + offset_x].tile = tiles["wall"]
				else 
					t[i + offset_y][j + offset_x].tile = tiles["room"]
				end
			end
		end

		--Should probably be rooms furthest froom eachothers centers, instead of random
	 	if startTile == false then
	 		startTile = true
	 		t[math.floor(offset_y + size_y / 2)][math.floor(offset_x + size_y / 2)].tile = tiles["start"]
	 	elseif endTile == false then
	 		t[math.floor(offset_y + size_y / 2)][math.floor(offset_x + size_y / 2)].tile = tiles["exit"]
	 		endTile = true;
	 	end
		
		-- Places amount of doors specified.
		-- Initializes a previous direction.
		local previous_dir = 0									
		-- Loops through and places amount of doors specified.
		for i = 1, amountOfDoors do 										
			-- Selects which side of the room the door should be placed at.
			local random_dir = math.random(4) 				
			
			-- Checks if several doors are placed on the same side.
			if random_dir == previous_dir then				
				return
			end		

			-- Door placement selector.
			local x = 1
			local y = 1
			if random_dir == 1 and random_dir then
				y = offset_y + math.random(2, size_y - 1)
				x = offset_x + 1
			elseif random_dir == 2 then 
				y = offset_y + math.random(2, size_y - 1)
				x = offset_x + size_x
			elseif random_dir == 3 then
				y = offset_y + 1
				x = offset_x + math.random(2, size_x - 1)
			else
				y = offset_y + size_y
				x = offset_x + math.random(2, size_x - 1)
			end

			-- Places a door at random position against one side of the room.
			t[y][x].tile = tiles["door"]								
			
			door = {x = x, y = y}
			table.insert(d, door)
		end
	else
		return
	end
end

-- Calculates heuristic cost for "A*""
local function calculateHeuristicCost(current, target)
    local xDist = current.x - target.x
    local yDist = current.y - target.y
	return math.abs(xDist) + math.abs(yDist)
end

-- Generates neighbours in 4 directions from current tile. Ignores tiles outside of grid.
local function generateNeighbours (parent)
	local right = { x = parent.x + 1, y = parent.y}
	local left = { x = parent.x - 1, y = parent.y}
	local up = { x = parent.x, y = parent.y + 1}
	local down = { x = parent.x, y = parent.y - 1}
	local neighbours = {right,left,up,down}
	local returnNeighbours =  {}
	for _, node in ipairs(neighbours) do
		if node.x > 1 and node.x < maxWidth and node.y > 1 and node.y < maxHeight then
				table.insert(returnNeighbours, node)
		end
	end

	return returnNeighbours
end

-- Finds node with lowest fScore
local function getLowestValueNode(openSet, fScore)
	local lowest = 1 / 0
	local bestNode = nil

	for _, node in ipairs (openSet) do
		local score = fScore[node.x + node.y * maxWidth]
		if score < lowest then
			 lowest, bestNode = score, node
		end  	
	end 
	return bestNode

end

-- Steps through path and places in table. Direction will be flipped, but it's arbitrary
local function getPath(node, cameFrom)
	local path = {}	
	local current = cameFrom[node]
	while current ~= nil do
		table.insert(path, current)
		current = cameFrom[current]
	end
	return path
end

-- Checks if table contains node 
local function doesNotContainNode(set, nodeToFind)
	for _, node in ipairs(set) do
		if node.x == nodeToFind.x and node.y == nodeToFind.y then
			return false
		end 
	end
	return true
end

-- Swaps node with last element and deletes last element
local function removeNode(set, nodeToRemove)
	for i, node in ipairs (set) do
		if node == nodeToRemove then
			set[i] = set[#set]
			set[#set] = nil
			return
		end	
	end 
end

-- Sort of A* function. Doesn't actually look for a specific target, but a door or a path tile. Still uses a heuristic for target node.
-- Gives a more interesting behavior than straight A*.
local function generatePath (t, startNode, targetNode)
	local openSet = { startNode }
	local closedSet = {}
	local cameFrom = {}
	local gScore = {}
	local fScore = {}

	-- Initial score values for startNode.
	gScore[startNode.x + startNode.y * maxWidth] = 0
	fScore[startNode.x + startNode.y * maxWidth] = gScore[startNode.x + startNode.y * maxWidth] + calculateHeuristicCost(startNode, targetNode)

	-- Evaluates tiles until a target is found or runs out of tiles.
	while #openSet > 0 do
		
		-- Finds tile with lowest value.
		local current = getLowestValueNode(openSet, fScore)
		
		-- Checks if tile matches specified target.
		rightType = t[current.y][current.x].tile == tiles["door"] or t[current.y][current.x].tile == tiles["path"] 
		if rightType and current.x ~= startNode.x and current.y ~= startNode.y then
			return getPath(current, cameFrom)
		end
		-- Sets tile as evaluated and moves it over to the closedSet.
		removeNode(openSet, current)
		table.insert(closedSet, current)

		-- Gets and iterates over all neighbouring tiles.
		local neighbours = generateNeighbours(current)

		for _, neighbour in ipairs (neighbours) do
			-- Validates tile.
			if t[neighbour.y][neighbour.x].tile == tiles["empty"] or 
				t[neighbour.y][neighbour.x].tile == tiles["door"] or 
				t[neighbour.y][neighbour.x].tile == tiles["path"] then
				
				-- Tile has not already been evaluated.
				if doesNotContainNode(closedSet, neighbour) then
					local tentativeScore = gScore[current.x + current.y * maxWidth] + 1
					
					-- Checks if tile is newly discovered or has a lower score than previously discovered path to tile.
					newlyDiscoverdTile = doesNotContainNode(openSet, neighbour)
					if newlyDiscoverdTile or tentativeScore < gScore[neighbour.x + neighbour.y * maxWidth]  then
						cameFrom[neighbour] = current
						gScore[neighbour.x + neighbour.y * maxWidth] = tentativeScore
						fScore[neighbour.x + neighbour.y * maxWidth] = tentativeScore + calculateHeuristicCost(neighbour, targetNode)

						-- Adds tile to be evaluated if it hasn't been already.
						if newlyDiscoverdTile then
							table.insert(openSet, neighbour)
						end
					end
				end
			end
		end
	end

	return nil
end

-- Compiles all the map data into a string and outputs it to the console.
-- Could also be saved to a seed and be stored in external table.
local function drawMap (t)
	local map = ""
	local currentIndex = 1

	for i = 1, maxHeight do
		for j = 1, maxWidth do
		if i>currentIndex then 
				map = map..tiles["border"]
				currentIndex = currentIndex + 1
			end
			local current_h = tostring(t[i][j].tile)
			map = map..current_h	
		end
	end
	return map
end

-- Main function. 
-- Generates a map and populates it with rooms, doors, corridors, start and exit.
local function populateMap(t, roomsToSpawn, doorsPerRoom)
	initializeMap(t)

	-- Spawns specified amount of rooms.
	for i = 1, roomsToSpawn do
		spawnRoom(doors, t, doorsPerRoom)
	end

	-- Generates a wall around the map.
	generateOutline(t)

	-- Gets paths between doors.
	paths = {}
	for i=1, #doors do
		local doorPos = {x = doors[i].x, y = doors[i].y}
		local index = math.fmod(i+1, #doors) + 1
		local targetDoorPos = {x = doors[index].x, y = doors[index].y}
		local path = generatePath(t, doorPos, targetDoorPos)
		if path ~= nil then
			table.insert(paths, path)
		end
	end

	-- Adds paths to provided table for drawing.
	for _, path in ipairs(paths) do
		for _, pos in ipairs(path) do
			t[pos.y][pos.x].tile = tiles["path"]
		end
	end

	-- Redraws doors that had been covered by paths.
	for _, door in ipairs(doors) do
			t[door.y][door.x].tile = tiles["door"]
	end
end

--[[------------- PROGRAM ---------------]] 
-------------------------------------------
-- Initializes a random seed for use of the math.random functions.
math.randomseed(os.time())										

-- Map data to be provided by the user.
generateMapData(40, 90, 20, 2)
populateMap(mapData, roomsToSpawn, doorsPerRoom)

-- Generic console drawing for this specific task.
io.write(drawMap(mapData))

-- Pause execution after drawing.
io.read()
