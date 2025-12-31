local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function getPlayerGui()
    local plr = Players.LocalPlayer
    if plr and plr:FindFirstChild("PlayerGui") then
        return plr.PlayerGui
    end
    return nil
end

local function getCamera()
    return Workspace.CurrentCamera
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local HRP = Character:FindFirstChild("HumanoidRootPart")

local function updateCharacterRefs(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
end

LocalPlayer.CharacterAdded:Connect(updateCharacterRefs)

local function getChar() return Character end
local function getHumanoid() return Humanoid end
local function getHRP() return HRP end

local function WaitForMap()
    local mapContainer = Workspace:FindFirstChild("Map")
    local ingame = mapContainer and mapContainer:FindFirstChild("Ingame")
    return ingame and ingame:FindFirstChild("Map") or nil
end

local MapFolder = WaitForMap()
local function RefreshMap()
    MapFolder = WaitForMap()
    return MapFolder
end

local function getSurvivorsFolder()
    return Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Survivors")
end

local function getKillersFolder()
    return Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Killers")
end

local function getGeneratorRemote(gen)
    return (gen and gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE")) or nil
end

AimSystem = {}

function AimSystem.RotateTo(targetCFrame, speed)
    if not HRP then return end
    speed = speed or 1

    local currentCFrame = HRP.CFrame
    local goalCFrame = CFrame.new(currentCFrame.Position, targetCFrame.Position)
    HRP.CFrame = currentCFrame:Lerp(goalCFrame, speed)
end

function AimSystem.GetTargetCFrame(targetPlayer)
    local targetChar = targetPlayer.Character
    if targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
        return targetChar.HumanoidRootPart.CFrame
    end
    return nil
end

local GuiClick = {}

GuiClick._cache = {}
GuiClick._initialized = false

function GuiClick:Init()
    if self._initialized then return end
    self._initialized = true

    local function scan()
        local gui = getPlayerGui()
        if not gui then return end

        local mainUI = gui:FindFirstChild("MainUI")
        local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
        if not container then return end

        for _, btn in ipairs(container:GetChildren()) do
            if btn:IsA("ImageButton") then
                if not self._cache[btn.Name] then
                    local info = {
                        button = btn,
                        connections = {},
                        remote = nil
                    }

                    local conns = getconnections(btn.MouseButton1Click)
                    info.connections = conns

                    for _, conn in ipairs(conns) do
                        local f = conn.Function
                        if f and islclosure(f) then
                            for _, v in pairs(getupvalues(f)) do
                                if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                                    info.remote = v
                                end
                            end
                        end
                    end

                    self._cache[btn.Name] = info
                end
            end
        end
    end

    scan()

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        self._cache = {}
        scan()
    end)
end

function GuiClick:Use(skillName)
    local data = self._cache[skillName]
    if not data then return false end

    if data.remote then
        pcall(function()
            data.remote:FireServer(true)
            task.delay(0.05, function()
                data.remote:FireServer(false)
            end)
        end)
        return true
    end

    for _, conn in ipairs(data.connections or {}) do
        pcall(function()
            conn:Fire()
        end)
    end

    if data.button then
        pcall(function()
            data.button:Activate()
        end)
    end

    return true
end

AnimationService = {}
AnimationService.__index = AnimationService

AnimationService.Character = Character
AnimationService.Humanoid = Humanoid
AnimationService.Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")

AnimationService.Tracks = {}
AnimationService.Animations = {}
AnimationService.Enabled = {}
AnimationService.Options = {}

local function setupAnimator()
    if not AnimationService.Humanoid then return end

    AnimationService.Animator =
        AnimationService.Humanoid:FindFirstChildOfClass("Animator")
        or Instance.new("Animator", AnimationService.Humanoid)

    for _, track in pairs(AnimationService.Tracks) do
        pcall(function()
            track:Stop(0.1)
            track:Destroy()
        end)
    end

    table.clear(AnimationService.Tracks)
end

function AnimationService:Init()
    setupAnimator()

    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.15)

        self.Character = char
        self.Humanoid = char:WaitForChild("Humanoid")

        setupAnimator()

        for name, enabled in pairs(self.Enabled) do
            if enabled then
                self:_playInternal(name)
            end
        end
    end)
end

function AnimationService:Register(name, animationId, options)
    self.Animations[name] = tostring(animationId)
    self.Options[name] = options or {}
end

function AnimationService:_load(name)
    if self.Tracks[name] then
        return self.Tracks[name]
    end

    local animId = self.Animations[name]
    if not animId or not self.Animator then return nil end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId

    local track = self.Animator:LoadAnimation(anim)
    self.Tracks[name] = track

    return track
end

function AnimationService:_playInternal(name)
    local track = self:_load(name)
    if not track then return end

    local opt = self.Options[name] or {}

    if opt.Priority then track.Priority = opt.Priority end

    track:Play(opt.FadeTime or 0.15)
    if opt.Speed then track:AdjustSpeed(opt.Speed) end

    track.Stopped:Connect(function()
        if self.Enabled[name] then
            track:Play(0.1)
        end
    end)

    return track
end

function AnimationService:Enable(name)
    if not self.Animations[name] then return end
    self.Enabled[name] = true
    self:_playInternal(name)
end

function AnimationService:Disable(name)
    self.Enabled[name] = false

    local track = self.Tracks[name]
    if track then
        pcall(function()
            track:Stop(0.15)
            track:Destroy()
        end)
    end

    self.Tracks[name] = nil
end

function AnimationService:IsEnabled(name)
    return self.Enabled[name] == true
end

function AnimationService:StopAll()
    for name in pairs(self.Enabled) do
        self:Disable(name)
    end
end

AnimationService:Init()

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

WindUI:AddTheme({
    Name = "Dark",
    Accent = "#18181b",
    Dialog = "#18181b", 
    Outline = "#FFFFFF",
    Text = "#FFFFFF",
    Placeholder = "#999999",
    Background = "#0e0e10",
    Button = "#52525b",
    Icon = "#a1a1aa",
})

WindUI:AddTheme({
    Name = "Light",
    Accent = "#f4f4f5",
    Dialog = "#f4f4f5",
    Outline = "#000000", 
    Text = "#000000",
    Placeholder = "#666666",
    Background = "#ffffff",
    Button = "#e4e4e7",
    Icon = "#52525b",
})

WindUI:AddTheme({
    Name = "Gray",
    Accent = "#374151",
    Dialog = "#374151",
    Outline = "#d1d5db", 
    Text = "#f9fafb",
    Placeholder = "#9ca3af",
    Background = "#1f2937",
    Button = "#4b5563",
    Icon = "#d1d5db",
})

WindUI:AddTheme({
    Name = "Blue",
    Accent = "#1e40af",
    Dialog = "#1e3a8a",
    Outline = "#93c5fd", 
    Text = "#f0f9ff",
    Placeholder = "#60a5fa",
    Background = "#1e293b",
    Button = "#3b82f6",
    Icon = "#93c5fd",
})

WindUI:AddTheme({
    Name = "Green",
    Accent = "#059669",
    Dialog = "#047857",
    Outline = "#6ee7b7", 
    Text = "#ecfdf5",
    Placeholder = "#34d399",
    Background = "#064e3b",
    Button = "#10b981",
    Icon = "#6ee7b7",
})

WindUI:AddTheme({
    Name = "Purple",
    Accent = "#7c3aed",
    Dialog = "#6d28d9",
    Outline = "#c4b5fd", 
    Text = "#faf5ff",
    Placeholder = "#a78bfa",
    Background = "#581c87",
    Button = "#8b5cf6",
    Icon = "#c4b5fd",
})

WindUI:SetNotificationLower(true)

local themes = {"Dark", "Light", "Gray", "Blue", "Green", "Purple"}
local currentThemeIndex = 1

if not getgenv().TransparencyEnabled then
    getgenv().TransparencyEnabled = true
end

local Window = WindUI:CreateWindow({
    Title = "Hutao Hub [Premium]",
    Icon = "rbxassetid://109995816235688", 
    Author = "Forsaken | By: SLK GAMING",
    Folder = "HutaoHub - WindUI",
    Size = UDim2.fromOffset(500, 350),
    Transparent = getgenv().TransparencyEnabled,
    Theme = "Blue",
    Resizable = true,
    SideBarWidth = 150,
    BackgroundImageTransparency = 0.8,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            currentThemeIndex = currentThemeIndex + 1
            if currentThemeIndex > #themes then
                currentThemeIndex = 1
            end
            
            local newTheme = themes[currentThemeIndex]
            WindUI:SetTheme(newTheme)
           
            WindUI:Notify({
                Title = "Theme Changed",
                Content = "Switched to " .. newTheme .. " theme!",
                Duration = 2,
                Icon = "palette"
            })
            print("Switched to " .. newTheme .. " theme")
        end,
    },
    
})

Window:SetToggleKey(Enum.KeyCode.V)

pcall(function()
    Window:CreateTopbarButton("TransparencyToggle", "eye", function()
        if getgenv().TransparencyEnabled then
            getgenv().TransparencyEnabled = false
            pcall(function() Window:ToggleTransparency(false) end)
            
            WindUI:Notify({
                Title = "Transparency", 
                Content = "Transparency disabled",
                Duration = 3,
                Icon = "eye"
            })
            print("Transparency = false")
        else
            getgenv().TransparencyEnabled = true
            pcall(function() Window:ToggleTransparency(true) end)
            
            WindUI:Notify({
                Title = "Transparency",
                Content = "Transparency enabled", 
                Duration = 3,
                Icon = "eye-off"
            })
            print(" Transparency = true")
        end

        print("Debug - Current Transparency state:", getgenv().TransparencyEnabled)
    end, 990)
end)

Window:EditOpenButton({
    Title = "Hutao Hub - Open Gui",
    Icon = "monitor",
    CornerRadius = UDim.new(0, 6),
    StrokeThickness = 2,
Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 140, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 120)),
}),
    Draggable = true,
})

Window:Tag({
    Title = "v2.3.8",
    Color = Color3.fromHex("#30ff6a")
})

local Tabs = {
    About = Window:Section({ Title = "About", Opened = true }),
    Main = Window:Section({ Title = "Main", Opened = true }),
    Custom = Window:Section({ Title = "Custom", Opened = true }),
    Game = Window:Section({ Title = "Game", Opened = true }),
    Misc = Window:Section({ Title = "Misc", Opened = true }),
}

local TabHandles = {
    Info = Tabs.About:Tab({ Title = "Information", Icon = "badge-info", Desc = "" }),
    Farm = Tabs.Main:Tab({ Title = "Farm", Icon = "crown", Desc = "" }),
    Survivors = Tabs.Main:Tab({ Title = "Survivors", Icon = "user-check", Desc = "" }),
    Killers = Tabs.Main:Tab({ Title = "Killers", Icon = "skull", Desc = "" }),
    Emote = Tabs.Custom:Tab({ Title = "Emote", Icon = "smile", Desc = "" }),
    Animation = Tabs.Custom:Tab({ Title = "Animation", Icon = "activity", Desc = "" }),
    Skills = Tabs.Custom:Tab({ Title = "Skills", Icon = "wand", Desc = "" }),
    Event = Tabs.Game:Tab({ Title = "Event", Icon = "bell", Desc = "" }),
    Teleport = Tabs.Game:Tab({ Title = "Teleport", Icon = "map", Desc = "" }),
    Player = Tabs.Game:Tab({ Title = "Player", Icon = "user", Desc = "" }),
    Visual = Tabs.Game:Tab({ Title = "Visual", Icon = "eye", Desc = "" }),
    Settings = Tabs.Misc:Tab({ Title = "Settings", Icon = "settings", Desc = "" }),
}

local OwnerList = {
    ["rbown_VIP"] = true,
    ["2x17d10"] = true,
    ["n1lk_v033STPE"] = true,
    ["SLK_GAMINGSSR"] = true,
    ["SLK_GAMlNGSSR"] = true,
}

local notifiedLocalOwner = false
local notifiedOwnerCount = 0

local function checkOwner()
    local isLocalOwner = OwnerList[LocalPlayer.Name] or false
    local currentOwnerCount = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if OwnerList[plr.Name] then
            currentOwnerCount = currentOwnerCount + 1
        end
    end

    if isLocalOwner and not notifiedLocalOwner then
        WindUI:Notify({
            Title = "Hutao Hub",
            Content = "Welcome, owner!",
            Duration = 3,
            Icon = "crown"
        })
        notifiedLocalOwner = true
    end

    if not isLocalOwner and currentOwnerCount > notifiedOwnerCount then
        WindUI:Notify({
            Title = "Hutao Hub",
            Content = "An owner is in this game.",
            Duration = 3,
            Icon = "crown"
        })
        notifiedOwnerCount = currentOwnerCount
    end
end

checkOwner()

Players.PlayerAdded:Connect(function()
    task.wait(1)
    checkOwner()
end)

local ESPManager = {
    ActiveTypes = {},
    Objects = {},
    Filters = {},
    Colors = {},
    Watchers = {},
    ShowHP = {},
    _pendingCreate = {},
    _accum = 0
}

local Shared = getgenv().__HutaoShared
if not Shared then
    Shared = {}
    getgenv().__HutaoShared = Shared
end
Shared.ESP = ESPManager

local function getPrimaryPart(model)
    if model == nil then
        return nil
    end

    if model.PrimaryPart then
        return model.PrimaryPart
    end

    local p = model:FindFirstChild("HumanoidRootPart")
    if p then return p end

    p = model:FindFirstChild("Torso")
    if p then return p end

    p = model:FindFirstChild("UpperTorso")
    if p then return p end

    return model:FindFirstChildWhichIsA("BasePart")
end

local function isNPC(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum == nil then
        return false
    end
    return Players:GetPlayerFromCharacter(model) == nil
end

local function disconnectConns(tbl)
    if tbl == nil then return end
    for _, c in pairs(tbl) do
        if typeof(c) == "RBXScriptConnection" then
            pcall(function()
                c:Disconnect()
            end)
        end
    end
end

RunService.RenderStepped:Connect(function(dt)
    ESPManager._accum = ESPManager._accum + dt
    if ESPManager._accum < 0.4 then
        return
    end
    ESPManager._accum = 0

    local root = getHRP()
    if root == nil then
        return
    end

for model, data in pairs(ESPManager.Objects) do
    if model ~= nil and model.Parent ~= nil then
        local typeName = data.type
        local filterFn = ESPManager.Filters[typeName]

        if filterFn and not filterFn(model) then
            ESPManager:Remove(model)

        else
            local part = getPrimaryPart(model)
            if part ~= nil then
                if data.gui ~= nil and data.gui.Parent ~= nil
                and data.hl ~= nil and data.hl.Parent ~= nil then

                    local label = data.label
                    if label ~= nil then
                        local dist = math.floor((part.Position - root.Position).Magnitude)
                        local name = model.Name

                        if isNPC(model) then
                            name = name .. " [NPC]"
                        end

                        local text = name .. " | [" .. dist .. "m]"

                        if ESPManager.ShowHP[typeName] then
                            local hum = model:FindFirstChildOfClass("Humanoid")
                            if hum ~= nil then
                                text = text .. " | HP: " .. math.floor(hum.Health)
                            end
                        end

                        label.Text = text
                    end

                else
                    ESPManager:Remove(model)
                    ESPManager:_ScheduleCreate(model, typeName)
                end
            else
                ESPManager:Remove(model)
            end
        end
    else
        ESPManager:Remove(model)
    end
end
end)

function ESPManager:RegisterType(name, color, filterFn, showHP)
    self.Filters[name] = filterFn
    self.Colors[name] = color or Color3.new(1, 1, 1)
    self.ShowHP[name] = showHP or false
    self.ActiveTypes[name] = false
end

function ESPManager:_CreateImmediate(model, typeName)
    if model == nil or model.Parent == nil then return end
    if self.Objects[model] ~= nil then return end

    local part = getPrimaryPart(model)
    if part == nil then return end

    local color = self.Colors[typeName] or Color3.new(1, 1, 1)

    local gui = Instance.new("BillboardGui")
    gui.Name = "ESP_" .. typeName
    gui.Size = UDim2.new(0, 220, 0, 40)
    gui.AlwaysOnTop = true
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.MaxDistance = 600
    gui.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.25
    label.Font = Enum.Font.GothamBold
    label.TextSize = 16
    label.Parent = gui

    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.7
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model

    local conns = {}

    table.insert(conns, model.AncestryChanged:Connect(function()
        if not model:IsDescendantOf(Workspace) then
            ESPManager:Remove(model)
        end
    end))

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum ~= nil then
        table.insert(conns, hum.Died:Connect(function()
            ESPManager:Remove(model)
        end))
    end

    self.Objects[model] = {
        type = typeName,
        gui = gui,
        label = label,
        hl = hl,
        conns = conns
    }
end

function ESPManager:_ScheduleCreate(model, typeName)
    if model == nil then return end
    if not self.ActiveTypes[typeName] then return end
    if self._pendingCreate[model] then return end

    self._pendingCreate[model] = true
    task.delay(0.15, function()
        self._pendingCreate[model] = nil
        if model ~= nil and model.Parent ~= nil then
            local f = self.Filters[typeName]
            if f ~= nil and f(model) then
                self:_CreateImmediate(model, typeName)
            end
        end
    end)
end

function ESPManager:Remove(model)
    local d = self.Objects[model]
    if d == nil then return end

    disconnectConns(d.conns)
    pcall(function() d.gui:Destroy() end)
    pcall(function() d.hl:Destroy() end)

    self.Objects[model] = nil
    self._pendingCreate[model] = nil
end

function ESPManager:StartWatcher(typeName)
    if self.Watchers[typeName] ~= nil then return end
    local f = self.Filters[typeName]
    if f == nil then return end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if f(obj) then
            self:_ScheduleCreate(obj, typeName)
        end
    end

    self.Watchers[typeName] = {
        add = Workspace.DescendantAdded:Connect(function(obj)
            if self.ActiveTypes[typeName] and f(obj) then
                self:_ScheduleCreate(obj, typeName)
            end
        end),
        rem = Workspace.DescendantRemoving:Connect(function(obj)
            self:Remove(obj)
        end)
    }
end

function ESPManager:StopWatcher(typeName)
    local w = self.Watchers[typeName]
    if w == nil then return end
    pcall(function() w.add:Disconnect() end)
    pcall(function() w.rem:Disconnect() end)
    self.Watchers[typeName] = nil
end

function ESPManager:SetEnabled(typeName, state)
    if self.ActiveTypes[typeName] == nil then return end
    self.ActiveTypes[typeName] = state

    if state then
        self:StartWatcher(typeName)
    else
        for obj, data in pairs(self.Objects) do
            if data.type == typeName then
                self:Remove(obj)
            end
        end
        self:StopWatcher(typeName)
    end
end

local ESP = Shared.ESP
GuiClick:Init()
Window:SelectTab(1)

local Info = TabHandles["Info"]

if not ui then ui = {} end
if not ui.Creator then ui.Creator = {} end

ui.Creator.Request = function(requestData)
    local success, result = pcall(function()
        if HttpService.RequestAsync then
            local response = HttpService:RequestAsync({
                Url = requestData.Url,
                Method = requestData.Method or "GET",
                Headers = requestData.Headers or {}
            })

            return {
                Body = response.Body,
                StatusCode = response.StatusCode,
                Success = response.Success
            }
        else
            return {
                Body = HttpService:GetAsync(requestData.Url),
                StatusCode = 200,
                Success = true
            }
        end
    end)

    if success then
        return result
    end

    return nil
end

local InviteCode = "e99ewJj4t"
local DiscordAPI =
    "https://discord.com/api/v10/invites/" .. InviteCode ..
    "?with_counts=true&with_expiration=true"

local function LoadDiscordInfo()
    local response = ui.Creator.Request({
        Url = DiscordAPI,
        Method = "GET",
        Headers = {
            ["User-Agent"] = "RobloxBot/1.0",
            ["Accept"] = "application/json"
        }
    })

    if not response or not response.Success then
        return
    end

    local data = HttpService:JSONDecode(response.Body)
    if not data or not data.guild then
        return
    end

    local DiscordInfo = Info:Paragraph({
        Title = data.guild.name,
        Desc =
            ' <font color="#52525b">●</font> Member Count : ' .. tostring(data.approximate_member_count) ..
            '\n <font color="#16a34a">●</font> Online Count : ' .. tostring(data.approximate_presence_count),
        Image = "https://cdn.discordapp.com/icons/" ..
            data.guild.id .. "/" .. data.guild.icon .. ".png?size=1024",
        ImageSize = 42,
    })

    Info:Button({
        Title = "Update Info",
        Callback = function()
            local res = ui.Creator.Request({ Url = DiscordAPI })
            if not res or not res.Success then return end

            local updated = HttpService:JSONDecode(res.Body)
            if not updated or not updated.guild then return end

            DiscordInfo:SetDesc(
                ' <font color="#52525b">●</font> Member Count : ' ..
                tostring(updated.approximate_member_count) ..
                '\n <font color="#16a34a">●</font> Online Count : ' ..
                tostring(updated.approximate_presence_count)
            )

            WindUI:Notify({
                Title = "Discord Info Updated",
                Content = "Successfully refreshed Discord statistics",
                Duration = 2,
                Icon = "refresh-cw",
            })
        end
    })

    Info:Button({
        Title = "Copy Discord Invite",
        Callback = function()
            setclipboard("https://discord.gg/" .. InviteCode)
            WindUI:Notify({
                Title = "Copied!",
                Content = "Discord invite copied to clipboard",
                Duration = 2,
                Icon = "clipboard-check",
            })
        end
    })
end

LoadDiscordInfo()

Info:Divider()
Info:Section({
    Title = "Hutao Information",
    TextXAlignment = "Center",
    TextSize = 17,
})
Info:Divider()

Info:Paragraph({
    Title = "Main Owner",
    Desc = "@n1lk_v033stpe_94053",
    Image = "rbxassetid://81894031817370",
    ImageSize = 30,
})

Info:Paragraph({
    Title = "Youtube",
    Desc = "Copy link youtube for subscribe!",
    Image = "rbxassetid://122312005360431",
    ImageSize = 30,
    Buttons = {
        {
            Icon = "copy",
            Title = "Copy Link",
            Callback = function()
                setclipboard("https://www.youtube.com/@htzgamingssr")
            end
        }
    }
})

Info:Paragraph({
    Title = "Discord",
    Desc = "Join our discord for more scripts!",
    Image = "rbxassetid://109995816235688",
    ImageSize = 30,
    Buttons = {
        {
            Icon = "copy",
            Title = "Copy Link",
            Callback = function()
                setclipboard("https://discord.gg/" .. InviteCode)
            end
        }
    }
})

TabHandles.Farm:Section({ Title = "Auto", Icon = "repeat" })

local SkillRemotes = {}
local SkillButtons = {}
local SkillConnections = {}

local SkillList = {
    "Slash", "Stab", "Punch",
    "VoidRush", "Nova",
    "CorruptEnergy", "Behead", "GashingWound",
    "MassInfection", "CorruptNature", "WalkspeedOverride",
    "PizzaDelivery", "UnstableEye", "Entanglement",
    "DigitalFootprint", "404Error", "Cataclysm",
    "RagingPace", "Carving Slash", "DemonicPursuit",
    "InfernalCry", "Blood Rush", "Ascension", "Hunter'sFeast",
    "Bloodhook", "Lacerate", "BloodHunt"
}

local function findRemoteByName_safe(name)
    if not name or name == "" then return nil end
    local rs = ReplicatedStorage
    if not rs then return nil end

    local direct = rs:FindFirstChild(name)
    if direct and direct:IsA("RemoteEvent") then return direct end

    local containers = {"Remotes", "RemoteEvents", "Events"}
    for _, cName in ipairs(containers) do
        local folder = rs:FindFirstChild(cName)
        if folder and folder:IsA("Folder") then
            local candidate = folder:FindFirstChild(name)
            if candidate and candidate:IsA("RemoteEvent") then
                return candidate
            end
        end
    end

    return nil
end

local function setupSkillButtonsFromGUI()
    table.clear(SkillButtons)
    table.clear(SkillConnections)
    table.clear(SkillRemotes)

    local gui = getPlayerGui()
    if not gui then return end

    local mainUI = gui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    if not container then return end

    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("ImageButton") or child:IsA("TextButton") then
            local name = child.Name
            SkillButtons[name] = child

            local ok, conns = pcall(function() return getconnections(child.MouseButton1Click) end)
            if ok and conns then
                SkillConnections[name] = conns
                for _, con in ipairs(conns) do
                    pcall(function()
                        local f = con.Function
                        if f and islclosure(f) then
                            for i = 1, 30 do
                                local up = debug.getupvalue(f, i)
                                if typeof(up) == "Instance" and up:IsA("RemoteEvent") then
                                    SkillRemotes[name] = up
                                    break
                                end
                            end
                        end
                    end)
                    if SkillRemotes[name] then break end
                end
            else
                SkillConnections[name] = {}
            end

            if not SkillRemotes[name] then
                SkillRemotes[name] = findRemoteByName_safe(name)
            end
        end
    end
end

setupSkillButtonsFromGUI()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    setupSkillButtonsFromGUI()
end)

local function tryVirtualClick(btn)
    local ok, Vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if not ok or not Vim then return false end

    local absPos, absSize
    pcall(function()
        absPos = btn.AbsolutePosition
        absSize = btn.AbsoluteSize
    end)
    if not absPos or not absSize then return false end

    local x = absPos.X + absSize.X / 2
    local y = absPos.Y + absSize.Y / 2

    pcall(function()
        Vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.02)
        Vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    return true
end

local function triggerSkill_safe(skillName)
    if not skillName then return false end

    local conns = SkillConnections[skillName]
    if conns and #conns > 0 then
        for _, c in ipairs(conns) do
            pcall(function() c:Fire() end)
        end
        return true
    end

    local btn = SkillButtons[skillName]
    if btn then
        local suc = pcall(function() btn:Activate() end)
        if suc then return true end
    end

    if btn then
        local ok = pcall(function() return tryVirtualClick(btn) end)
        if ok then return true end
    end

    local remote = SkillRemotes[skillName]
    if remote and remote:IsA("RemoteEvent") then
        pcall(function()
            remote:FireServer(true)
            task.wait(0.005)
            remote:FireServer(false)
        end)
        return true
    end

    return false
end

local farmActive = false
local farmThread = nil
local lastAttack = 0
local CurrentTarget = nil
local PriorityList = { ["0206octavio"] = true }

local function GetPriorityTarget()
    local survivorsFolder = getSurvivorsFolder()
    if not survivorsFolder then return nil end
    for _, survivor in ipairs(survivorsFolder:GetChildren()) do
        if survivor:IsA("Model") and survivor:FindFirstChild("HumanoidRootPart") then
            if PriorityList[survivor.Name] then
                local humanoid = survivor:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    return survivor
                end
            end
        end
    end
    return nil
end

local function GetClosestSurvivor()
    local priorityTarget = GetPriorityTarget()
    if priorityTarget then return priorityTarget end

    local hrp = getHRP()
    if not hrp then return nil end

    local closest, minDist = nil, math.huge
    local survivorsFolder = getSurvivorsFolder()
    if not survivorsFolder then return nil end

    for _, survivor in ipairs(survivorsFolder:GetChildren()) do
        local humanoid = survivor:FindFirstChildOfClass("Humanoid")
        local hrp2 = survivor:FindFirstChild("HumanoidRootPart")
        if survivor:IsA("Model") and hrp2 and humanoid and humanoid.Health > 0 then
            local dist = (hrp.Position - hrp2.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = survivor
            end
        end
    end
    return closest
end

local function KillTarget(target)
    if not target then return end
    local hrp = getHRP()
    if not hrp then return end
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    if tick() - lastAttack >= 0.05 then
        lastAttack = tick()
        for _, skillName in ipairs(SkillList) do
            local offset = targetRoot.CFrame.LookVector * -2
            pcall(function()
                hrp.CFrame = targetRoot.CFrame + offset
            end)
            triggerSkill_safe(skillName)
            task.wait(0.01)
        end
    end
end

local function StartFarmLoop()
    if farmThread then return end
    farmThread = task.spawn(function()
        while farmActive do
            local hrp = getHRP()
            local char = getChar()
            if not (char and hrp) then
                CurrentTarget = nil
                task.wait(0.5)
            else
                local isKiller = false
                local killersFolder = getKillersFolder()
                if killersFolder then
                    for _, killer in ipairs(killersFolder:GetChildren()) do
                        if killer:IsA("Model") and killer.Name == char.Name then
                            isKiller = true
                            break
                        end
                    end
                end

                if not isKiller then
                    CurrentTarget = nil
                    task.wait(0.5)
                else
                    if (not CurrentTarget)
                       or (not CurrentTarget.Parent)
                       or (not CurrentTarget:FindFirstChildOfClass("Humanoid"))
                       or (CurrentTarget:FindFirstChildOfClass("Humanoid").Health <= 0) then
                        CurrentTarget = GetClosestSurvivor()
                    end

                    if CurrentTarget then
                        KillTarget(CurrentTarget)
                    end
                    task.wait(0.01)
                end
            end
        end
        farmThread = nil
    end)
end

local function StopFarmLoop()
    farmActive = false
    if farmThread then
        pcall(function() task.cancel(farmThread) end)
        farmThread = nil
    end
end

TabHandles.Farm:Toggle({
    Title = "Killers Farm V2",
    Locked = false,
    Value = false,
    Callback = function(Value)
        farmActive = Value
        if farmActive then
            StartFarmLoop()
        else
            StopFarmLoop()
        end
    end
})

local G = getgenv()
G.survivorsFarmActive = false
G.genDelay = 1.25
G.teleportThreshold = 1.5
G.CHECK_RADIUS = 2.5
G.WALL_CHECK_DIST = 3
G.SURVIVOR_DELAY = 6
G.AFTER_GEN_DELAY = 3
G.lockNextGenUntil = 0
G.currentGen = nil
G.waitingForSurvivor = false
G.survivorReadyAt = 0
G.delayNotified = false
G.farmNotified = false
G.wasSurvivor = false
G._remoteQueue = {}
G._lastRemoteFire = 0
G._SAFE_REMOTE_DELAY = 1.5

task.spawn(function()
    while true do
        if #G._remoteQueue > 0 then
            local now = os.clock()
            if now - G._lastRemoteFire >= G._SAFE_REMOTE_DELAY then
                local data = table.remove(G._remoteQueue, 1)
                pcall(data.remote.FireServer, data.remote, unpack(data.args))
                G._lastRemoteFire = now
            end
        end
        task.wait(0.05)
    end
end)

G.safeFireRemote = function(remote, ...)
    if not remote then return end
    table.insert(G._remoteQueue, {
        remote = remote,
        args = {...}
    })
end

G.notify = function(title, content)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = 3,
            Icon = "info"
        })
    end)
end

G.getValidSurvivorCharacter = function()
    local char = getChar()
    if not char then return nil end
    if not char:FindFirstChildOfClass("Humanoid") then return nil end
    local folder = getSurvivorsFolder()
    if not (folder and folder:FindFirstChild(char.Name)) then return nil end
    return char
end

G.getValidSurvivorHRP = function()
    local char = G.getValidSurvivorCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

G.isSurvivorBlocking = function(pos)
    local myChar = G.getValidSurvivorCharacter()
    local folder = getSurvivorsFolder()
    if not (myChar and folder) then return true end

    for _, model in ipairs(folder:GetChildren()) do
        if model ~= myChar then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - pos).Magnitude <= G.CHECK_RADIUS then
                return true
            end
        end
    end
    return false
end

G.isWallBlocking = function(fromPos, toPos)
    local char = G.getValidSurvivorCharacter()
    if not char then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { char }
    return workspace:Raycast(fromPos, toPos - fromPos, params) ~= nil
end

G.getBestGeneratorPosition = function(gen)
    if not gen then return nil end
    local ok, pivot = pcall(gen.GetPivot, gen)
    if not ok then return nil end

    local offsets = {
        Vector3.new(0, 0, -6),
        Vector3.new(6, 0, 0),
        Vector3.new(-6, 0, 0),
    }

    for _, off in ipairs(offsets) do
        local pos = (pivot * CFrame.new(off)).Position
        if not G.isSurvivorBlocking(pos)
        and not G.isWallBlocking(pos, pos + Vector3.new(0,0,-G.WALL_CHECK_DIST)) then
            return pos
        end
    end
    return nil
end

G.getOneUnfinishedGenerator = function()
    local map = RefreshMap()
    if not map then return nil end
    for _, gen in ipairs(map:GetChildren()) do
        if gen.Name == "Generator" then
            local prog = gen:FindFirstChild("Progress")
            if prog and prog.Value < 100 then
                return gen
            end
        end
    end
    return nil
end

G.interactGenerator = function(gen)
    if not gen then return end
    local char = G.getValidSurvivorCharacter()
    local hrp = G.getValidSurvivorHRP()
    if not (char and hrp) then return end

    local pos = G.getBestGeneratorPosition(gen)
    if pos and (hrp.Position - pos).Magnitude > G.teleportThreshold then
        pcall(char.PivotTo, char, CFrame.new(pos))
    end

    local prompt = gen:FindFirstChild("Main") and gen.Main:FindFirstChild("Prompt")
    if prompt then
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = 99999
            prompt:InputHoldBegin()
            prompt:InputHoldEnd()
        end)
    end

    local remote = getGeneratorRemote(gen)
    if remote then
        G.safeFireRemote(remote)
    end
end

if not G.farmingLoopActive then
    G.farmingLoopActive = true
    task.spawn(function()
        while G.farmingLoopActive do
            if G.survivorsFarmActive then
                local isSurvivorNow = G.getValidSurvivorCharacter() ~= nil

                if not isSurvivorNow then
                    G.wasSurvivor = false
                    G.waitingForSurvivor = false
                    G.currentGen = nil
                    G.lockNextGenUntil = 0
                end

                if isSurvivorNow then
                    if not G.wasSurvivor then
                        G.waitingForSurvivor = true
                        G.survivorReadyAt = os.clock() + G.SURVIVOR_DELAY
                        G.delayNotified = false
                        G.farmNotified = false
                    end

                    if G.waitingForSurvivor then
                        if not G.delayNotified then
                            G.notify("Hutao Hub", "Bypass Anti Cheat Start...")
                            G.delayNotified = true
                        end

                        if os.clock() >= G.survivorReadyAt then
                            G.waitingForSurvivor = false
                            if not G.farmNotified then
                                G.notify("Hutao Hub", "Bypass Anti Cheat Success!!")
                                G.farmNotified = true
                            end
                        end
                    else
                        local now = os.clock()

                        if G.currentGen then
                            local prog = G.currentGen:FindFirstChild("Progress")

                            if prog and prog.Value < 100 then
                                G.interactGenerator(G.currentGen)

                            elseif G.lockNextGenUntil == 0 then
                                G.lockNextGenUntil = now + G.AFTER_GEN_DELAY

                            elseif now >= G.lockNextGenUntil then
                                G.currentGen = nil
                                G.lockNextGenUntil = 0
                            end
                        else
                            local gen = G.getOneUnfinishedGenerator()
                            if gen then
                                G.currentGen = gen
                                G.interactGenerator(gen)
                            end
                        end
                    end
                end

                G.wasSurvivor = isSurvivorNow
            end
            task.wait(G.genDelay)
        end
    end)
end

TabHandles.Farm:Toggle({
    Title = "Survivors Farm V3",
    Locked = false,
    Value = false,
    Callback = function(v)
        G.survivorsFarmActive = v
        G.waitingForSurvivor = false
        G.survivorReadyAt = 0
        G.delayNotified = false
        G.farmNotified = false
        G.currentGen = nil
        G.lockNextGenUntil = 0
        G._remoteQueue = {}
    end
})

TabHandles.Farm:Section({ Title = "Generator", Icon = "battery-charging" })

local solveGeneratorCooldown = false
local AutoFinishGen = false
local genDelay = 1.5
local autoGenThread

local function getClosestGenerator()
    local char = getChar()
    local hrp = getHRP()
    if not (char and hrp) then return nil end

    local MapFolder = RefreshMap()
    if not MapFolder then return nil end

    local closest = nil
    local shortestDist = math.huge

    for _, obj in ipairs(MapFolder:GetChildren()) do
        if obj:IsA("Model") and obj.Name == "Generator" and obj.PrimaryPart then
            local dist = (hrp.Position - obj.PrimaryPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                closest = obj
            end
        end
    end

    return closest
end

local function finishGenerator()
    if solveGeneratorCooldown then return end

    local gen = getClosestGenerator()
    local remote = gen and getGeneratorRemote(gen)
    if not remote then return end

    solveGeneratorCooldown = true
    remote:FireServer()

    task.delay(genDelay, function()
        solveGeneratorCooldown = false
    end)
end

TabHandles.Farm:Button({
    Title = "Finish Generator",
    Callback = function()
        if AutoFinishGen then return end
        finishGenerator()
    end
})

TabHandles.Farm:Toggle({
    Title = "Auto Finish Generator",
    Locked = false,
    Value = false,
    Callback = function(state)
        AutoFinishGen = state

        if autoGenThread then
            task.cancel(autoGenThread)
            autoGenThread = nil
        end

        if state then
            autoGenThread = task.spawn(function()
                while AutoFinishGen do
                    finishGenerator()
                    task.wait(0.1)
                end
            end)
        else
            solveGeneratorCooldown = false
        end
    end
})

TabHandles.Farm:Input({
    Title = "Generator Delay",
    Placeholder = "1.5 - 10",
    Value = tostring(genDelay),
    Numeric = true,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            genDelay = math.clamp(num, 1.5, 10)
        end
    end
})

TabHandles.Farm:Section({ Title = "Items", Icon = "backpack" })

local function pickUpNearest()
    local map = MapFolder or WaitForMap()
    if not map then return end

    local char = getChar()
    local hrp = getHRP()
    if not char or not hrp then return end

    local root = hrp
    local oldCFrame = root.CFrame

    for _, item in ipairs(map:GetChildren()) do
        if item:IsA("Tool")
            and item:FindFirstChild("ItemRoot")
            and item.ItemRoot:FindFirstChild("ProximityPrompt") then

            root.CFrame = item.ItemRoot.CFrame
            task.wait(0.3)
            
            pcall(function()
                fireproximityprompt(item.ItemRoot.ProximityPrompt)
            end)
            
            task.wait(0.4)
            root.CFrame = oldCFrame
            break
        end
    end
end

TabHandles.Farm:Button({
    Title = "Pick Up Item",
    Callback = function()
        pickUpNearest()
    end
})

TabHandles.Farm:Toggle({
    Title = "Auto PickUp Item",
    Locked = false,
    Value = false,
    Callback = function(state)
        _G.PickupItem = state
        if not state then return end

        task.spawn(function()
            while _G.PickupItem do
                pickUpNearest()
                task.wait(0.2)
            end
        end)
    end
})

TabHandles.Survivors:Section({ Title = "Dusekkar", Icon = "zap" })

local skillList = { 77894750279891 }

_G.DusekAimEnabled = _G.DusekAimEnabled or false
_G.DusekAimMode = _G.DusekAimMode or 1

local isAiming = false
local currentTrack = nil
local renderLoop = nil

local camBackup = {
    cf = nil,
    fov = nil,
    camType = nil,
    camMode = nil
}

local function normalize(id)
    return tostring(id):gsub("%D","")
end

local function isSkill(animId)
    if not animId then return false end
    local clean = normalize(animId)
    for _,v in ipairs(skillList) do
        if tostring(v) == clean then
            return true
        end
    end
    return false
end

local function anchorCF()
    local char = getChar()
    if not char then return nil end

    local h = char:FindFirstChild("Head")
    if h then return h.CFrame end

    local hrp = getHRP()
    if hrp then return hrp.CFrame + Vector3.new(0,1.5,0) end
    return nil
end

local lastScan = 0
local cachedTarget = nil

local function findNearest(list)
    local myHRP = getHRP()
    if not myHRP then return nil end

    local myPos = myHRP.Position
    local best = nil
    local bestDist = math.huge

    for _, model in ipairs(list) do
        if model:IsA("Model") and model ~= getChar() then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hrp and (not hum or hum.Health > 0) then
                local d = (hrp.Position - myPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = hrp
                end
            end
        end
    end

    return best
end

local function getTarget()
    local now = tick()
    if now - lastScan < 0.15 then
        return cachedTarget
    end
    lastScan = now

    local folder = (_G.DusekAimMode == 1) and getKillersFolder() or getSurvivorsFolder()
    if not folder then return nil end

    cachedTarget = findNearest(folder:GetChildren())
    return cachedTarget
end

local function ensureRender()
    if renderLoop then return end

    renderLoop = RunService.RenderStepped:Connect(function()
        if not isAiming or not _G.DusekAimEnabled then return end

        local anch = anchorCF()
        if not anch then return end

        local t = getTarget()
        if t then
            Camera.CFrame = CFrame.new(anch.Position, t.Position)
        else
            Camera.CFrame = CFrame.new(anch.Position, anch.Position + anch.LookVector * 15)
        end
    end)
end

local function startAim()
    if isAiming or not _G.DusekAimEnabled then return end

    local a = anchorCF()
    if not a then return end

    isAiming = true

    camBackup.cf = Camera.CFrame
    camBackup.fov = Camera.FieldOfView
    camBackup.camType = Camera.CameraType
    camBackup.camMode = LocalPlayer.CameraMode

    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.FieldOfView = 50
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

    ensureRender()
end

local function stopAim()
    if not isAiming then return end
    isAiming = false

    Camera.CameraType = camBackup.camType or Enum.CameraType.Custom
    Camera.FieldOfView = camBackup.fov or 70
    Camera.CFrame = camBackup.cf or Camera.CFrame
    LocalPlayer.CameraMode = camBackup.camMode or Enum.CameraMode.Classic

    cachedTarget = nil
end

local function attachHumanoid(hum)
    if hum:GetAttribute("DusekBound") then return end
    hum:SetAttribute("DusekBound", true)

    hum.AnimationPlayed:Connect(function(track)
        local id
        pcall(function()
            id = track.Animation and track.Animation.AnimationId or track.AnimationId
        end)

        if id and isSkill(id) then
            currentTrack = track
            if _G.DusekAimEnabled then startAim() end

            track.Stopped:Connect(function()
                if currentTrack == track then stopAim() end
            end)
        end
    end)
end

local function bindCharacter(char)
    local hum = char:FindFirstChild("Humanoid") or char:WaitForChild("Humanoid",3)
    if hum then attachHumanoid(hum) end
end

if LocalPlayer.Character then
    bindCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.defer(function()
        bindCharacter(char)
    end)
end)

TabHandles.Survivors:Dropdown({
    Title = "Aim Mode",
    Values = { "Aim Killers", "Aim Survivors" },
    Value = (_G.DusekAimMode == 2 and "Aim Survivors") or "Aim Killers",
    Callback = function(v)
        _G.DusekAimMode = (v == "Aim Killers" and 1) or 2
        cachedTarget = nil
    end
})

TabHandles.Survivors:Toggle({
    Title = "Dusekkar Aimlock",
    Locked = false,
    Value = _G.DusekAimEnabled,
    Callback = function(v)
        _G.DusekAimEnabled = v
        if v and currentTrack and currentTrack.IsPlaying then
            startAim()
        else
            stopAim()
        end
    end
})

TabHandles.Survivors:Section({ Title = "Eliot", Icon = "pizza" })

local toggleFlag = Instance.new("BoolValue")
toggleFlag.Name = "EliotPizzaAim_ToggleFlag"
toggleFlag.Value = false

TabHandles.Survivors:Toggle({
    Title = "Pizza Aimbot",
    Locked = false,
    Value = toggleFlag.Value,
    Callback = function(state)
        toggleFlag.Value = state
    end
})

local maxDistance = 100
TabHandles.Survivors:Input({
    Title = "Aim Distance",
    Value = tostring(maxDistance),
    Placeholder = "Enter Number",
    Callback = function(v)
        local n = tonumber(v)
        if n then maxDistance = n end
    end
})

local PizzaAnimation = {
    ["114155003741146"] = true,
    ["104033348426533"] = true
}
local EliotModels = { ["Elliot"] = true }
local autoRotateDisabledByScript = false
local currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
local aimOffset = 2

local function getSurvivors()
    return getSurvivorsFolder() or (Workspace:FindFirstChild("Players") and Workspace.Players:FindFirstChild("Survivors"))
end

local function isEliot()
    local c = getChar()
    return c and EliotModels[c.Name] or false
end

local function restoreAutoRotate()
    local hum = getHumanoid()
    if hum and autoRotateDisabledByScript then
        hum.AutoRotate = true
        autoRotateDisabledByScript = false
    end
end

local function isPlayingDangerousAnimation()
    local hum = getHumanoid()
    if not hum then return false end
    local animator = hum:FindFirstChildWhichIsA("Animator")
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local animId = track.Animation and tostring(track.Animation.AnimationId):match("%d+")
        if animId and PizzaAnimation[animId] then
            return true
        end
    end
    return false
end

local function getWeakestSurvivor()
    local survivors = getSurvivors()
    if not survivors then return nil end
    local myChar = getChar()
    local myHum = getHumanoid()
    local myRoot = getHRP()
    if not myHum or not myRoot or not myHum.MaxHealth or myHum.MaxHealth <= 0 then return nil end

    local myHpPercent = myHum.Health / myHum.MaxHealth
    local list = {}

    for _, mdl in ipairs(survivors:GetChildren()) do
        if mdl:IsA("Model") and mdl ~= myChar then
            local hum = mdl:FindFirstChildWhichIsA("Humanoid")
            local hrp = mdl:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and hum.MaxHealth > 0 then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                if dist <= maxDistance then
                    table.insert(list, { model = mdl, hp = hum.Health / hum.MaxHealth })
                end
            end
        end
    end

    if #list == 0 then return nil end
    table.sort(list, function(a,b) return a.hp < b.hp end)

    if myHpPercent <= list[1].hp and #list > 1 then
        return list[2].model
    else
        return list[1].model
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    autoRotateDisabledByScript = false
end)

RunService.RenderStepped:Connect(function()
    if not toggleFlag.Value then
        restoreAutoRotate()
        currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
        return
    end

    if not isEliot() then
        restoreAutoRotate()
        currentTarget, isLockedOn, wasPlayingAnimation = nil, false, false
        return
    end

    local hum = getHumanoid()
    local root = getHRP()
    if not hum or not root then return end

    local playing = isPlayingDangerousAnimation()

    if playing and not isLockedOn then
        currentTarget = getWeakestSurvivor()
        if currentTarget then isLockedOn = true end
    end

    if isLockedOn and currentTarget then
        local tHum = currentTarget:FindFirstChildWhichIsA("Humanoid")
        local tRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if not (tHum and tRoot and tHum.Health > 0) then
            currentTarget, isLockedOn = nil, false
        end
    end

    if (not playing) and wasPlayingAnimation then
        currentTarget, isLockedOn = nil, false
        restoreAutoRotate()
    end
    wasPlayingAnimation = playing

    if playing and isLockedOn and currentTarget then
        local tRoot = currentTarget:FindFirstChild("HumanoidRootPart")
        if tRoot then
            if not autoRotateDisabledByScript then
                hum.AutoRotate = false
                autoRotateDisabledByScript = true
            end

            local targetCFrame = CFrame.new(Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z) + root.CFrame.RightVector * aimOffset)
            AimSystem.RotateTo(targetCFrame, 0.99)
        end
    end
end)

getgenv().BlinkToPizzaToggle = getgenv().BlinkToPizzaToggle or false
TabHandles.Survivors:Toggle({
    Title = "Auto Eat Pizza",
    Locked = false,
    Value = getgenv().BlinkToPizzaToggle,
    Callback = function(s)
        getgenv().BlinkToPizzaToggle = s
    end
})

getgenv().HPThreshold = getgenv().HPThreshold or 30
TabHandles.Survivors:Input({
    Title = "HP Threshold",
    Value = tostring(getgenv().HPThreshold),
    Placeholder = "30",
    Callback = function(v)
        local n = tonumber(v)
        if n then getgenv().HPThreshold = n end
    end
})

local function getPizzaCF()
    local map = RefreshMap() or WaitForMap()
    if not map then return nil end

    local pizza = map:FindFirstChild("Pizza")
    if not pizza then return nil end

    if pizza:IsA("BasePart") or pizza:IsA("MeshPart") or pizza:IsA("UnionOperation") then
        return pizza.CFrame
    elseif pizza:IsA("Model") then
        local pp = pizza.PrimaryPart or pizza:FindFirstChildWhichIsA("BasePart")
        if pp then
            if not pizza.PrimaryPart then pizza.PrimaryPart = pp end
            return pp.CFrame
        end
    elseif pizza:IsA("CFrameValue") then
        return pizza.Value
    end
    return nil
end

task.spawn(function()
    while task.wait(0.9) do
        if getgenv().BlinkToPizzaToggle then
            local hrp = getHRP()
            local hum = getHumanoid()
            if hrp and hum then
                local pizzaCF = getPizzaCF()
                if pizzaCF and hum.Health <= getgenv().HPThreshold then
                    local old = hrp.CFrame
                    hrp.CFrame = pizzaCF * CFrame.new(0, 1, 0)

                    if getgenv().activateRemoteHook then
                        getgenv().activateRemoteHook("UnreliableRemoteEvent", "UpdCF")
                    end

                    task.delay(0.2, function()
                        hrp.CFrame = old
                        task.wait(0.3)
                        if getgenv().deactivateRemoteHook then
                            getgenv().deactivateRemoteHook("UnreliableRemoteEvent", "UpdCF")
                        end
                    end)
                end
            end
        end
    end
end)

TabHandles.Survivors:Section({ Title = "Two Time", Icon = "shuffle" })

local Mode = "AI Aimbot"
local enabled = false
local checkRadius = 18
local backstabDelay = 0.01
local killersFolder = getKillersFolder()

local ANIM_IDS = {
    "115194624791339",
    "86545133269813",
    "89448354637442",
    "77119710693654",
    "107640065977686",
    "112902284724598",
}

TabHandles.Survivors:Dropdown({
    Title = "Backstab Mode",
    Values = { "AI Aimbot", "Player Aimbot", "AI Aimbot Pro" },
    Value = Mode,
    Callback = function(v)
        Mode = v
    end
})

TabHandles.Survivors:Toggle({
    Title = "Auto Backstab V2",
    Locked = false,
    Value = false,
    Callback = function(v)
        enabled = v
    end
})

TabHandles.Survivors:Input({
    Title = "Check Radius",
    Placeholder = "1 - 50",
    Value = tostring(checkRadius),
    Numeric = true,
    Callback = function(v)
        local n = tonumber(v)
        if n then
            checkRadius = math.clamp(n, 1, 50)
        end
    end
})

local function isPlayingTargetAnimation(h)
    if not h then return false end
    for _, track in ipairs(h:GetPlayingAnimationTracks()) do
        local id = tostring(track.Animation.AnimationId or "")
        for _, a in ipairs(ANIM_IDS) do
            if id:find(a, 1, true) then
                return true
            end
        end
    end
    return false
end

local function teleportBehind(targetHRP, myHRP)
    local look = targetHRP.CFrame.LookVector
    local pos = targetHRP.Position - look * 2
    myHRP.CFrame = CFrame.new(pos, pos + look)
end

local function isBehindTarget(targetHRP, myHRP)
    local look = targetHRP.CFrame.LookVector
    local dir = (myHRP.Position - targetHRP.Position).Unit
    return look:Dot(dir) < -0.5
end

local function getNearbyPlayers(pos)
    local t = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - pos).Magnitude
                if d <= checkRadius then
                    t[#t + 1] = { model = plr.Character, hrp = hrp, dist = d }
                end
            end
        end
    end
    return t
end

local function getNearbyAI(myHRP)
    local t = {}
    if not killersFolder or not killersFolder.Parent then
        killersFolder = getKillersFolder()
    end
    if not killersFolder then return t end

    for _, k in ipairs(killersFolder:GetChildren()) do
        local hrp = k:FindFirstChild("HumanoidRootPart")
        if hrp then
            local d = (hrp.Position - myHRP.Position).Magnitude
            if d <= checkRadius then
                t[#t + 1] = { model = k, hrp = hrp, dist = d }
            end
        end
    end
    return t
end

local function dashBehind(targetHRP, humanoid, myHRP)
    local dest = targetHRP.Position - targetHRP.CFrame.LookVector * 1.2
    if not pcall(function()
        humanoid:MoveTo(dest)
    end) then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = (dest - myHRP.Position).Unit * 60
        bv.Parent = myHRP
        task.delay(0.15, function()
            if bv then bv:Destroy() end
        end)
    end
end

local state = "idle"
local stateTime = 0
local currentTarget = nil
local lastTarget = nil
local lastHit = 0
local dashed = false

RunService.Heartbeat:Connect(function(dt)
    if not enabled then
        state = "idle"
        currentTarget = nil
        return
    end

    local char = getChar()
    local hum = getHumanoid()
    local myHRP = getHRP()
    if not (char and hum and myHRP) then return end
    if char.Name ~= "TwoTime" then return end

    if state == "idle" then
        local list

        if Mode == "Player Aimbot" then
            if not isPlayingTargetAnimation(hum) then return end
            list = getNearbyPlayers(myHRP.Position)
        else
            list = getNearbyAI(myHRP)
        end

        if #list == 0 then return end
        table.sort(list, function(a, b)
            return a.dist < b.dist
        end)

        local t = list[1]
        if t.model == lastTarget then return end
        if Mode ~= "Player Aimbot" and not isBehindTarget(t.hrp, myHRP) then return end

        currentTarget = t
        lastTarget = t.model
        state = "attack"
        stateTime = tick()
        dashed = false
        lastHit = 0
        return
    end

    if state == "attack" then
        if not (currentTarget and currentTarget.hrp and currentTarget.hrp.Parent) then
            state = "idle"
            return
        end

        if tick() - stateTime > 0.7 then
            state = "cooldown"
            task.delay(Mode == "Player Aimbot" and 1 or 10, function()
                state = "idle"
                lastTarget = nil
            end)
            return
        end

        if Mode ~= "AI Aimbot Pro" then
            teleportBehind(currentTarget.hrp, myHRP)
        end

        if Mode == "AI Aimbot Pro" then
            AimSystem.RotateTo(
                currentTarget.hrp.CFrame,
                math.clamp(0.9 + dt * 1.2, 0.1, 1)
            )

            if not dashed then
                dashed = true
                dashBehind(currentTarget.hrp, hum, myHRP)
            end

            if tick() - lastHit >= backstabDelay then
                lastHit = tick()
                GuiClick:Use("Dagger")
            end
        else
            GuiClick:Use("Dagger")
        end
    end
end)

TabHandles.Survivors:Section({ Title = "007n7", Icon = "ghost" })

local ANIM_ID = "rbxassetid://75804462760596"
local InvisibleTrack = nil

local InstantInvisibleEnabled = false
local CloneInvisibleEnabled = false

local function getHumanoid()
    local char = getChar()
    return char and char:FindFirstChildOfClass("Humanoid"), char
end

local function getAnimator(humanoid)
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end
    return animator
end

local function playAnim(humanoid)
    if not humanoid then return end
    if InvisibleTrack and InvisibleTrack.IsPlaying then return end

    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID

    local animator = getAnimator(humanoid)
    InvisibleTrack = animator:LoadAnimation(anim)
    InvisibleTrack.Looped = true
    InvisibleTrack:Play()
    InvisibleTrack:AdjustSpeed(0)
end

local function stopAnim()
    if InvisibleTrack then
        pcall(function()
            InvisibleTrack:Stop()
        end)
        InvisibleTrack = nil
    end
end

local function applyInstantInvisible()
    if not InstantInvisibleEnabled then return end

    local humanoid, char = getHumanoid()
    if not humanoid or not char then return end

    local survivorsFolder = getSurvivorsFolder()
    if survivorsFolder and survivorsFolder:FindFirstChild(char.Name) then
        playAnim(humanoid)
    else
        stopAnim()
    end
end

local function applyCloneInvisible()
    if not CloneInvisibleEnabled then return end

    local humanoid, char = getHumanoid()
    if not char then return end

    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if torso and torso.Transparency ~= 0 then
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.Transparency = 0.4
        end
    else
        if char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.Transparency = 1
        end
    end
end

RunService.Heartbeat:Connect(function()
    applyInstantInvisible()
    applyCloneInvisible()
end)

TabHandles.Survivors:Toggle({
    Title = "Instant Invisible",
    Locked = false,
    Value = false,
    Callback = function(v)
        InstantInvisibleEnabled = v
        if not v then
            stopAnim()
        end
    end
})

TabHandles.Survivors:Toggle({
    Title = "Invisible If Cloned",
    Locked = false,
    Value = false,
    Callback = function(v)
        CloneInvisibleEnabled = v
        if not v then
            local _, char = getHumanoid()
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.Transparency = 1
            end
        end
    end
})

TabHandles.Survivors:Section({ Title = "Veeronica", Icon = "wind" })

TabHandles.Survivors:Toggle({
    Title = "Auto Trick V2",
    Locked = false,
    Value = false,
    Callback = function(Value)
        local device = "Mobile"

        local function getBehaviorFolder()
            local ok, folder = pcall(function()
                return ReplicatedStorage.Assets.Survivors.Veeronica.Behavior
            end)
            return ok and folder
        end

        local function getSprintingButton()
            local gui = getPlayerGui()
            if not gui then return end
            local main = gui:FindFirstChild("MainUI")
            if not main then return end
            return main:FindFirstChild("SprintingButton")
        end

        local function adorneeIsPlayerCharacter(h)
            if not h then return false end
            local adornee = h.Adornee
            local char = getChar()
            if not adornee or not char then return false end
            return adornee == char or adornee:IsDescendantOf(char)
        end

        local function triggerSprint()
            if device ~= "Mobile" then return end
            local btn = getSprintingButton()
            if not btn then return end
            local conns = getconnections(btn.MouseButton1Down)
            for _, v in pairs(conns) do
                pcall(function()
                    v:Fire()
                    if v.Function then v:Function() end
                end)
            end
        end

        local function cleanup()
            if _G.AutoTrick_Connections then
                for _, conn in ipairs(_G.AutoTrick_Connections) do
                    if conn and conn.Connected then
                        conn:Disconnect()
                    end
                end
                _G.AutoTrick_Connections = nil
            end
            if _G.AutoTrick_Loop then
                task.cancel(_G.AutoTrick_Loop)
                _G.AutoTrick_Loop = nil
            end
            print("[AutoTrick] Disabled")
        end

        if Value then
            print("[AutoTrick] Enabled")

            local behaviorFolder = getBehaviorFolder()
            if not behaviorFolder then
                warn("[AutoTrick] Behavior folder not found.")
                return
            end

            local highlights = {}
            _G.AutoTrick_Connections = {}

            local addConn = behaviorFolder.DescendantAdded:Connect(function(child)
                if child:IsA("Highlight") then
                    highlights[child] = true
                end
            end)

            local removeConn = behaviorFolder.DescendantRemoving:Connect(function(child)
                if child:IsA("Highlight") then
                    highlights[child] = nil
                end
            end)

            table.insert(_G.AutoTrick_Connections, addConn)
            table.insert(_G.AutoTrick_Connections, removeConn)

            _G.AutoTrick_Loop = task.spawn(function()
                while task.wait(0.3) do
                    if not Value then break end
                    for h in pairs(highlights) do
                        if adorneeIsPlayerCharacter(h) then
                            triggerSprint()
                            break
                        end
                    end
                end
            end)
        else
            cleanup()
        end
    end
})

TabHandles.Survivors:Section({ Title = "Chance", Icon = "bitcoin" })

_G.AIMBOT_ACTIVE = false
_G.AIM_USE_OFFSET = true
_G.AIM_PREDICTION_MODE = "Speed"
_G.AIM_MODE = "Normal"
_G.AIM_DURATION = 1.7
_G.AIM_FASTER_DURATION = 1.5
_G.AIM_SPIN_DURATION = 0.5

_G.AIMING = false
_G.PREV_FLINT_VISIBLE = false
_G.LAST_TRIGGER = 0

_G.AUTO_COINFLIP = false
_G.COINFLIP_TARGET_CHARGE = 3
_G.COINFLIP_COOLDOWN = 0.15
_G.LAST_COINFLIP = 0
_G.BLOCK_COINFLIP_WHEN_CLOSE = true
_G.COINFLIP_BLOCK_DIST = 50

_G._AIM_REMOTE_EVENT = nil
pcall(function()
    _G._AIM_REMOTE_EVENT = ReplicatedStorage:WaitForChild("Modules")
        :WaitForChild("Network")
        :WaitForChild("RemoteEvent")
end)

function AC_GetValidTargetPart()
    local killers = getKillersFolder()
    if not killers then return nil end
    for i = 1, #killers:GetChildren() do
        local model = killers:GetChildren()[i]
        if model then
            local part = model:FindFirstChild("HumanoidRootPart")
            if part and part:IsA("BasePart") then
                return part
            end
        end
    end
    return nil
end

function AC_GetPingSeconds()
    local ok, stat = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"] end)
    if not ok or not stat then return 0.1 end
    local ok2, v = pcall(function() return stat:GetValue() end)
    if ok2 and type(v) == "number" then
        return v / 1000
    end
    return 0.1
end

function AC_IsFlintlockVisible()
    local ok, char = pcall(function() return getChar() end)
    if not ok or not char then return false end
    local success, flint = pcall(function() return char:FindFirstChild("Flintlock", true) end)
    if not success or not flint then return false end
    if not flint:IsA("BasePart") then return false end
    return flint.Transparency < 1
end

function AC_GetPredictedPos(targetHRP)
    if not targetHRP then return nil end
    local ping = AC_GetPingSeconds()

    local mode = _G.AIM_PREDICTION_MODE or "Speed"
    if mode == "Ping" then
        return targetHRP.Position + (targetHRP.Velocity or Vector3.zero) * ping
    elseif mode == "front" then
        return targetHRP.Position + (targetHRP.CFrame and targetHRP.CFrame.LookVector or Vector3.new()) * 4
    elseif mode == "No Lag" then
        return targetHRP.Position + (targetHRP.CFrame and targetHRP.CFrame.LookVector or Vector3.new()) * (ping * 60)
    else
        if _G.AIM_USE_OFFSET then
            return targetHRP.Position + (targetHRP.Velocity or Vector3.zero) * (4 / 60)
        else
            return targetHRP.Position
        end
    end
end

function AC_GetAbilityContainer()
    local ok, gui = pcall(function() return getPlayerGui() end)
    if not ok or not gui then return nil end
    local main = gui:FindFirstChild("MainUI")
    if not main then return nil end
    return main:FindFirstChild("AbilityContainer")
end

function AC_SafeClick(btn)
    if not btn then return end
    pcall(function()
        if btn.Activate then
            btn:Activate()
        end
    end)
    if pcall(function() return btn:IsA("GuiButton") end) then
        pcall(function() firesignal(btn.MouseButton1Click) end)
    end
    pcall(function()
        btn.Selectable = true
        btn.Modal = false
    end)
end

function AC_FindCoinflipButton()
    local container = AC_GetAbilityContainer()
    if not container then return nil end
    for i = 1, #container:GetDescendants() do
        local obj = container:GetDescendants()[i]
        if not obj then break end
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local n = tostring(obj.Name):lower()
            local t = (pcall(function() return obj.Text end) and tostring(obj.Text):lower()) or ""
            if n:find("coin") or n:find("flip") or t:find("coin") or t:find("flip") then
                return obj
            end
        end
    end
    return nil
end

function AC_GetNearbyMaxNumber()
    local container = AC_GetAbilityContainer()
    if not container then return nil end
    local maxNum = nil
    for i = 1, #container:GetDescendants() do
        local obj = container:GetDescendants()[i]
        if not obj then break end
        if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and pcall(function() return obj.Text end) then
            local text = tostring(obj.Text):lower()
            if not text:find("s") then
                for num in text:gmatch("%d+") do
                    local n = tonumber(num)
                    if n and n >= 1 and n <= 10 then
                        if not maxNum or n > maxNum then
                            maxNum = n
                        end
                    end
                end
            end
        end
    end
    return maxNum
end

TabHandles.Survivors:Dropdown({
    Title = "Aim Mode",
    Values = {"Normal", "Faster", "Reflex"},
    Value = _G.AIM_MODE,
    Callback = function(val)
        _G.AIM_MODE = val
    end
})

TabHandles.Survivors:Dropdown({
    Title = "Prediction Mode",
    Values = {"Speed", "Ping", "front", "No Lag"},
    Value = _G.AIM_PREDICTION_MODE,
    Callback = function(val)
        _G.AIM_PREDICTION_MODE = val
    end
})

TabHandles.Survivors:Dropdown({
    Title = "Coinflip Target",
    Values = {"1 Point", "2 Point", "3 Point"},
    Value = tostring(_G.COINFLIP_TARGET_CHARGE).." Point",
    Callback = function(val)
        local num = tonumber(val:match("%d+"))
        if num then _G.COINFLIP_TARGET_CHARGE = num end
    end
})

TabHandles.Survivors:Input({
    Title = "Anti Killers Distance",
    Value = tostring(_G.COINFLIP_BLOCK_DIST),
    Placeholder = "Enter Distance",
    Callback = function(val)
        local num = tonumber(val)
        if num then _G.COINFLIP_BLOCK_DIST = num end
    end
})

TabHandles.Survivors:Toggle({
    Title = "Anti Killers",
    Locked = false,
    Value = _G.BLOCK_COINFLIP_WHEN_CLOSE,
    Callback = function(state)
        _G.BLOCK_COINFLIP_WHEN_CLOSE = state
    end
})

TabHandles.Survivors:Toggle({
    Title = "Enable Offset",
    Locked = false,
    Value = _G.AIM_USE_OFFSET,
    Callback = function(state)
        _G.AIM_USE_OFFSET = state
    end
})

TabHandles.Survivors:Toggle({
    Title = "Auto Aim Shoot",
    Locked = false,
    Value = _G.AIMBOT_ACTIVE,
    Callback = function(state)
        _G.AIMBOT_ACTIVE = state
    end
})

TabHandles.Survivors:Toggle({
    Title = "Auto Coin Flip",
    Locked = false,
    Value = _G.AUTO_COINFLIP,
    Callback = function(state)
        _G.AUTO_COINFLIP = state
    end
})

spawn(function()
    local POLL_RATE = 0.03

    while task.wait(POLL_RATE) do
        if _G.AIMBOT_ACTIVE and getHumanoid() and getHRP() then
            local visible = AC_IsFlintlockVisible()

            if visible and not _G.PREV_FLINT_VISIBLE and not _G.AIMING then
                _G.AIMING = true
                _G.LAST_TRIGGER = tick()
            end

            _G.PREV_FLINT_VISIBLE = visible

            if _G.AIMING then
                local elapsed = tick() - (_G.LAST_TRIGGER or 0)
                local duration = (_G.AIM_MODE == "Faster") and _G.AIM_FASTER_DURATION or _G.AIM_DURATION

                if _G.AIM_MODE == "Reflex" and elapsed <= _G.AIM_SPIN_DURATION then
                    local a = math.rad(360 * (elapsed / _G.AIM_SPIN_DURATION))
                    local me = getHRP()
                    if me then
                        pcall(function() me.CFrame = CFrame.new(me.Position) * CFrame.Angles(0, a, 0) end)
                    end
                elseif elapsed <= duration then
                    local humanoid = getHumanoid()
                    if humanoid then pcall(function() humanoid.AutoRotate = false end) end

                    local targetPart = AC_GetValidTargetPart()
                    if targetPart then
                        local predicted = AC_GetPredictedPos(targetPart)
                        if predicted then
                            pcall(function()
                                if type(AimSystem) == "table" and type(AimSystem.RotateTo) == "function" then
                                    AimSystem.RotateTo(CFrame.new(predicted), 0.99)
                                else
                                    local me = getHRP()
                                    if me then me.CFrame = CFrame.lookAt(me.Position, predicted) end
                                end
                            end)
                        end
                    end
                else
                    _G.AIMING = false
                    local humanoid = getHumanoid()
                    if humanoid then pcall(function() humanoid.AutoRotate = true end) end
                end
            end
        end

        if _G.AUTO_COINFLIP then
            local block = false
            if _G.BLOCK_COINFLIP_WHEN_CLOSE then
                local tp = AC_GetValidTargetPart()
                local me = getHRP()
                if tp and me then
                    local ok, d = pcall(function() return (tp.Position - me.Position).Magnitude end)
                    if ok and d and d <= _G.COINFLIP_BLOCK_DIST then
                        block = true
                    end
                end
            end

            if not block and tick() - (_G.LAST_COINFLIP or 0) >= _G.COINFLIP_COOLDOWN then
                local maxNum = AC_GetNearbyMaxNumber()
                if not maxNum or maxNum < (_G.COINFLIP_TARGET_CHARGE or 3) then
                    _G.LAST_COINFLIP = tick()
                    GuiClick:Use("CoinFlip")
                end
            end
        end
    end
end)

TabHandles.Survivors:Section({ Title = "Guest1337", Icon = "shield-check" })

function isKiller(player)
    local ok, killersFolder = pcall(getKillersFolder)
    if not ok or not killersFolder or not player then return false end

    if killersFolder:FindFirstChild(player.Name) then return true end

    local char = player.Character
    if char and killersFolder:FindFirstChild(char.Name) then return true end
    return false
end

animationIds = {
        ["83829782357897"]  = true,
        ["126830014841198"] = true,
        ["126355327951215"] = true,
        ["121086746534252"] = true,
        ["105458270463374"] = true,
        ["18885909645"]     = true,
        ["94162446513587"]  = true,
        ["93069721274110"]  = true,
        ["97433060861952"]  = true,
        ["121293883585738"] = true,
        ["92173139187970"]  = true,
        ["106847695270773"] = true,
        ["125403313786645"] = true,
        ["81639435858902"]  = true,
        ["137314737492715"] = true,
        ["120112897026015"] = true,
        ["82113744478546"]  = true,
        ["118298475669935"] = true,
        ["126681776859538"] = true,
        ["129976080405072"] = true,
        ["109667959938617"] = true,
        ["74707328554358"]  = true,
        ["133336594357903"] = true,
        ["86204001129974"]  = true,
        ["70371667919898"]  = true,
        ["131543461321709"] = true,
        ["106776364623742"] = true,
        ["136323728355613"] = true,
        ["109230267448394"] = true,
        ["139835501033932"] = true,
        ["114356208094580"] = true,
        ["106538427162796"] = true,
        ["126896426760253"] = true,
        ["126171487400618"]  = true,
        ["97167027849946"]  = true,
        ["99135633258223"]  = true,
        ["98456918873918"]  = true,
        ["83251433279852"]  = true,
        ["126681776859538"] = true,
        ["129976080405072"] = true,
        ["122709416391891"] = true,
        ["87989533095285"] = true,
        ["139309647473555"] = true,
        ["133363345661032"] = true,
        ["128414736976503"] = true,
        ["77375846492436"] = true,
        ["92445608014276"] = true,
        ["100358581940485"] = true,
        ["91758760621955"] = true,
        ["94634594529334"] = true,
        ["90620531468240"] = true,
        ["94958041603347"] = true,
        ["131642454238375"] = true,
        ["110702884830060"] = true,
        ["76312020299624"] = true,
        ["126654961540956"] = true,
        ["139613699193400"] = true,
        ["91509234639766"] = true,
        ["105458270463374"] = true,
        ["114506382930939"] = true,
        ["82113036350227"] = true,
        ["88451353906104"] = true,
        ["99829427721752"] = true,
}

massInfectionIds = {
    ["131430497821198"] = true,
    ["100592913030351"] = true,
    ["70447634862911"]  = true,
    ["83685305553364"]  = true,
    ["101101433684051"] = true,
    ["109777684604906"] = true,
    ["104897856211468"] = true,
}

delayedAnimations = {}

toggleOn = false
strictRangeOn = false
detectionRange = 18
showCircleOn = true

blockRemote = nil
blockButton = nil
connections = {}

function findBlockRemote()
    if blockRemote then return blockRemote end
    if not blockButton then return nil end

    local ok, conns = pcall(function()
        return getconnections(blockButton.MouseButton1Click)
    end)
    if not ok or not conns then return nil end

    for i = 1, #conns do
        local conn = conns[i]
        local f = conn and conn.Function
        if f and islclosure(f) then
            local ok2, ups = pcall(getupvalues, f)
            if ok2 and ups then
                for _, v in pairs(ups) do
                    if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
                        blockRemote = v
                        return blockRemote
                    end
                end
            end
        end
    end
    return nil
end

function initBlockButton()
    local gui = getPlayerGui()
    if not gui then return end

    local mainUI = gui:FindFirstChild("MainUI")
    local container = mainUI and mainUI:FindFirstChild("AbilityContainer")
    blockButton = container and container:FindFirstChild("Block")

    if blockButton and blockButton:IsA("ImageButton") then
        pcall(function()
            connections = getconnections(blockButton.MouseButton1Click)
        end)
        findBlockRemote()
    end
end

initBlockButton()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0)
    initBlockButton()
end)

function fastBlock()
    if blockRemote then
        pcall(function()
            blockRemote:FireServer(true)
            task.delay(1e-10, function()
                pcall(function()
                    blockRemote:FireServer(false)
                end)
            end)
        end)
    else
        if not blockButton or not blockButton.Visible then return end
        for i = 1, #connections do
            local conn = connections[i]
            pcall(function() conn:Fire() end)
        end
        pcall(function() blockButton:Activate() end)
    end
end

lastTeleport = 0
function teleportDodge(killerChar)
    local now = tick()
    if now - lastTeleport < 5 then return end
    lastTeleport = now

    local myRoot = getHRP()
    local killerRoot = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
    if not (myRoot and killerRoot) then return end

    local oldCFrame = myRoot.CFrame
    local forward = killerRoot.CFrame.LookVector
    myRoot.CFrame = killerRoot.CFrame + forward * 7.5

    task.delay(0.1, function()
        if myRoot then
            myRoot.CFrame = oldCFrame
        end
    end)
end

function getBoolFlag(name, default)
    local flag = LocalPlayer:FindFirstChild(name)
    if not flag then
        flag = Instance.new("BoolValue")
        flag.Name = name
        flag.Value = default
        flag.Parent = LocalPlayer
    end
    return flag
end

function getNumberFlag(name, default)
    local flag = LocalPlayer:FindFirstChild(name)
    if not flag then
        flag = Instance.new("NumberValue")
        flag.Name = name
        flag.Value = default
        flag.Parent = LocalPlayer
    end
    return flag
end

toggleFlag = getBoolFlag("AutoBlockToggle", false)
strictFlag = getBoolFlag("AutoBlockStrictRange", false)
rangeFlag = getNumberFlag("AutoBlockRange", 18)
circleFlag = getBoolFlag("ShowKillerCircle", false)

toggleOn = toggleFlag.Value
strictRangeOn = strictFlag.Value
detectionRange = rangeFlag.Value
showCircleOn = circleFlag.Value

TabHandles.Survivors:Toggle({
    Title = "Auto Block",
    Locked = false,
    Value = toggleOn,
    Callback = function(state)
        toggleOn = state
        toggleFlag.Value = state
    end
})

TabHandles.Survivors:Toggle({
    Title = "Range Check",
    Locked = false,
    Value = strictRangeOn,
    Callback = function(state)
        strictRangeOn = state
        strictFlag.Value = state
    end
})

TabHandles.Survivors:Toggle({
    Title = "Show Circle",
    Locked = false,
    Value = showCircleOn,
    Callback = function(state)
        showCircleOn = state
        circleFlag.Value = state
    end
})

TabHandles.Survivors:Input({
    Title = "Detection Range",
    Value = tostring(detectionRange),
    Placeholder = "Enter range",
    Callback = function(txt)
        local val = tonumber(txt)
        if val then
            detectionRange = val
            rangeFlag.Value = val
        end
    end
})

playerConns = {}
recentBlocks = {}

function shouldBlockNow(p, animId, track)
    recentBlocks[p.UserId] = recentBlocks[p.UserId] or {}
    local last = recentBlocks[p.UserId][animId] or 0
    local now = tick()

    if now - last >= 0 then
        recentBlocks[p.UserId][animId] = now
        return true
    end
    return false
end

function onAnimationPlayed(player, char, track)
    if not toggleOn then return end
    if not (track and track.Animation) then return end

    local animIdStr = track.Animation.AnimationId
    local id = animIdStr and string.match(animIdStr, "%d+")
    if not id then return end
    if not (animationIds[id] or massInfectionIds[id]) then return end

    if strictRangeOn then
        local myRoot = getHRP()
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not myRoot or not root then return end
        if (root.Position - myRoot.Position).Magnitude > detectionRange then return end
    end

    if shouldBlockNow(player, id, track) then
        if massInfectionIds[id] then
            task.delay(0.5, fastBlock)
        else
            fastBlock()
        end

        if isKiller(player) and delayedAnimations[id] then
            teleportDodge(char)
        end
    end
end

function monitorCharacter(player, char)
    if not player or not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end

    local con = hum.AnimationPlayed:Connect(function(track)
        task.spawn(onAnimationPlayed, player, char, track)
    end)

    playerConns[player] = playerConns[player] or {}
    table.insert(playerConns[player], con)
end

function onPlayerAdded(player)
    if player == LocalPlayer then return end
    if player.Character then
        monitorCharacter(player, player.Character)
    end

    local con = player.CharacterAdded:Connect(function(char)
        task.wait(0)
        monitorCharacter(player, char)
    end)

    playerConns[player] = playerConns[player] or {}
    table.insert(playerConns[player], con)
end

for i = 1, #Players:GetPlayers() do
    onPlayerAdded(Players:GetPlayers()[i])
end

Players.PlayerAdded:Connect(onPlayerAdded)

circles = {}

function createCircleFor(player, hrp)
    if circles[player] then pcall(function() circles[player]:Destroy() end) end

    local circle = Instance.new("Part")
    circle.Anchored = true
    circle.CanCollide = false
    circle.Shape = Enum.PartType.Cylinder
    circle.Size = Vector3.new(0.2, detectionRange * 2, detectionRange * 2)
    circle.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))
    circle.Material = Enum.Material.Neon
    circle.Transparency = 0.5
    circle.Parent = Workspace

    circles[player] = circle
end

RunService.Heartbeat:Connect(function()
    if not showCircleOn then
        for _, c in pairs(circles) do
            if c then c.Transparency = 1 end
        end
        return
    end

    local myRoot = getHRP()
    if not myRoot then return end

    local killersFolder = getKillersFolder()

    local list = Players:GetPlayers()
    for i = 1, #list do
        local player = list[i]
        if player ~= LocalPlayer then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 and killersFolder and 
               (killersFolder:FindFirstChild(player.Name) or (char and killersFolder:FindFirstChild(char.Name))) then

                if not circles[player] then
                    createCircleFor(player, hrp)
                end

                local circle = circles[player]
                circle.Size = Vector3.new(0.2, detectionRange * 2, detectionRange * 2)
                circle.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90))

                local dist = (myRoot.Position - hrp.Position).Magnitude
                circle.Color = dist <= detectionRange and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
                circle.Transparency = 0.5
            else
                if circles[player] then
                    circles[player]:Destroy()
                    circles[player] = nil
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if circles[player] then
        circles[player]:Destroy()
        circles[player] = nil
    end
end)

local autoPunchOn, aimPunch, flingPunchOn, customPunchEnabled = false, false, false, false
local hiddenfling = false
local flingPower = 10000
local predictionValue = 4
local customPunchAnimId = ""
local lastPunchTime = 0
local punchAnimIds = { "87259391926321" }

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function playCustomPunch(animId)
    if not Humanoid then return end
    if not animId or animId == "" then return end
    local now = tick()
    if now - lastPunchTime < 1 then return end

    for _, track in ipairs(Humanoid:GetPlayingAnimationTracks()) do
        local animNum = tostring(track.Animation.AnimationId):match("%d+")
        if table.find(punchAnimIds, animNum) then
            track:Stop()
        end
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. animId
    local track = Humanoid:LoadAnimation(anim)
    track:Play()
    lastPunchTime = now
end

coroutine.wrap(function()
    local hrp, c, vel, movel = nil, nil, nil, 0.1
    while true do
        RunService.Heartbeat:Wait()
        if hiddenfling then
            while hiddenfling and not (c and c.Parent and hrp and hrp.Parent) do
                RunService.Heartbeat:Wait()
                c = getChar()
                hrp = c and c:FindFirstChild("HumanoidRootPart")
            end
            if hiddenfling then
                vel = hrp.Velocity
                hrp.Velocity = vel * flingPower + Vector3.new(0, flingPower, 0)
                RunService.RenderStepped:Wait()
                hrp.Velocity = vel
                RunService.Stepped:Wait()
                hrp.Velocity = vel + Vector3.new(0, movel, 0)
                movel = movel * -1
            end
        end
    end
end)()

RunService.RenderStepped:Connect(function()
    local myChar = getChar()
    local myRoot = getHRP()
    Humanoid = getHumanoid()
    if not myChar or not myRoot or not Humanoid then return end

    if autoPunchOn then
        local gui = PlayerGui:FindFirstChild("MainUI")
        local punchBtn = gui and gui:FindFirstChild("AbilityContainer") and gui.AbilityContainer:FindFirstChild("Punch")
        local charges = punchBtn and punchBtn:FindFirstChild("Charges")

        if charges and charges.Text == "1" then
            local killersFolder = getKillersFolder()

            if killersFolder then
                for _, killer in ipairs(killersFolder:GetChildren()) do
                    local root = killer:FindFirstChild("HumanoidRootPart")

                    if root and (root.Position - myRoot.Position).Magnitude <= 10 then

                        if aimPunch then
                            Humanoid.AutoRotate = false
                            task.spawn(function()
                                local start = tick()
                                while tick() - start < 2 do
                                    if myRoot and root and root.Parent then
                                        local predictedPos = root.Position + (root.CFrame.LookVector * predictionValue)
                                        myRoot.CFrame = CFrame.lookAt(myRoot.Position, predictedPos)
                                    end
                                    task.wait()
                                end
                                Humanoid.AutoRotate = true
                            end)
                        end

                        for _, conn in ipairs(getconnections(punchBtn.MouseButton1Click)) do
                            pcall(function()
                                conn:Fire()
                            end)
                        end

                        if flingPunchOn then
                            hiddenfling = true
                            task.spawn(function()
                                local start = tick()
                                while tick() - start < 1 do
                                    if getHRP() and root and root.Parent then
                                        local frontPos = root.Position + (root.CFrame.LookVector * 2)
                                        getHRP().CFrame = CFrame.new(frontPos, root.Position)
                                    end
                                    task.wait()
                                end
                                hiddenfling = false
                            end)
                        end

                        if customPunchEnabled and customPunchAnimId ~= "" then
                            playCustomPunch(customPunchAnimId)
                        end

                        break
                    end
                end
            end
        end
    end
end)

TabHandles.Survivors:Toggle({
    Title = "Auto Punch",
    Locked = false,
    Value = false,
    Callback = function(val)
        autoPunchOn = val
    end
})

TabHandles.Survivors:Toggle({
    Title = "Punch Aimbot",
    Locked = false,
    Value = false,
    Callback = function(val)
        aimPunch = val
    end
})

TabHandles.Survivors:Toggle({
    Title = "Fling Punch",
    Locked = false,
    Value = false,
    Callback = function(val)
        flingPunchOn = val
    end
})

TabHandles.Survivors:Slider({
    Title = "Aim Prediction",
    Value = {
        Min = 0,
        Max = 10,
        Default = 4
    },
    Callback = function(value)
        predictionValue = value
    end
})

TabHandles.Survivors:Slider({
    Title = "Fling Power",
    Value = {
        Min = 5000,
        Max = 500000,
        Default = 10000
    },
    Callback = function(value)
        flingPower = value
    end
})

TabHandles.Survivors:Input({
    Title = "Custom Punch",
    Value = "",
    Placeholder = "Enter Animation ID",
    Callback = function(txt)
        customPunchAnimId = txt
    end
})

TabHandles.Survivors:Toggle({
    Title = "Enable Custom Animation",
    Locked = false,
    Value = false,
    Callback = function(val)
        customPunchEnabled = val
    end
})

TabHandles.Killers:Section({ Title = "1x1x1x1", Icon = "swords" })

_G.MASS_AIM_MODE = "One Player"
_G.MASS_TOGGLE = false

local MASS_IDS = {
    ["131430497821198"]=true,
    ["100592913030351"]=true,
    ["70447634862911"]=true,
    ["83685305553364"]=true,
    ["101101433684051"]=true,
    ["109777684604906"]=true,
    ["104897856211468"]=true
}

function _G.MassAnimCheck()
    local h = getHumanoid()
    if h then
        local tr = h:GetPlayingAnimationTracks()
        for i=1,#tr do
            local a = tr[i].Animation
            if a then
                local id = string.gsub(a.AnimationId,"[^0-9]","")
                if MASS_IDS[id] then
                    return true
                end
            end
        end
    end
    return false
end

function _G.MassGetNearest()
    local folder = getSurvivorsFolder()
    if folder then
        local me = getHRP()
        if me then
            local best=nil
            local dist=999999
            local list=folder:GetChildren()
            for i=1,#list do
                local p=list[i]
                local hrp=p:FindFirstChild("HumanoidRootPart")
                local hum=p:FindFirstChild("Humanoid")
                if hrp and hum and hum.Health>0 then
                    local d=(me.Position-hrp.Position).Magnitude
                    if d<dist then
                        dist=d
                        best=p
                    end
                end
            end
            return best
        end
    end
    return nil
end

spawn(function()
    while task.wait(0.03) do
        if _G.MASS_TOGGLE == true then

            if _G.MassAnimCheck() == true then
                local t = _G.MassGetNearest()
                if t then
                    local hrp = t:FindFirstChild("HumanoidRootPart")
                    local hum = t:FindFirstChild("Humanoid")
                    local me = getHRP()

                    if hrp and hum and hum.Health>0 and me then
                        if _G.MASS_AIM_MODE == "Teleport" then
                            local back = (hrp.CFrame*CFrame.new(0,0,-3)).Position
                            me.CFrame = CFrame.lookAt(back,hrp.Position)
                        else
                            me.CFrame = CFrame.lookAt(me.Position,hrp.Position)
                        end
                    end
                end
            end

        end
    end
end)

TabHandles.Killers:Dropdown({
    Title = "Aim Mode",
    Values = {
        "One Player",
        "Multi Players",
        "Teleport"
    },
    Value = "One Player",
    Callback = function(v)
        _G.MASS_AIM_MODE = v
    end
})

TabHandles.Killers:Toggle({
    Title = "MassInfection Aimbot",
    Locked = false,
    Value = false,
    Callback = function(v)
        _G.MASS_TOGGLE = v
    end
})

AnimationService:Register("HakariDance", 138019937280193, { Speed = 1 })

TabHandles.Emote:Toggle({
    Title = "Hakari Dance",
    Callback = function(state)
        if state then
            AnimationService:Enable("HakariDance")
        else
            AnimationService:Disable("HakariDance")
        end
    end
})

AnimationService:Register("WhoWins", 109569860731042, { Speed = 1 })

TabHandles.Emote:Toggle({
    Title = "Who Wins",
    Callback = function(state)
        if state then
            AnimationService:Enable("WhoWins")
        else
            AnimationService:Disable("WhoWins")
        end
    end
})

AnimationService:Register("Rambunctious", 134229395028226, { Speed = 1 })

TabHandles.Emote:Toggle({
    Title = "Rambunctious",
    Callback = function(state)
        if state then
            AnimationService:Enable("Rambunctious")
        else
            AnimationService:Disable("Rambunctious")
        end
    end
})

AnimationService:Register("CoolFlip", 89401874695202, { Speed = 1 })

TabHandles.Emote:Toggle({
    Title = "Cool Dance",
    Callback = function(state)
        if state then
            AnimationService:Enable("CoolFlip")
        else
            AnimationService:Disable("CoolFlip")
        end
    end
})

TabHandles.Event:Section({ Title = "Holiday", Icon = "gift" })

local allowedModels = {
    ["shedletsky"] = true,
    ["builderman"] = true,
    ["noob"] = true,
    ["eliot"] = true,
    ["tapt"] = true,
    ["Guest"] = true,
    ["veeronica"] = true,
    ["007n7"] = true,
    ["chance"] = true,
    ["twotime"] = true
}

local blockedRadius = 5

local blockedCenter = Vector3.zero

local function safeLower(s)
    return type(s) == "string" and s:lower() or ""
end

local function getModelPart(model)
    if not model then return nil end
    local a = model:FindFirstChild("HumanoidRootPart")
    if a and a:IsA("BasePart") then return a end
    local b = model.PrimaryPart
    if b and b:IsA("BasePart") then return b end
    return model:FindFirstChildWhichIsA("BasePart")
end

local function isLivingCreature(model)
    return model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isValidCookie(model)
    if not model
    or not model:IsA("Model")
    or not model:IsDescendantOf(Workspace) then
        return false
    end

    if isLivingCreature(model) then
        return false
    end

    if not allowedModels[safeLower(model.Name)] then
        return false
    end

    local part = getModelPart(model)
    if not part then return false end

    local mag = (part.Position - blockedCenter).Magnitude
    return mag > blockedRadius
end

task.spawn(function()
    while true do
        task.wait(0.1)

        local hrp = getHRP()
        if hrp then
            blockedCenter = hrp.Position
        end
    end
end)

ESP:RegisterType(
    "Cookies",
    Color3.fromRGB(139, 69, 19),
    isValidCookie,
    false
)

TabHandles.Event:Toggle({
    Title = "ESP Cookies",
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Cookies", state)
    end
})

local currentCoords = "X: 0, Y: 0, Z: 0"

RunService.RenderStepped:Connect(function()
    if HRP then
        local pos = HRP.Position
        currentCoords = string.format("X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z)
    end
end)

TabHandles.Teleport:Paragraph({
    Title = "Player Coordinates",
    Desc = "Current position in the world",
    Image = "rbxassetid://109995816235688",
    ImageSize = 30,
    Buttons = {
        {
            Icon = "copy",
            Title = "Copy Coordinates",
            Callback = function()
                setclipboard(currentCoords)
                print("Copied coordinates:", currentCoords)
            end
        }
    }
})

TabHandles.Teleport:Button({
    Title = "TP Up +100",
    Callback = function()
        local hrp = getHRP()
        if hrp and hrp:IsA("BasePart") then
            pcall(function()
                local currentPos = hrp.Position
                hrp.CFrame = CFrame.new(currentPos.X, currentPos.Y + 100, currentPos.Z)
            end)
        end
    end,
})

TabHandles.Teleport:Button({
    Title = "TP To ???",
    Callback = function()
        local hrp = getHRP()
        if hrp and hrp:IsA("BasePart") then
            pcall(function()
                hrp.CFrame = CFrame.new(-3645.4, 6.6, -418.4)
            end)
        end
    end,
})

TabHandles.Player:Section({ Title = "Power", Icon = "zap" })

local ActiveNoStun = false
local noStunLoop

TabHandles.Player:Toggle({
    Title = "No Stun",
    Locked = false,
    Value = false,
    Callback = function(state)
        ActiveNoStun = state

        if noStunLoop then
            task.cancel(noStunLoop)
            noStunLoop = nil
        end

        if state then
            noStunLoop = task.spawn(function()
                while ActiveNoStun do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")

                    if hrp then
                        hrp.Anchored = false
                    end

                    task.wait(0.1)
                end
                noStunLoop = nil
            end)
        end
    end
})

local InfStaminaEnabled = false
local staminaLoop
local StaminaModule

pcall(function()
    local path =
        ReplicatedStorage:FindFirstChild("Systems")
        and ReplicatedStorage.Systems:FindFirstChild("Character")
        and ReplicatedStorage.Systems.Character:FindFirstChild("Game")
        and ReplicatedStorage.Systems.Character.Game:FindFirstChild("Sprinting")

    if path then
        StaminaModule = require(path)
    end
end)

local function restoreStamina()
    if not StaminaModule then return end

    local maxStamina = StaminaModule.MaxStamina or 100

    if StaminaModule.Stamina then
        if typeof(StaminaModule.SetStamina) == "function" then
            StaminaModule:SetStamina(maxStamina)
        elseif typeof(StaminaModule.UpdateStamina) == "function" then
            StaminaModule:UpdateStamina(maxStamina)
        else
            StaminaModule.Stamina = maxStamina
        end
    end
end

if StaminaModule then
    TabHandles.Player:Toggle({
        Title = "Infinite Stamina",
        Locked = false,
        Value = false,
        Callback = function(state)
            InfStaminaEnabled = state

            if StaminaModule.StaminaLossDisabled ~= nil then
                StaminaModule.StaminaLossDisabled = state
            end

            if state then
                restoreStamina()

                if not staminaLoop then
                    staminaLoop = task.spawn(function()
                        while InfStaminaEnabled do
                            task.wait(0.5)
                            restoreStamina()
                        end
                        staminaLoop = nil
                    end)
                end
            else
                if staminaLoop then
                    task.cancel(staminaLoop)
                    staminaLoop = nil
                end
            end
        end
    })
end

local WalkSpeed = { Value = 16, Active = false, Loop = nil }

TabHandles.Player:Section({ Title = "Walk Speed", Icon = "gauge" })

TabHandles.Player:Slider({
    Title = "Set Speed",
    Value = {
        Min = 0,
        Max = 40,
        Default = WalkSpeed.Value
    },
    Callback = function(value)
        WalkSpeed.Value = value
        if WalkSpeed.Active then
            local hum = getHumanoid()
            if hum then
                hum.WalkSpeed = WalkSpeed.Value
                hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
            end
        end
    end
})

TabHandles.Player:Toggle({
    Title = "Walk Speed",
    Value = false,
    Locked = false,
    Callback = function(enabled)
        WalkSpeed.Active = enabled

        if enabled then
            local hum = getHumanoid()
            if hum then
                hum.WalkSpeed = WalkSpeed.Value
                hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
            end

            WalkSpeed.Loop = task.spawn(function()
                while WalkSpeed.Active do
                    local hum = getHumanoid()
                    if hum then
                        hum.WalkSpeed = WalkSpeed.Value
                        hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
                    end
                    task.wait(0.5)
                end
            end)
        else
            WalkSpeed.Loop = nil
            local hum = getHumanoid()
            if hum then
                hum.WalkSpeed = 16
            end
        end
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    if WalkSpeed.Active then
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = WalkSpeed.Value
            hum:SetAttribute("BaseSpeed", WalkSpeed.Value)
        end
    end
end)

local TeleportSpeed = { Value = 50, Max = 300, Active = false }

TabHandles.Player:Section({ Title = "Teleport Speed", Icon = "navigation" })

TabHandles.Player:Slider({
    Title = "Set Speed",
    Value = {
        Min = 1,
        Max = TeleportSpeed.Max,
        Default = TeleportSpeed.Value
    },
    Callback = function(value)
        TeleportSpeed.Value = value
    end
})

TabHandles.Player:Toggle({
    Title = "Teleport Speed",
    Value = false,
    Locked = false,
    Callback = function(state)
        TeleportSpeed.Active = state
    end
})

RunService.Heartbeat:Connect(function(dt)
    if TeleportSpeed.Active then
        local hrp = getHRP()
        local hum = getHumanoid()
        if hrp and hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + hum.MoveDirection.Unit * (TeleportSpeed.Value * dt)
        end
    end
end)

local allowedModelsClone = {
    ["1x1x1x1Zombie"] = true,
    ["PizzaDeliveryRig"] = true,
    ["Mafia1"] = true,
    ["Mafia2"] = true,
    ["Mafia3"] = true,
    ["Mafia4"] = true,
}

ESP:RegisterType("Clone", Color3.fromRGB(0, 255, 0), function(obj)
    return obj:IsA("Model") and allowedModelsClone[obj.Name] == true
end, false)

TabHandles.Visual:Section({ Title = "Clone", Icon = "copy" })

TabHandles.Visual:Toggle({
    Title = "ESP Clone",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Clone", state)
    end
})

ESP:RegisterType("Model", Color3.fromRGB(255, 170, 0), function(obj)
    if not obj:IsA("Model") then return false end

    if Players:GetPlayerFromCharacter(obj) then
        return false
    end

    if obj.PrimaryPart then return true end
    if obj:FindFirstChild("HumanoidRootPart") then return true end

    return false
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Model",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Model", state)
    end
})

TabHandles.Visual:Section({ Title = "Player", Icon = "user" })

ESP:RegisterType("Player", Color3.fromRGB(0, 255, 255), function(obj)
    local plr = Players:GetPlayerFromCharacter(obj)
    return plr ~= nil and plr ~= LocalPlayer
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Player",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Player", state)
    end
})

ESP:RegisterType("Survivor", Color3.fromRGB(255, 255, 255), function(obj)
    local survivorsFolder = getSurvivorsFolder()
    return obj:IsA("Model")
        and survivorsFolder ~= nil
        and obj.Parent == survivorsFolder
        and obj:FindFirstChildOfClass("Humanoid") ~= nil
end, true)

TabHandles.Visual:Toggle({
    Title = "ESP Survivors",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Survivor", state)
    end
})

ESP:RegisterType("Killer", Color3.fromRGB(255, 0, 0), function(obj)
    local killersFolder = getKillersFolder()
    return obj:IsA("Model")
        and killersFolder ~= nil
        and obj.Parent == killersFolder
        and obj:FindFirstChildOfClass("Humanoid") ~= nil
end, true)

TabHandles.Visual:Toggle({
    Title = "ESP Killers",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Killer", state)
    end
})

TabHandles.Visual:Section({ Title = "Other", Icon = "layers" })

ESP:RegisterType("Generator", Color3.fromRGB(255, 255, 255), function(obj)
    if obj == nil or not obj:IsA("Model") or obj.Name ~= "Generator" then
        return false
    end

    local progress = obj:FindFirstChild("Progress", true)
    if progress == nil or not progress:IsA("NumberValue") then
        return false
    end

    if not progress:GetAttribute("ESP_Watch") then
        progress:SetAttribute("ESP_Watch", true)
        progress:GetPropertyChangedSignal("Value"):Connect(function()
            if progress.Value >= 100 then
                ESP:Remove(obj)
            else
                if ESP.Objects[obj] == nil then
                    ESP:_ScheduleCreate(obj, "Generator")
                end
            end
        end)
    end

    return progress.Value < 100
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Generator",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Generator", state)
    end
})

ESP:RegisterType("Item", Color3.fromRGB(255, 215, 0), function(obj)
    local map = Workspace:FindFirstChild("Map")
    return obj:IsA("Tool") and map ~= nil and obj:IsDescendantOf(map)
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Items",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Item", state)
    end
})

TabHandles.Visual:Section({ Title = "Builderman", Icon = "pen-tool" })

ESP:RegisterType("Dispenser", Color3.fromRGB(0, 162, 255), function(obj)
    return obj:IsA("Model") and string.find(obj.Name:lower(), "dispenser") ~= nil
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Dispenser",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Dispenser", state)
    end
})

ESP:RegisterType("Sentry", Color3.fromRGB(128, 128, 128), function(obj)
    return obj:IsA("Model") and string.find(obj.Name:lower(), "sentry") ~= nil
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Sentry",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Sentry", state)
    end
})

TabHandles.Visual:Section({ Title = "Trap / Tapt", Icon = "triangle-alert" })

ESP:RegisterType("Tripwire", Color3.fromRGB(255, 85, 0), function(obj)
    return obj:IsA("Model") and string.find(obj.Name, "TaphTripwire") ~= nil
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Tripwire",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Tripwire", state)
    end
})

ESP:RegisterType("Subspace", Color3.fromRGB(160, 32, 240), function(obj)
    return obj:IsA("Model") and obj.Name == "SubspaceTripmine"
end, false)

TabHandles.Visual:Toggle({
    Title = "ESP Subspace",
    Locked = false,
    Value = false,
    Callback = function(state)
        ESP:SetEnabled("Subspace", state)
    end
})

TabHandles.Settings:Section({ Title = "Camera", Icon = "camera" })

local fullBrightEnabled = false
local fullBrightConn = nil

local function applyFullBright()
    if not fullBrightEnabled then return end
    pcall(function()
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 4
        Lighting.GlobalShadows = false
    end)
end

local function enableFullBright()
    if fullBrightConn then fullBrightConn:Disconnect() end
    applyFullBright()

    fullBrightConn = Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
        applyFullBright()
    end)
end

local function disableFullBright()
    if fullBrightConn then
        fullBrightConn:Disconnect()
        fullBrightConn = nil
    end

    pcall(function()
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end)
end

TabHandles.Settings:Toggle({
    Title = "Full Bright",
    Locked = false,
    Value = false,
    Callback = function(state)
        fullBrightEnabled = state

        if state then
            enableFullBright()
        else
            disableFullBright()
        end
    end
})

local fogEnabled = false
local fogConn = nil

local function removeFog()
    pcall(function()
        Lighting.FogStart = 0
        Lighting.FogEnd = 999999

        local a = Lighting:FindFirstChild("Atmosphere")
        if a then
            a.Density = 0
            a.Offset = 0
            a.Haze = 0
            a.Color = Color3.new(1, 1, 1)
        end
    end)
end

local function restoreFog()
    pcall(function()
        Lighting.FogStart = 200
        Lighting.FogEnd = 1000

        local a = Lighting:FindFirstChild("Atmosphere")
        if a then
            a.Density = 0.3
            a.Offset = 0
            a.Haze = 0.5
            a.Color = Color3.fromRGB(200, 200, 200)
        end
    end)
end

TabHandles.Settings:Toggle({
    Title = "Remove Fog",
    Locked = false,
    Value = false,
    Callback = function(state)
        fogEnabled = state

        if state then
            removeFog()

            if fogConn then fogConn:Disconnect() end
            fogConn = RunService.Heartbeat:Connect(function()
                removeFog()
            end)
        else
            if fogConn then
                fogConn:Disconnect()
                fogConn = nil
            end
            restoreFog()
        end
    end
})

TabHandles.Settings:Toggle({
    Title = "Infinite Zoom",
    Locked = false,
    Value = false,
    Callback = function(state)
        local player = LocalPlayer

        if state then
            player.CameraMaxZoomDistance = math.huge
            player.CameraMinZoomDistance = 0.5
        else
            player.CameraMaxZoomDistance = 128
            player.CameraMinZoomDistance = 0.5
        end
    end
})

TabHandles.Settings:Section({ Title = "Protect", Icon = "shield-alert" })

local antiAFKCons = {}

TabHandles.Settings:Toggle({
    Title = "Anti-AFK",
    Locked = false,
    Value = true,
    Callback = function(state)
        if not getconnections then
            return
        end

        local idleCons = getconnections(game.Players.LocalPlayer.Idled)

        if state then
            for _, c in ipairs(idleCons) do
                antiAFKCons[c] = true
                pcall(function()
                    c:Disable()
                end)
            end
        else
            for c, _ in pairs(antiAFKCons) do
                if c and c.Enable then
                    pcall(function()
                        c:Enable()
                    end)
                end
            end
            antiAFKCons = {}
        end
    end
})

TabHandles.Settings:Toggle({
    Title = "Anti Ban V9",
    Locked = false,
    Value = true,
    Callback = function(Value)

        if type(setfflag) == "function" then
            pcall(function()
                if Value then
                    setfflag("AbuseReportScreenshot", "False")
                    setfflag("AbuseReportScreenshotPercentage", "0")
                else
                    setfflag("AbuseReportScreenshot", "True")
                    setfflag("AbuseReportScreenshotPercentage", "100")
                end
            end)
        end

        if WindUI then
            WindUI:Notify({
                Title = "Hutao Hub",
                Content = Value
                    and "Anti Ban - Report : ON"
                    or  "Anti Ban - Report : OFF",
                Duration = 2,
                Icon = Value and "shield" or "shield-off"
            })
        end
    end
})

TabHandles.Settings:Section({ Title = "Fix Lag", Icon = "cpu" })

local ActiveRemoveAll = false
local effectNames = {
    "BlurEffect", "ColorCorrectionEffect", "BloomEffect", "SunRaysEffect", 
    "DepthOfFieldEffect", "ScreenFlash", "HitEffect", "DamageOverlay", 
    "BloodEffect", "Vignette", "BlackScreen", "WhiteScreen", "ShockEffect",
    "Darkness", "JumpScare", "LowHealthOverlay", "Flashbang", "FadeEffect"
}

local effectClasses = {
    "BlurEffect",
    "BloomEffect",
    "SunRaysEffect",
    "DepthOfFieldEffect",
    "ColorCorrectionEffect"
}

local function safeGetPlayerGui()
    local gui = getPlayerGui()
    if gui and gui.Parent ~= nil then
        return gui
    end
    return nil
end

local function removeAll()
    for _, obj in pairs(Lighting:GetDescendants()) do
        if table.find(effectNames, obj.Name) or table.find(effectClasses, obj.ClassName) then
            obj:Destroy()
        end
    end

    local PlayerGui = safeGetPlayerGui()
    if not PlayerGui then return end

    for _, obj in pairs(PlayerGui:GetDescendants()) do
        if table.find(effectNames, obj.Name) then
            obj:Destroy()
        elseif (obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) then
            local lower = obj.Name:lower()
            if obj:FindFirstChildWhichIsA("ImageLabel") or obj:FindFirstChildWhichIsA("Frame") then
                if table.find(effectNames, obj.Name) or lower:find("overlay") or lower:find("effect") then
                    obj:Destroy()
                end
            end
        end
    end
end

local function ServerHop()
    local placeId = game.PlaceId
    local jobId = game.JobId
    print("[ServerHop] Đang rời server hiện tại...")

    local success, err = pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)

    if success then
        WindUI:Notify({
            Title = "Rejoin Starting",
            Content = "Bắt Đầu Vào Máy Chủ Đã Fix Lag",
            Duration = 3,
            Icon = "info"
        })
    else
        warn("[ServerHop] Lỗi khi Teleport:", err)
        WindUI:Notify({
            Title = "Lỗi Teleport",
            Content = tostring(err),
            Duration = 4,
            Icon = "alert"
        })
    end
end

TabHandles.Settings:Button({
    Title = "Rejoin To Fix Lag",
    Callback = function()
        WindUI:Notify({
            Title = "Rejoin Settings",
            Content = "Đang Giảm Lag Cho Các Máy Chủ...",
            Duration = 2,
            Icon = "info"
        })
        task.wait(0.3)
        ServerHop()
    end
})

getgenv().chatWindow = game:GetService("TextChatService"):WaitForChild("ChatWindowConfiguration")
getgenv().chatEnabled = false
getgenv().chatConnection = nil

TabHandles.Settings:Toggle({
    Title = "Show Chat",
    Locked = false,
    Value = getgenv().chatEnabled,
    Callback = function(Value)
        getgenv().chatEnabled = Value

        if Value then
            if not getgenv().chatConnection then
                getgenv().chatConnection = RunService.Heartbeat:Connect(function()
                    if getgenv().chatWindow then
                        getgenv().chatWindow.Enabled = true
                    end
                end)
            end
        else
            if getgenv().chatConnection then
                getgenv().chatConnection:Disconnect()
                getgenv().chatConnection = nil
            end
            if getgenv().chatWindow then
                getgenv().chatWindow.Enabled = false
            end
        end
    end
})

TabHandles.Settings:Toggle({
    Title = "Remove Effects",
    Locked = false,
    Value = true,
    Callback = function(Value)
        ActiveRemoveAll = Value

        if Value then
            task.spawn(function()
                while ActiveRemoveAll do
                    pcall(removeAll)
                    task.wait(0.5)
                end
            end)
        end
    end
})

TabHandles.Settings:Section({ Title = "Game Play", Icon = "joystick" })

local ASConfigs = {
    Slowness = {Values = {"SlowedStatus"}, Enabled = false},
    Skills = {
        Values = {
            "StunningKiller","EatFriedChicken","GuestBlocking","PunchAbility","SubspaceTripmine",
            "TaphTripwire","PlasmaBeam","SpawnProtection","c00lgui","ShootingGun",
            "TwoTimeStab","TwoTimeCrouching","DrinkingCola","DrinkingSlateskin",
            "SlateskinStatus","EatingGhostburger"
        },
        Enabled = false
    },
    Items = {Values = {"BloxyColaItem","Medkit"}, Enabled = false},
    Emotes = {Values = {"Emoting"}, Enabled = false},
    Builderman = {Values = {"DispenserConstruction","SentryConstruction"}, Enabled = false}
}

local DoAutoPopup = false
local AutoClickActiveButton = false
local clickedButtons = {}

local function hideSlownessUI()
    local gui = getPlayerGui()
    if not gui then return end

    local mainUI = gui:FindFirstChild("MainUI")
    if not mainUI then return end

    local status = mainUI:FindFirstChild("StatusContainer")
    if not status then return end

    local slowUI = status:FindFirstChild("Slowness")
    if slowUI then
        slowUI.Visible = false
    end
end

local function applyAntiSlow()
    local survivors = getSurvivorsFolder()
    local char = getChar()
    if not survivors or not char then return end

    local model = survivors:FindFirstChild(char.Name)
    if not model then return end

    local speedMult = model:FindFirstChild("SpeedMultipliers")
    if not speedMult then return end

    for _, cfg in pairs(ASConfigs) do
        if cfg.Enabled then
            for _, valName in ipairs(cfg.Values) do
                local val = speedMult:FindFirstChild(valName)
                if val and val:IsA("NumberValue") and val.Value ~= 1 then
                    val.Value = 1
                end
            end
        end
    end

    hideSlownessUI()
end

local function applyAutoPopup()
    local gui = getPlayerGui()
    if gui then
        local tempUI = gui:FindFirstChild("TemporaryUI")
        if tempUI then
            local popup = tempUI:FindFirstChild("1x1x1x1Popup")
            if popup then popup:Destroy() end
        end
    end

    local survivors = getSurvivorsFolder()
    local char = getChar()
    if not survivors or not char then return end

    local model = survivors:FindFirstChild(char.Name)
    if not model then return end

    local speed = model:FindFirstChild("SpeedMultipliers")
    if speed then
        local v = speed:FindFirstChild("SlowedStatus")
        if v then v.Value = 1 end
    end

    local fov = model:FindFirstChild("FOVMultipliers")
    if fov then
        local v = fov:FindFirstChild("SlowedStatus")
        if v then v.Value = 1 end
    end
end

RunService.Heartbeat:Connect(function()
    applyAntiSlow()
    if DoAutoPopup then
        applyAutoPopup()
    end
end)

TabHandles.Settings:Toggle({
    Title = "Anti-Slow",
    Locked = false,
    Value = false,
    Callback = function(v)
        for _, cfg in pairs(ASConfigs) do
            cfg.Enabled = v
        end
    end
})

TabHandles.Settings:Toggle({
    Title = "Delete 1x Popups",
    Locked = false,
    Value = true,
    Callback = function(v)
        DoAutoPopup = v
    end
})

TabHandles.Settings:Toggle({
    Title = "Detele ActiveButton",
    Locked = false,
    Value = false,
    Callback = function(state)
        AutoClickActiveButton = state
        if not state then
            table.clear(clickedButtons)
        end
    end
})

RunService.RenderStepped:Connect(function()
    if not AutoClickActiveButton then return end

    local playerGui = getPlayerGui()
    if not playerGui then return end

    local gui = playerGui:FindFirstChildWhichIsA("ScreenGui", true)
    if not gui then return end

    local tempUI = gui:FindFirstChild("TemporaryUI")
    if not tempUI then return end

    for _, v in ipairs(tempUI:GetDescendants()) do
        if v.Name == "ActiveButton"
        and (v:IsA("ImageButton") or v:IsA("TextButton"))
        and v.Visible
        and not clickedButtons[v] then

            clickedButtons[v] = true

            pcall(function()
                v:Destroy()
            end)
        end
    end
end)

