-- Brainrot Bazaar — small visual feedback helpers.
-- Kept deliberately simple: a green flash on the money label when the
-- player earns, and a brief red vignette flash for the tsunami warning.
-- Every helper no-ops safely if the target instance is missing.

local TweenService = game:GetService("TweenService")

local Effects = {}

-- Flash the money label green, then fade it back to its original colour.
function Effects.flashMoney(label)
	if not label or not label.Parent then
		return
	end
	pcall(function()
		local original = label.TextColor3
		local flashIn = TweenService:Create(label, TweenInfo.new(0.15),
			{ TextColor3 = Color3.fromRGB(110, 255, 130) })
		flashIn:Play()
		flashIn.Completed:Connect(function()
			if not label.Parent then
				return
			end
			local flashOut = TweenService:Create(label, TweenInfo.new(0.6),
				{ TextColor3 = original })
			flashOut:Play()
		end)
	end)
end

-- Brief red vignette flash over the whole screen (tsunami warning).
function Effects.tsunamiFlash(vignette)
	if not vignette then
		return
	end
	pcall(function()
		vignette.Visible = true
		vignette.BackgroundTransparency = 0.55
		local fade = TweenService:Create(vignette,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Connect(function()
			vignette.Visible = false
		end)
	end)
end

return Effects

-- Polish pass 18 Nov: reviewed; no change needed.
