local repo="https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library=loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager=loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))()
local SaveManager=loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "flopsaken",
    Footer = "now made for forsaken sandbox and more!",
    Center = true,
    AutoShow = true,
    ToggleKeybind = Enum.KeyCode.RightControl
})

local RoleTab = Window:AddTab({ Name = "Role", Icon = "user" })
local StaminaTab = Window:AddTab({ Name = "Stamina", Icon = "zap" })
local AutoBlockTab = Window:AddTab({ Name = "Autoblock", Icon = "shield" })
local BackstabTab = Window:AddTab({ Name = "AutoBackstab", Icon = "swords" })
local VisualTab = Window:AddTab({ Name = "Visuals", Icon = "eye" })
local AntiTab = Window:AddTab({ Name = "Anti", Icon = "ban" })
local OtherTab = Window:AddTab({ Name = "Other", Icon = "settings" })
local ConfigTab = Window:AddTab({ Name = "Config", Icon = "folder" })

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:ApplyToTab(ConfigTab)
SaveManager:BuildConfigSection(ConfigTab)
Library.ForceCheckbox=true

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local lp=Players.LocalPlayer
local PlayerGui=lp:WaitForChild("PlayerGui")
local PathfindingService = game:GetService("PathfindingService")
local httpService = game:GetService("HttpService")
local localPlayer = Players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local Network = replicatedStorage:WaitForChild("Modules"):WaitForChild("Network")
local gameMap = workspace.Map
local isSurvivor
local isKiller
local killerModel

do
    local voidrushcontrol = false

    local function setupCharacter(character)
        if not character then return end
        local Humanoid = character:FindFirstChild("Humanoid")
        local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if Humanoid and HumanoidRootPart then
            _G.Humanoid = Humanoid
            _G.HumanoidRootPart = HumanoidRootPart
        end
    end

    if lp.Character then setupCharacter(lp.Character) end
    lp.CharacterAdded:Connect(setupCharacter)

    local ORIGINAL_DASH_SPEED = 55
    local isOverrideActive = false
    local connection

    local function startOverride()
        if isOverrideActive then return end
        isOverrideActive = true
        connection = RunService.RenderStepped:Connect(function()
            local humanoid = _G.Humanoid
            local rootPart = _G.HumanoidRootPart
            if not humanoid or not rootPart then return end
            humanoid.WalkSpeed = ORIGINAL_DASH_SPEED
            humanoid.AutoRotate = false
            local direction = rootPart.CFrame.LookVector
            local horizontal = Vector3.new(direction.X, 0, direction.Z)
            if horizontal.Magnitude > 0 then
                humanoid:Move(horizontal.Unit)
            end
        end)
    end

    local function stopOverride()
        if not isOverrideActive then return end
        isOverrideActive = false
        local humanoid = _G.Humanoid
        if humanoid then
            humanoid.WalkSpeed = 18
            humanoid.AutoRotate = true
            humanoid:Move(Vector3.new(0, 0, 0))
        end
        if connection then connection:Disconnect() connection = nil end
    end

    RunService.RenderStepped:Connect(function()
        if not voidrushcontrol then return end
        local char = _G.Humanoid and _G.Humanoid.Parent
        local voidRushState = char and char:GetAttribute("VoidRushState")
        if voidRushState == "Dashing" then
            startOverride()
        else
            stopOverride()
        end
    end)
    local NoliGroup = RoleTab:AddLeftGroupbox("Noli")
    NoliGroup:AddToggle("VoidrushControl", {
        Text = "Voidrush Controllable",
        Default = false,
        Callback = function(v)
            voidrushcontrol = v
        end
    })
end

do
    local player = Players.LocalPlayer
    local device = "Mobile"

    local function getBehaviorFolder()
        return ReplicatedStorage:WaitForChild("Assets")
            :WaitForChild("Survivors")
            :WaitForChild("Veeronica")
            :WaitForChild("Behavior")
    end

    local function getSprintingButton()
        return player.PlayerGui:WaitForChild("MainUI"):WaitForChild("SprintingButton")
    end

    local behaviorFolder = getBehaviorFolder()

    local function safeConnectPropertyChanged(instance, prop, fn)
        local ok, signal = pcall(function() return instance:GetPropertyChangedSignal(prop) end)
        if ok and signal then return signal:Connect(fn) end
        return nil
    end

    local enabled = false
    local activeMonitors = {}
    local descendantAddedConn = nil

    local function monitorHighlight(h)
        if not h or activeMonitors[h] then return end

        local connections = {}
        local prevState = false

        local function cleanup()
            for _, conn in ipairs(connections) do
                if conn and conn.Connected then conn:Disconnect() end
            end
            activeMonitors[h] = nil
        end

        local function adorneeIsPlayerCharacter()
            local adornee = h.Adornee
            local char = player.Character
            if not adornee or not char then return false end
            return adornee == char or adornee:IsDescendantOf(char)
        end

        local function onChanged()
            if not enabled then return end
            if not h or not h.Parent then cleanup() return end

            local currState = adorneeIsPlayerCharacter()
            if prevState ~= currState and currState then
                if device == "Mobile" then
                    local ok, btn = pcall(getSprintingButton)
                    if ok and btn then
                        for _, v in pairs(getconnections(btn.MouseButton1Down)) do
                            pcall(v.Fire, v)
                        end
                    end
                end
            end
            prevState = currState
        end

        local c = safeConnectPropertyChanged(h, "Adornee", onChanged)
        if c then table.insert(connections, c) end

        table.insert(connections, h.AncestryChanged:Connect(function(_, parent)
            if not parent then cleanup() else onChanged() end
        end))

        table.insert(connections, player.CharacterAdded:Connect(onChanged))
        table.insert(connections, player.CharacterRemoving:Connect(onChanged))

        activeMonitors[h] = cleanup
        task.spawn(onChanged)
    end

    local function startManager()
        if descendantAddedConn then return end
        for _, desc in ipairs(behaviorFolder:GetDescendants()) do
            if desc:IsA("Highlight") then monitorHighlight(desc) end
        end
        descendantAddedConn = behaviorFolder.DescendantAdded:Connect(function(child)
            if child:IsA("Highlight") then monitorHighlight(child) end
        end)
    end

    local function stopManager()
        if descendantAddedConn and descendantAddedConn.Connected then
            descendantAddedConn:Disconnect()
        end
        descendantAddedConn = nil
        for _, cleanup in pairs(activeMonitors) do pcall(cleanup) end
        activeMonitors = {}
    end

    local function setEnabled(v)
        if enabled == v then return end
        enabled = v
        if enabled then startManager() else stopManager() end
    end
    local VerronicaGroup = RoleTab:AddRightGroupbox("Veeronica")
    VerronicaGroup:AddToggle("AutoTrick", {
        Text = "Auto Trick",
        Default = false,
        Callback = function(v)
            setEnabled(v)
        end
    })
end

local autoBlockTriggerSounds = {
["88609253286783"]=true,["121433785000497"]=true,["90821385958954"]=true,["117441203118962"]=true,
["80806679751288"]=true,["114281779710684"]=true,["108779919920137"]=true,["99524481904334"]=true,
["94030859065596"]=true,["110521131601724"]=true,["110521131601724"]=true,["70799679558553"]=true,
["77505612298116"]=true,["113651709982310"]=true,["115340562700238"]=true,["128750110272163"]=true,
["93816657895411"]=true,["126955046721348"]=true,["115341290575575"]=true,["128344992001306"]=true,
["137046881887759"]=true,["82559525726219"]=true,["71261962248869"]=true,["82879404709627"]=true,
["124005260284980"]=true,["114742322778642"]=true,["119583605486352"]=true,["79980897195554"]=true,
["71805956520207"]=true,["79391273191671"]=true,["89004992452376"]=true,["101553872555606"]=true,
["101698569375359"]=true,["106300477136129"]=true,["116581754553533"]=true,["117231507259853"]=true,
["119089145505438"]=true,["121954639447247"]=true,["111372126229539"]=true,["109917667524290"]=true
}


local autoBlockTriggerAnims = {
["76718907771547"]=true, ["79993230317474"]=true, ["76893161450284"]=true,
["116143734489482"]=true, ["87148236889657"]=true, ["75750952395724"]=true,
["86210399276997"]=true, ["93760621619834"]=true, ["98459518844037"]=true,
["82113744478546"]=true, ["70371667919898"]=true, ["99135633258223"]=true,
["128854816792231"]=true, ["109230267448394"]=true, ["139835501033932"]=true,
["126896426760253"]=true, ["109667959938617"]=true, ["126681776859538"]=true,
["129976080405072"]=true, ["138355968678501"]=true, ["81639435858902"]=true,
["137314737492715"]=true, ["92173139187970"]=true, ["105102953527729"]=true,
["879895330952"]=true,

["131430497821198"]=true, ["85730700349434"]=true, ["18885919947"]=true,  
["87259391926321"]=true, ["106014898528300"]=true, ["104633736983646"]=true,  
["89448354637442"]=true, ["134910205278125"]=true, ["94829505101254"]=true,  
["106086955212611"]=true, ["107640065977686"]=true, ["77124578197357"]=true,  
["124981994583326"]=true, ["134958187822107"]=true, ["111313169447787"]=true,  
["71685573690338"]=true, ["129843313690921"]=true, ["108019063386815"]=true,  
["137177777200593"]=true, ["86096387000557"]=true, ["108807732150251"]=true,  
["115545052973987"]=true, ["111420552802912"]=true, ["86709774283672"]=true,  
["140703210927645"]=true, ["96173857867228"]=true, ["121255898612475"]=true,  
["98031287364865"]=true, ["119462383658044"]=true, ["77448521277146"]=true,  
["103741352379819"]=true, ["131696603025265"]=true, ["122503338277352"]=true,  
["97648548303678"]=true, ["85070787013540"]=true, ["84426150435898"]=true,  
["93069721274110"]=true, ["114620047310688"]=true, ["97433060861952"]=true,  
["82183356141401"]=true, ["100592913030351"]=true, ["116875978795421"]=true,  
["106847695270773"]=true, ["115698939556919"]=true, ["74707328554358"]=true,  
["133336594357903"]=true, ["86204001129974"]=true, ["124243639579224"]=true,  
["131543461321709"]=true, ["132156034062684"]=true
}
local autoBlockOn = false
local autoBlockAudioOn = false
local detectionRange = 12
local facingCheckEnabled = false
local customFacingDot = -0.3
local blockdelay = 0
local autoPunch = false
local aimPunch = false
local aimPrediction = 4
local backstab = false
local backstabRange = 8
local backstabMode = "Around"
local visualEnabled = false
local showKiller = false
local showSurvivor = false
local showItems = false
local showGen = false
local jumpEnabled = false
local undetectedMode = false
local backdis = 1.8

local LeftAB = AutoBlockTab:AddLeftGroupbox("Auto Block")
local RightAB = AutoBlockTab:AddRightGroupbox("Autopunch")

LeftAB:AddToggle("AutoBlockAnim", {Text = "Auto Block (Animation)", Default = false, Callback = function(v) autoBlockOn = v end})
LeftAB:AddToggle("AutoBlockAudio", {Text = "Auto Block (Audio)", Default = false, Callback = function(v) autoBlockAudioOn = v end})
LeftAB:AddInput("DetectionRange", {Text = "Detection Range", Default = "12", Numeric = true, Callback = function(t) detectionRange = tonumber(t) or detectionRange end})
LeftAB:AddToggle("FacingCheck", {Text = "Enable Facing Check", Default = true, Callback = function(v) facingCheckEnabled = v end})
LeftAB:AddInput("FacingDot", {Text = "Facing Check DOT", Default = "-0.3", Numeric = true, Callback = function(t) customFacingDot = tonumber(t) or customFacingDot end})
LeftAB:AddInput("BlockDelay", {Text = "Block Delay (seconds)", Default = "0", Numeric = true, Callback = function(t) blockdelay = tonumber(t) or blockdelay end})

RightAB:AddToggle("Autopunch", {Text = "Autopunch", Default = false, Callback = function(v) autoPunch = v end})
RightAB:AddToggle("Aimpunch", {Text = "Aimpunch", Default = false, Callback = function(v) aimPunch = v end})
RightAB:AddSlider("Prediction", {Text = "Prediction", Min = 0, Max = 10, Default = 4, Increment = 0.1, Suffix = " studs", Callback = function(v) aimPrediction = v end})

local LeftBS = BackstabTab:AddLeftGroupbox("Auto Backstab")
LeftBS:AddToggle("AutoBackstab", {Text = "AutoBackstab", Default = false, Callback = function(v) backstab = v end})
LeftBS:AddInput("BackstabRange", {Text = "Range", Default = "8", Numeric = true, Callback = function(t) backstabRange = tonumber(t) or backstabRange end})
LeftBS:AddDropdown("BackstabMode", {Text = "Mode", Default = "Around", Values = {"Behind", "Around"}, Callback = function(v) backstabMode = v end})
LeftBS:AddInput("Backdis", {
    Text = "Backdis",
    Default = "1.8",
    Numeric = true,
    PlaceholderText = "0.5 - 5",
    Callback = function(text)
        local num = tonumber(text)
        if num and num >= 0.5 and num <= 5 then
            backdis = num
        else
            backdis = 1.8
            Library:Notify("Backdis must be between 0.5 and 5!", 3)
        end
    end
})

local LeftVis = VisualTab:AddLeftGroupbox("ESP Settings")
LeftVis:AddToggle("Highlight", {Text = "Highlight", Default = false, Callback = function(v) visualEnabled = v end})
LeftVis:AddToggle("Killer", {Text = "Killer", Default = false, Callback = function(v) showKiller = v end})
LeftVis:AddToggle("Survivor", {Text = "Survivor", Default = false, Callback = function(v) showSurvivor = v end})
LeftVis:AddToggle("Generator", {Text = "Generator", Default = false, Callback = function(v) showGen = v end})
LeftVis:AddToggle("Items", {Text = "Medkit & BloxyCola", Default = false, Callback = function(v) showItems = v end})

local LeftOther = OtherTab:AddLeftGroupbox("Misc")
LeftOther:AddToggle("Jump", {Text = "Jump", Default = false, Callback = function(v) jumpEnabled = v end})

LeftOther:AddToggle("AutoGen", {Text = "Auto gen", Default = true, Callback = function(v) autoGen = v end})
LeftOther:AddInput("GenSpeed", {
    Text = "Gen Speed",
    Default = "0.05",
    Numeric = true,
    PlaceholderText = "0.01 - 0.5",
    Callback = function(text)
        local num = tonumber(text)
        if num and num >= 0.01 and num <= 0.5 then
            autoGenSpeed = num
        else
            autoGenSpeed = 0.05
        end
    end
})
LeftOther:AddToggle("Undetected", {Text = "Undetected Mode", Default = false, Callback = function(v) undetectedMode = v end})
LeftOther:AddToggle("HakariDance", {
    Text = "Hakari Dance",
    Default = false,
    Callback = function(state)
        local char = lp.Character or lp.CharacterAdded:Wait()
        local humanoid = char:WaitForChild("Humanoid")
        local rootPart = char:WaitForChild("HumanoidRootPart")

        if state then
            Library:Notify("Hakari Dance activated!", 5)
            humanoid.PlatformStand = true
            humanoid.JumpPower = 0

            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
            bodyVelocity.Velocity = Vector3.zero
            bodyVelocity.Parent = rootPart

            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://138019937280193"
            local animationTrack = humanoid:LoadAnimation(animation)
            animationTrack:Play()

            local sound = Instance.new("Sound")
            sound.SoundId = "rbxassetid://87166578676888"
            sound.Parent = rootPart
            sound.Volume = 0.5
            sound.Looped = true
            sound:Play()

            local effect = ReplicatedStorage.Assets.Emotes.HakariDance.HakariBeamEffect:Clone()
            effect.Name = "PlayerEmoteVFX"
            effect.CFrame = char.PrimaryPart.CFrame * CFrame.new(0, -1, -0.3)
            effect.WeldConstraint.Part0 = char.PrimaryPart
            effect.WeldConstraint.Part1 = effect
            effect.Parent = char
            effect.CanCollide = false

            local args = {"PlayEmote", "Animations", "HakariDance"}
            ReplicatedStorage.Modules.Network.RemoteEvent:FireServer(unpack(args))

            animationTrack.Stopped:Connect(function()
                if not LeftOther.Options.HakariDance.Value then
                    humanoid.PlatformStand = false
                    if bodyVelocity and bodyVelocity.Parent then bodyVelocity:Destroy() end
                end
            end)
        else
            humanoid.PlatformStand = false
            humanoid.JumpPower = 50

            local bodyVelocity = rootPart:FindFirstChildOfClass("BodyVelocity")
            if bodyVelocity then bodyVelocity:Destroy() end

            local sound = rootPart:FindFirstChildOfClass("Sound")
            if sound and sound.SoundId:find("87166578676888") then
                sound:Stop()
                sound:Destroy()
            end

            local effect = char:FindFirstChild("PlayerEmoteVFX")
            if effect then effect:Destroy() end

            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                if track.Animation.AnimationId == "rbxassetid://138019937280193" then
                    track:Stop()
                end
            end
        end
    end
})
_G.showChat = _G.showChat or false
local RightOther = OtherTab:AddRightGroupbox("chat")

RightOther:AddToggle('AlwaysShowChat', {
    Text = "Always Show Chat",
    Callback = function(state)
        if state then
            _G.showChat = true
            task.spawn(function()
                while _G.showChat and task.wait() do
                    local chatConfig = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
                    if chatConfig then
                        chatConfig.Enabled = true
                    end
                end
            end)
        else
            _G.showChat = false
            local playingState = lp:GetAttribute("PlayingState") or "Playing"
            if playingState ~= "Spectating" then
                local chatConfig = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
                if chatConfig then
                    chatConfig.Enabled = false
                end
            end
        end
    end
})

local customMaxStamina = 100
local customStaminaGain = 20
local customStaminaLoss = 5
local customSprintSpeed = 28

local infStamina = true
local enableMaxStamina = false
local enableStaminaGain = false
local enableStaminaLoss = false
local enableSprintSpeed = false

local originalMaxStamina = nil
local originalStaminaGain = nil
local originalStaminaLoss = nil
local originalSprintSpeed = nil

local SprintingModule = require(ReplicatedStorage.Systems.Character.Game.Sprinting)

task.spawn(function()
    while task.wait(0.1) do
        if SprintingModule then
            if infStamina then
                SprintingModule.Stamina = SprintingModule.MaxStamina
            else
                if enableMaxStamina then
                    SprintingModule.MaxStamina = customMaxStamina
                elseif originalMaxStamina ~= nil then
                    SprintingModule.MaxStamina = originalMaxStamina
                end

                if enableStaminaGain then
                    SprintingModule.StaminaGain = customStaminaGain
                elseif originalStaminaGain ~= nil then
                    SprintingModule.StaminaGain = originalStaminaGain
                end

                if enableStaminaLoss then
                    SprintingModule.StaminaLoss = customStaminaLoss
                elseif originalStaminaLoss ~= nil then
                    SprintingModule.StaminaLoss = originalStaminaLoss
                end

                if enableSprintSpeed then
                    SprintingModule.SprintSpeed = customSprintSpeed
                elseif originalSprintSpeed ~= nil then
                    SprintingModule.SprintSpeed = originalSprintSpeed
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if SprintingModule then
            if originalMaxStamina == nil then originalMaxStamina = SprintingModule.MaxStamina end
            if originalStaminaGain == nil then originalStaminaGain = SprintingModule.StaminaGain end
            if originalStaminaLoss == nil then originalStaminaLoss = SprintingModule.StaminaLoss end
            if originalSprintSpeed == nil then originalSprintSpeed = SprintingModule.SprintSpeed end
        end
    end
end)

local LeftStamina = StaminaTab:AddLeftGroupbox("Toggles")
local RightStamina = StaminaTab:AddRightGroupbox("Values")

LeftStamina:AddToggle("InfStamina", {
    Text = "Infinite Stamina",
    Default = true,
    Callback = function(v)
        infStamina = v
    end
})

LeftStamina:AddToggle("EnableMaxStamina", {
    Text = "Custom Max Stamina",
    Default = false,
    Callback = function(v)
        enableMaxStamina = v
    end
})

LeftStamina:AddToggle("EnableStaminaGain", {
    Text = "Custom Stamina Gain",
    Default = false,
    Callback = function(v)
        enableStaminaGain = v
    end
})

LeftStamina:AddToggle("EnableStaminaLoss", {
    Text = "Custom Stamina Loss",
    Default = false,
    Callback = function(v)
        enableStaminaLoss = v
    end
})

LeftStamina:AddToggle("EnableSprintSpeed", {
    Text = "Custom Sprint Speed",
    Default = false,
    Callback = function(v)
        enableSprintSpeed = v
    end
})

RightStamina:AddInput("MaxStamina", {
    Text = "Max Stamina",
    Default = "100",
    Numeric = true,
    Callback = function(v)
        customMaxStamina = tonumber(v) or 100
    end
})

RightStamina:AddInput("StaminaGain", {
    Text = "Stamina Gain",
    Default = "20",
    Numeric = true,
    Callback = function(v)
        customStaminaGain = tonumber(v) or 10
    end
})

RightStamina:AddInput("StaminaLoss", {
    Text = "Stamina Loss",
    Default = "5",
    Numeric = true,
    Callback = function(v)
        customStaminaLoss = tonumber(v) or 15
    end
})

RightStamina:AddInput("SprintSpeed", {
    Text = "Sprint Speed",
    Default = "28",
    Numeric = true,
    Callback = function(v)
        customSprintSpeed = tonumber(v) or 25
    end
})

local antiStun=false
local antiSlow=false
local antiBlindness=true
local antiSubspace=true
local antiHiddenStats=false
local toggleState=false
local originalValues={}

local AntiGroup=AntiTab:AddLeftGroupbox("Anti")
local anti1xConn

AntiGroup:AddToggle("Anti1x", {
    Text = "Anti 1x1x1x1 popups",
    Default = true,
    Callback = function(state)
        _G.no1x = state

        if anti1xConn then
            anti1xConn:Disconnect()
            anti1xConn = nil
        end

        if not state then return end

        local function handlePopup(popup)
            task.wait(0.3) 
            if firesignal and popup and popup:IsA("ImageButton") then
                pcall(function()
                    firesignal(popup.MouseButton1Click)
                end)
            end
        end

        local function scan(gui)
            if gui.Name ~= "TemporaryUI" then return end
            local popup = gui:FindFirstChild("1x1x1x1Popup")
            if popup then
                handlePopup(popup)
            end
            gui.ChildAdded:Connect(function(c)
                if c.Name == "1x1x1x1Popup" then
                    handlePopup(c)
                end
            end)
        end

        for _,ui in ipairs(lp.PlayerGui:GetChildren()) do
            scan(ui)
        end

        anti1xConn = lp.PlayerGui.ChildAdded:Connect(scan)
    end
})

AntiGroup:AddToggle("AntiStun",{
Text="Anti Stun",
Default=false,
Callback=function(v)
antiStun=v
task.spawn(function()
while antiStun and task.wait() do
local char=lp.Character
if char and char:FindFirstChild("SpeedMultipliers") then
local s=char.SpeedMultipliers:FindFirstChild("Stunned")
if s then s.Value=1.2 end
end
end
end)
end})

AntiGroup:AddToggle("AntiSlow",{
Text="Anti Slow",
Default=false,
Callback=function(v)
antiSlow=v
task.spawn(function()
while antiSlow and task.wait() do
local char=lp.Character
if char and char:FindFirstChild("SpeedMultipliers") then
for _,m in ipairs(char.SpeedMultipliers:GetChildren()) do
if m.Value<1 then m.Value=1.2 end
end
end
end
end)
end})

AntiGroup:AddToggle("AntiBlind",{
Text="Anti Blindness",
Default=true,
Callback=function(v)
antiBlindness=v
task.spawn(function()
while antiBlindness and task.wait() do
local b=Lighting:FindFirstChild("BlindnessBlur")
if b then b:Destroy() end
end
end)
end})

AntiGroup:AddToggle("AntiSubspace",{
Text="Anti Subspace",
Default=false,
Callback=function(v)
antiSubspace=v
task.spawn(function()
while antiSubspace and task.wait() do
local a=Lighting:FindFirstChild("SubspaceVFXBlur")
local b=Lighting:FindFirstChild("SubspaceVFXColorCorrection")
if a then a:Destroy() end
if b then b:Destroy() end
end
end)
end})

local paths={"HideKillerWins","HidePlaytime","HideSurvivorWins"}

local function saveOriginals(p)
originalValues[p.UserId]=originalValues[p.UserId] or {}
for _,k in ipairs(paths) do
local v=p.PlayerData.Settings.Privacy:FindFirstChild(k)
if v then originalValues[p.UserId][k]=v.Value end
end
end

local function reveal(p)
for _,k in ipairs(paths) do
local v=p.PlayerData.Settings.Privacy:FindFirstChild(k)
if v then v.Value=false end
end
end

local function restore(p)
if not originalValues[p.UserId] then return end
for k,val in pairs(originalValues[p.UserId]) do
local v=p.PlayerData.Settings.Privacy:FindFirstChild(k)
if v then v.Value=val end
end
end

local function hiddenStatsFunc(on)
for _,p in ipairs(Players:GetPlayers()) do
if on then
saveOriginals(p)
reveal(p)
else
restore(p)
end
end
end

Players.PlayerAdded:Connect(function(p)
if toggleState then
saveOriginals(p)
reveal(p)
end
end)

AntiGroup:AddToggle("AntiHiddenStats",{
Text="Anti Hidden Stats",
Default=false,
Callback=function(v)
toggleState=v
antiHiddenStats=v
hiddenStatsFunc(v)
end})

local KillersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")

local cachedBlockBtn, cachedCooldown
local function refreshUIRefs()
    local main = PlayerGui:FindFirstChild("MainUI")
    if main then
        local ability = main:FindFirstChild("AbilityContainer")
        cachedBlockBtn = ability and ability:FindFirstChild("Block")
        cachedCooldown = cachedBlockBtn and cachedBlockBtn:FindFirstChild("CooldownTime")
    end
end
refreshUIRefs()
PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "MainUI" then task.delay(0.02, refreshUIRefs) end
end)
lp.CharacterAdded:Connect(function() task.delay(0.5, refreshUIRefs) end)

local function click(btnName)
    local ui = PlayerGui:FindFirstChild("MainUI")
    local btn = ui and ui:FindFirstChild("AbilityContainer") and ui.AbilityContainer:FindFirstChild(btnName)
    if not btn then return end
    for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
    pcall(function() btn:Activate() end)
end

local function isFacing(myRoot, targetRoot)
    if not facingCheckEnabled then return true end
    local dir = (myRoot.Position - targetRoot.Position).Unit
    local dot = targetRoot.CFrame.LookVector:Dot(dir)
    return dot > customFacingDot
end

local soundHooks = {}
local soundBlockedUntil = {}
local lastLocalBlockTime = 0
local AUDIO_LOCAL_COOLDOWN = 0.35

local function extractNumericSoundId(sound)
    local sid = sound.SoundId
    if type(sid) ~= "string" then sid = tostring(sid) end
    return sid:match("rbxassetid://(%d+)") or sid:match("://(%d+)") or sid:match("^(%d+)$")
end

local function hookSound(sound)
    if not sound:IsA("Sound") or soundHooks[sound] then return end
    local id = extractNumericSoundId(sound)
    if not id or not autoBlockTriggerSounds[id] then return end
    soundHooks[sound] = true
    local function tryBlock()
        if not autoBlockAudioOn then return end
        if tick() - lastLocalBlockTime < AUDIO_LOCAL_COOLDOWN then return end
        if soundBlockedUntil[sound] and tick() < soundBlockedUntil[sound] then return end
        local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local parent = sound.Parent
        while parent and not parent:FindFirstChild("HumanoidRootPart") do parent = parent.Parent end
        local hrp = parent and parent:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if (hrp.Position - myRoot.Position).Magnitude > detectionRange then return end
        if facingCheckEnabled and not isFacing(myRoot, hrp) then return end
        refreshUIRefs()
        if cachedCooldown and cachedCooldown.Text ~= "" then return end
        task.wait(blockdelay)
        click("Block")
        lastLocalBlockTime = tick()
        soundBlockedUntil[sound] = tick() + 1
    end
    sound.Played:Connect(tryBlock)
    sound:GetPropertyChangedSignal("IsPlaying"):Connect(function() if sound.IsPlaying then tryBlock() end end)
    if sound.IsPlaying then tryBlock() end
end

for _, desc in ipairs(KillersFolder:GetDescendants()) do if desc:IsA("Sound") then hookSound(desc) end end
KillersFolder.DescendantAdded:Connect(function(desc) if desc:IsA("Sound") then hookSound(desc) end end)

RunService.RenderStepped:Connect(function()
    if not autoBlockOn then return end
    local myChar = lp.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    refreshUIRefs()
    if cachedCooldown and cachedCooldown.Text ~= "" then return end
    for _, killer in ipairs(KillersFolder:GetChildren()) do
        local hrp = killer:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - myRoot.Position).Magnitude <= detectionRange then
            local hum = killer:FindFirstChildOfClass("Humanoid")
            local animator = hum and hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local animId = tostring(track.Animation.AnimationId):match("%d+")
                    if animId and autoBlockTriggerAnims[animId] then
                        if not facingCheckEnabled or isFacing(myRoot, hrp) then
                            task.wait(blockdelay)
                            click("Block")
                            return
                        end
                    end
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not autoPunch then return end
    local myChar = lp.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local gui = PlayerGui:FindFirstChild("MainUI")
    local punchBtn = gui and gui:FindFirstChild("AbilityContainer") and gui.AbilityContainer:FindFirstChild("Punch")
    local charges = punchBtn and punchBtn:FindFirstChild("Charges")
    if not charges or charges.Text ~= "1" then return end
    local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if not killersFolder then return end
    for _, killer in ipairs(killersFolder:GetChildren()) do
        local root = killer:FindFirstChild("HumanoidRootPart")
        if root and (root.Position - myRoot.Position).Magnitude <= 10 then
            if aimPunch then
                local humanoid = myChar:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.AutoRotate = false end
                task.spawn(function()
                    local startTime = tick()
                    while tick() - startTime < 1 do
                        if myRoot and root and root.Parent then
                            local predictedPos = root.Position + (root.CFrame.LookVector * aimPrediction)
                            myRoot.CFrame = CFrame.lookAt(myRoot.Position, predictedPos)
                        end
                        task.wait()
                    end
                    if humanoid then humanoid.AutoRotate = true end
                end)
            end
            click("Punch")
            break
        end
    end
end)

local killersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")
local lastBackstab = 0
local COOLDOWN = 10
local HOLD = 0.295

local function isBehind(hrp, khrp)
    if (hrp.Position - khrp.Position).Magnitude > backstabRange then return false end
    if backstabMode == "Around" then return true end
    return (hrp.Position - khrp.Position):Dot(-khrp.CFrame.LookVector) > 0.5
end

RunService.Heartbeat:Connect(function()
    if not backstab or tick() - lastBackstab < COOLDOWN then return end
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, k in ipairs(killersFolder:GetChildren()) do
        local khrp = k:FindFirstChild("HumanoidRootPart")
        if khrp and isBehind(hrp, khrp) then
            lastBackstab = tick()
            click("Dagger")
            local s = tick()
            local c
            c = RunService.Heartbeat:Connect(function()
                if tick() - s > HOLD then c:Disconnect() return end
                hrp.CFrame = CFrame.new(khrp.Position - khrp.CFrame.LookVector * backdis, khrp.Position)
            end)
            break
        end
    end
end)

local oldA, oldO, oldB, oldF = Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness, Lighting.FogEnd
local function bright(on)
    if on then
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.Brightness = 6
        Lighting.FogEnd = 0
    else
        Lighting.Ambient = oldA
        Lighting.OutdoorAmbient = oldO
        Lighting.Brightness = oldB
        Lighting.FogEnd = oldF
    end
end

local function addHL(obj, color)
    if obj:FindFirstChild("VisualHL") then return end
    local h = Instance.new("Highlight")
    h.Name = "VisualHL"
    h.FillTransparency = 1
    h.OutlineTransparency = 0
    h.OutlineColor = color
    h.Parent = obj
    h.Adornee = obj
end

local function clearVisual()
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Highlight") and v.Name == "VisualHL" then v:Destroy() end
    end
end

task.spawn(function()
    while task.wait(1) do
        if not visualEnabled then clearVisual() bright(false) continue end
        bright(true)
        clearVisual()
        local pf = workspace:FindFirstChild("Players")
        if pf then
            if showKiller and pf:FindFirstChild("Killers") then
                for _, k in ipairs(pf.Killers:GetChildren()) do
                    if k:FindFirstChild("Humanoid") then addHL(k, Color3.fromRGB(255,70,70)) end
                end
            end
            if showSurvivor and pf:FindFirstChild("Survivors") then
                for _, s in ipairs(pf.Survivors:GetChildren()) do
                    if s:FindFirstChild("Humanoid") then addHL(s, Color3.fromRGB(70,255,70)) end
                end
            end
        end
        if showItems then
            for _, i in ipairs(workspace:GetDescendants()) do
                if i.Name == "Medkit" or i.Name == "BloxyCola" then addHL(i, Color3.fromRGB(180,0,255)) end
            end
        end
        if showGen then
            for _, g in ipairs(workspace:GetDescendants()) do
                if g.Name:lower():find("generator") then addHL(g, Color3.fromRGB(255,255,0)) end
            end
        end
    end
end)

local flipHeight = 10
local flipDistance = 20

LeftOther:AddToggle("FrontFlip", { 
    Text = "Front Flip",
    Tooltip = "funny flip",
    Default = false,
    Callback = function(v)
        getgenv().FlipUI.Enabled = v
    end
}):AddKeyPicker("FlipKeybind", {
    Default = "F",
    Text = "Flip keybind",
    NoUI = false,
    Callback = function()
        if not LeftOther.Options.FrontFlip.Value then return end
        FortniteFlips()
    end,
})

LeftOther:AddSlider("FlipHeight", {
    Text = "Flip Height",
    Min = 5,
    Max = 35,
    Default = 10,
    Rounding = 1,
    Callback = function(v)
        flipHeight = v
    end
})

LeftOther:AddSlider("FlipDistance", {
    Text = "Flip Distance",
    Min = 5,
    Max = 35,
    Default = 20,
    Rounding = 1,
    Callback = function(v)
        flipDistance = v
    end
})

local FlipCooldown = false

function FortniteFlips()
    if FlipCooldown then
        return
    end

    FlipCooldown = true
    local character = lp.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not hrp or not humanoid then
        FlipCooldown = false
        return
    end

    local savedTracks = {}

    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            savedTracks[#savedTracks + 1] = { track = track, time = track.TimePosition }
            track:Stop(0)
        end
    end

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)

    local duration = 0.45
    local steps = 120
    local startCFrame = hrp.CFrame
    local forwardVector = startCFrame.LookVector
    local upVector = Vector3.new(0, 1, 0)
    task.spawn(function()
        local startTime = tick()
        for i = 1, steps do
            local t = i / steps
            local height = 4 * (t - t ^ 2) * flipHeight
            local nextPos = startCFrame.Position + forwardVector * (flipDistance * t) + upVector * height
            local rotation = startCFrame.Rotation * CFrame.Angles(-math.rad(i * (360 / steps)), 0, 0)

            hrp.CFrame = CFrame.new(nextPos) * rotation
            local elapsedTime = tick() - startTime
            local expectedTime = (duration / steps) * i
            local waitTime = expectedTime - elapsedTime
            if waitTime > 0 then
                task.wait(waitTime)
            end
        end

        hrp.CFrame = CFrame.new(startCFrame.Position + forwardVector * flipDistance) * startCFrame.Rotation
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)

        if animator then
            for _, data in ipairs(savedTracks) do
                local track = data.track
                track:Play()
                track.TimePosition = data.time
            end
        end
        task.wait(0.25)
        FlipCooldown = false
    end)
end


task.spawn(function()
    local Undetectable = require(ReplicatedStorage.Modules.StatusEffects.Undetectable)
    local animationId = "rbxassetid://75804462760596"
    local loadedAnim = nil
    local function play(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local anim = Instance.new("Animation")
            anim.AnimationId = animationId
            loadedAnim = hum:LoadAnimation(anim)
            loadedAnim:Play()
            loadedAnim:AdjustSpeed(0)
        end
    end
    local function stop()
        if loadedAnim then loadedAnim:Stop() loadedAnim = nil end
    end
    local oA = Undetectable.Applied
    local oR = Undetectable.Removed
    Undetectable.Applied = function(d)
        if undetectedMode and d.Player == lp then play(d.Character or d.Player.Character) end
        return oA(d)
    end
    Undetectable.Removed = function(d)
        if undetectedMode and d.Player == lp then stop() end
        return oR(d)
    end
end)

local autoGen = true
local autoGenSpeed = 0.08
local FlowGameModule
local oldNew
local hookedGen = false

local function isNeighbour(r1, c1, r2, c2)
    return (r2 == r1-1 and c2 == c1) or (r2 == r1+1 and c2 == c1) or (r2 == r1 and c2 == c1-1) or (r2 == r1 and c2 == c1+1)
end

local function key(n) return n.row .. "-" .. n.col end

local function orderPath(path, endpoints)
    if not path or #path == 0 then return path end
    local start = endpoints and endpoints[1] or path[1]
    local pool = {}
    for _, n in ipairs(path) do pool[key(n)] = {row = n.row, col = n.col} end
    local ordered = {}
    local cur = {row = start.row, col = start.col}
    table.insert(ordered, cur)
    pool[key(cur)] = nil
    while next(pool) do
        local found = false
        for k, n in pairs(pool) do
            if isNeighbour(cur.row, cur.col, n.row, n.col) then
                table.insert(ordered, n)
                pool[k] = nil
                cur = n
                found = true
                break
            end
        end
        if not found then break end
    end
    return ordered
end

local HintSystem = {}
function HintSystem:Draw(puzzle)
    if not puzzle or not puzzle.Solution then return end
    for i = 1, #puzzle.Solution do
        local path = puzzle.Solution[i]
        local ends = puzzle.targetPairs[i]
        local ordered = orderPath(path, ends)
        puzzle.paths[i] = {}
        for _, node in ipairs(ordered) do
            if not autoGen then return end
            table.insert(puzzle.paths[i], {row = node.row, col = node.col})
            puzzle:updateGui()
            task.wait(autoGenSpeed)
        end
        puzzle:checkForWin()
    end
end

local function hookAutoGen()
    if hookedGen then return end
    local mod = ReplicatedStorage.Modules.Misc.FlowGameManager.FlowGame
    FlowGameModule = require(mod)
    oldNew = oldNew or FlowGameModule.new
    FlowGameModule.new = function(...)
        local puzzle = oldNew(...)
        task.spawn(function()
            if autoGen then HintSystem:Draw(puzzle) end
        end)
        return puzzle
    end
    hookedGen = true
end

hookAutoGen()

task.spawn(function()
    while task.wait(0.2) do
        local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = jumpEnabled and 60 or 0 end
    end
end)

local ShedletskyGroup = RoleTab:AddLeftGroupbox("Shedletsky")

local tpSlashEnabled = false
local tpSlashRange = 8
local tpSlashDistance = 0.3
local tpSlashDelay = 0.08  
local tpSlashHoldTime = 0.58
local tpSlashCooldown = 10
local lastTpSlashTime = 0

ShedletskyGroup:AddToggle("AutoTPSlash", {
    Text = "Auto TP Slash",
    Default = false,
    Callback = function(v)
        tpSlashEnabled = v
    end
})

ShedletskyGroup:AddInput("TPSlashRange", {
    Text = "Range",
    Default = "8",
    Numeric = true,
    Callback = function(t)
        tpSlashRange = tonumber(t) or 8
    end
})

ShedletskyGroup:AddInput("TPSlashDis", {
    Text = "TP Distance",
    Default = "0.3",
    Numeric = true,
    PlaceholderText = "0.3 - 3",
    Callback = function(text)
        local num = tonumber(text)
        if num and num >= 0.3 and num <= 3 then
            tpSlashDistance = num
        else
            tpSlashDistance = 0.5
            Library:Notify("TP Distance must be between 0.3 and 3!", 3)
        end
    end
})

RunService.Heartbeat:Connect(function()
    if not tpSlashEnabled then return end
    if tick() - lastTpSlashTime < tpSlashCooldown then return end

    local myChar = lp.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
    if not killersFolder then return end

    local targetKiller = nil
    local closestDist = math.huge

    for _, killer in ipairs(killersFolder:GetChildren()) do
        local kRoot = killer:FindFirstChild("HumanoidRootPart")
        if kRoot and killer:FindFirstChild("Humanoid") and killer.Humanoid.Health > 0 then
            local dist = (kRoot.Position - myRoot.Position).Magnitude
            if dist <= tpSlashRange and dist < closestDist then
                closestDist = dist
                targetKiller = killer
            end
        end
    end

    if targetKiller then
        local kRoot = targetKiller:FindFirstChild("HumanoidRootPart")
        if kRoot then
            lastTpSlashTime = tick()
            local holdStart = tick()
            local holdConn
            holdConn = RunService.Heartbeat:Connect(function()
                if tick() - holdStart >= tpSlashHoldTime then
                    holdConn:Disconnect()
                    return
                end
                if myRoot and kRoot and kRoot.Parent then
                    myRoot.CFrame = CFrame.new(kRoot.Position + kRoot.CFrame.LookVector * tpSlashDistance, kRoot.Position)
                end
            end)
            task.delay(tpSlashDelay, function()
                if tpSlashEnabled and myRoot and kRoot and kRoot.Parent then
                    click("Slash")
                end
            end)
        end
    end
end)
local RightRole = RoleTab:AddRightGroupbox("Killer")
RightRole:AddToggle("Hitbox", {Text = "Hitbox", Default = false, Callback = function(v)
    hitbox = v
    if v then
        HitboxModule = HitboxModule or loadstring(game:HttpGet("https://raw.githubusercontent.com/FoxIPro5965/c00lgui/main/Hitbox.lua"))()
        HitboxModule:ExtendHitbox(1.3, 500)
    elseif HitboxModule then
        HitboxModule:StopExtendingHitbox()
    end
end})
local AntiFakeNoliGroup = AntiTab:AddLeftGroupbox("Anti Fake Noli")

_G.AntiFakeNoliEnabled = false

AntiFakeNoliGroup:AddToggle("AntiFakeNoli", {
    Text = "Anti Fake Noli",
    Default = false,
    Callback = function(state)
        _G.AntiFakeNoliEnabled = state
        
        if state then
            spawn(function()
                while _G.AntiFakeNoliEnabled do
                    pcall(function()
                        local Killers = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
                        if Killers then
                            for _, model in pairs(Killers:GetChildren()) do
                                if model:IsA("Model") and model:GetAttribute("IsFakeNoli") == true then
                                    model:Destroy()
                                end
                            end
                        end
                    end)
                    task.wait(0.2)
                end
            end)
        end
    end
})

local DestroyGroup = ConfigTab:AddLeftGroupbox("Unload")
DestroyGroup:AddButton("Unload GUI", function()
    Library:Unload()
end)
DestroyGroup:AddLabel("Click to destroy UI")

Library:Notify("i love you zen!", 5)
Library:Notify("loading infinite yield!", 3)
wait(2)
loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
Library:Notify("enjoy :D", 3)
