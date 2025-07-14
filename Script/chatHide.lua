game.StarterGui:SetCore("ChatMakeSystemMessage", {
    Text = "[System] : Le chat est maintenant masqué.",
    Color = Color3.fromRGB(255, 255, 0),
    Font = Enum.Font.SourceSansBold,
    TextSize = 18,
})
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false) 