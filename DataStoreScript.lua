---- SERVICES ----
local playerService = game:GetService("Players")
local dataStoreService = game:GetService("DataStoreService")
local runService = game:GetService("RunService")
local marketplaceService = game:GetService("MarketplaceService")
local serverScriptService = game:GetService("ServerScriptService")
local textChatService = game:GetService("TextChatService")

---- VARIABLES ----

local playerDatabase = dataStoreService:GetDataStore("_playerData")
local defaultData = {
	SessionLock = false,
	GameData = {
		Cash = 0,
		Gems = 0,
	},
}

local updateAsync = Enum.DataStoreRequestType.UpdateAsync

local productId = 1747730658
local passId = 705221101

local productFunctions = {
	[1747730658] = function(player:Player)
		local leaderstats = player:FindFirstChild("leaderstats")
		local gems:IntValue = leaderstats:FindFirstChild("Gems")
		gems.Value += 50
	end,
}

local passFunctions = {
	[705221101] = function(player:Player)
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash:IntValue = leaderstats:FindFirstChild("Cash")
		local gems:IntValue = leaderstats:FindFirstChild("Gems")
		cash.Value += 100
		gems.Value += 100
	end,
}

---- FUNCTIONS ----
---- String function, splits the given string and returns the desired word within the string. ----
local function getSplitMsg(message:string, number:number)
	local splitStrings = string.split(message, " ")
	if number > #splitStrings then
		error("Error: could not retrieve split string from message. Have you included the second argument?")
	end
	return splitStrings[number]
end

---- Chat command functions ----
local function giveCashCmd(textSource, message)
	print(message)
	local userId = textSource.UserId
	local player = playerService:GetPlayerByUserId(userId)
	if player then
		local amount = tonumber(getSplitMsg(message, 2))
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats:FindFirstChild("Cash")
		if amount and amount > 100 then
			warn("Amount must not be greater than 100.")
		else
			cash.Value += amount
			print(amount, "cash has been given to player")
		end
	else
		warn("Error: Player could not be found")
	end
end

local function giveGemsCmd(textSource, message)
	print(message)
	local userId = textSource.UserId
	local player = playerService:GetPlayerByUserId(userId)
	if player then
		local amount = tonumber(getSplitMsg(message, 2))
		local leaderstats = player:FindFirstChild("leaderstats")
		local gems = leaderstats:FindFirstChild("Gems")
		if amount and amount > 100 then
			warn("Amount must not be greater than 100.")
		else
			gems.Value += amount
			print(amount, "gems has been given to player")
		end
	else
		warn("Error: Player could not be found")
	end
end

local function promptProductCmd(textSource, message)
	local userId = textSource.UserId
	local player = playerService:GetPlayerByUserId(userId)
	if player then
		marketplaceService:PromptProductPurchase(player, productId)
	else
		warn("Error: Player could not be found")
	end
end

local function promptPassCmd(textSource, message)
	local userId = textSource.UserId
	local player = playerService:GetPlayerByUserId(userId)
	if player then
		marketplaceService:PromptGamePassPurchase(player, passId)
	else
		warn("Error: Player could not be found")
	end
end

---- Developer product functions ----
local function productPromptFinished(userId, productId, wasPurchased)
	local playerName = playerService:GetNameFromUserIdAsync(userId)
	local productInfo = marketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	if wasPurchased then
		--Show player's purchase in output
		print("Player " .. playerName .. " has purchased the developer product: " .. productInfo.Name)
	else
		print("Player " .. playerName .. " has ignored the developer product purchase prompt for " .. productInfo.Name)
	end
end

local function passPromptFinished(player, passId, wasPurchased)
	local playerName = player.Name
	local passInfo = marketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	if wasPurchased then
		--Show player's purchase in output
		print("Player " .. playerName .. " has purchased the game pass: " .. passInfo.Name)
	else
		print("Player " .. playerName .. " has ignored the game pass purchase prompt for " .. passInfo.Name)
	end
end

local function processReceipt(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	
	print(receiptInfo)
	local player = playerService:GetPlayerByUserId(playerId)
	if not player then --player may have left game, will run callback again when player rejoins
		return Enum.ProductPurchaseDecision.NotProcessedYet
	else
		local success, result = pcall(productFunctions[productId], player)
		if success then
			print("Purchase has been made successfully")
		else
			warn("Error: Purchase could not be handled, reason:"..result)
		end
	end
	
	return Enum.ProductPurchaseDecision.PurchaseGranted
end


--Waits for request budget, use before doing UpdateAsync pcall
local function waitForRequestBudget()
	local requestBudget = dataStoreService:GetRequestBudgetForRequestType(updateAsync)
	while requestBudget < 1 do
		requestBudget = dataStoreService:GetRequestBudgetForRequestType(updateAsync)
		task.wait(5)
	end
end

--Sets up data for player, also checks for session lock
local function setUp(player)
	
	local name = player.Name
	local userId = player.UserId
	local key = "Player_"..userId
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local cash = Instance.new("IntValue", leaderstats)
	cash.Name = "Cash"
	
	local gems = Instance.new("IntValue", leaderstats)
	gems.Name = "Gems"
	
	local success, data, waitForSession
	
	repeat --will repeat until pcall is success and data is received, or if player leaves the game
		waitForRequestBudget() --get request budget
		success = pcall(playerDatabase.UpdateAsync, playerDatabase, key, function(oldData)
			print(oldData)
			oldData = oldData or defaultData
			
			if oldData.SessionLock then
				if os.time() - oldData.SessionLock < 1 then --checks if it's been 30 minutes since session started then
					warn("Old session still ongoing, time until session expires:", 1800 - (os.time()- oldData.SessionLock))
					waitForSession = true
				else
					oldData.SessionLock = os.time() --old session has died, make new session
					data = oldData
					return data
				end
			else
				oldData.SessionLock = os.time() --session isnt found, make new session
				data = oldData
				return data
			end
		end)
		
		if waitForSession then
			task.wait(5)
			waitForSession = false
		end
	until (success and data) or not playerService:FindFirstChild(name)
	
	if success and data then
		cash.Value = data.GameData.Cash
		gems.Value = data.GameData.Gems
		
		leaderstats.Parent = player
		
		if marketplaceService:PlayerOwnsAsset(player, passId) then
			passFunctions[passId](player)
		end
		
		print("Player data has successfuly loaded")
	end
end

--Save function for player
local function save(player, notLeaving, dontWait)
	local userId = player.UserId
	local key = "Player_"..userId
	
	local leaderstats = player:FindFirstChild("leaderstats")
	
	if leaderstats then
		local cashValue = leaderstats.Cash.Value
		local gemsValue = leaderstats.Gems.Value
		
		local success
		
		repeat
			if not dontWait then
				waitForRequestBudget()
			end
			success = pcall(playerDatabase.UpdateAsync, playerDatabase, key, function(oldData)
				
				return {
					SessionLock = notLeaving and os.time() or nil,
					GameData = {
						Cash = cashValue,
						Gems = gemsValue
					},
				}
			end)
		until success
		print("Game has successfully saved player data for " .. player.Name)
	end
end

--Performs function right before server shut downs
local function onShutdown()
	if runService:IsStudio() then
		task.wait(2)
	else
		local finished = Instance.new("BindableEvent")
		local allPlayers = playerService:GetPlayers()
		local leftPlayers = #allPlayers

		for _,player in ipairs(allPlayers) do --iterates through player list
			coroutine.wrap(function() --you dont need to worry about request budget, the getRequestBudget function is already within the save function
				save(player, nil, true)
				leftPlayers -= 1
				if leftPlayers == 0 then
					finished:Fire()
				end
			end)
		end

		finished.Event:Wait() --once finished event is fired, wait so that the game has enough time to save everyone's data
	end
end


---- CONNECTIONS AND CALLBACKS ----
textChatService.Commands.GiveCash.Triggered:Connect(giveCashCmd)
textChatService.Commands.GiveGems.Triggered:Connect(giveGemsCmd)
textChatService.Commands.PromptProduct.Triggered:Connect(promptProductCmd)
textChatService.Commands.PromptPass.Triggered:Connect(promptPassCmd)

marketplaceService.ProcessReceipt = processReceipt
marketplaceService.PromptProductPurchaseFinished:Connect(productPromptFinished)
marketplaceService.PromptGamePassPurchaseFinished:Connect(passPromptFinished)

playerService.PlayerAdded:Connect(setUp)
playerService.PlayerRemoving:Connect(save)
game:BindToClose(onShutdown)

---- LOOPS ----

--Autosave feature, every minute, iterates save function for each player
while true do
	task.wait(60)
	for _,player in ipairs(playerService:GetPlayers()) do
		coroutine.wrap(save)(player, true)
	end
end
