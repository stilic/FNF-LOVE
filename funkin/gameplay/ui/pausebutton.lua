local PauseButton = SpriteGroup:extend("PauseButton")

function PauseButton:new(x, y, skin)
	PauseButton.super.new(self, x, y)

	local pauseButton = SpriteButton(0, 0, "return", skin:get("pauseButton", "atlas"))

	pauseButton.animation:addByIndices('idle', 'pause', {0}, "", 24, false);
	pauseButton.animation:addByIndices('hold', 'pause', {5}, "", 24, false);
	pauseButton.animation:addByIndices('confirm', 'pause', {
		6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
	}, "", 24, false);
	pauseButton.scale:set(0.8, 0.8);
	pauseButton:updateHitbox();
	pauseButton.animation:play("idle");

	pauseButton.button.onPress:add(function() pauseButton.animation:play("confirm", true) end)
	self.pauseButton = pauseButton

	local pauseCircle = Sprite(0, 0, skin:get("pauseCircle"))
	pauseCircle.scale:set(0.84, 0.8);
	pauseCircle:updateHitbox();

	pauseCircle:center(pauseButton)
	pauseButton.button:setPosition(x + pauseCircle.x, y + pauseCircle.y)
	pauseButton.button.width, pauseButton.button.height =
		pauseCircle.width, pauseCircle.height

	pauseCircle.blend = "add"
	pauseButton.blend = "add"
	pauseCircle.alpha = 0.067;
	self.pauseCircle = pauseCircle

	self:add(pauseButton)
	self:add(pauseCircle)
end

return PauseButton
