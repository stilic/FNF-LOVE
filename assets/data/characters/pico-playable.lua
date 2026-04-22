local fadeGroup = Group()
local retry

local function createFadeSprite()
	local spr = fadeGroup:recycle(AnimateAtlas)
	spr:setPosition(x, y)
	spr:load(_animAtlas.library)

	local scont = self.anim
	local curSymbol = _animAtlas.symbol
	local curFrame = scont:getCurrentFrame() or 0

	local tcont = spr.animation
	tcont.symbol = curSymbol
	spr.symbol = curSymbol
	spr.frame = curFrame

	tcont.update = function() end
	tcont.curAnim = nil

	spr.alpha = 1
	spr.scale:set(1, 1)
	spr.offset:set(offset.x, offset.y)
	spr.origin:set(origin.x, origin.y)

	tween:tween(spr, {alpha = 0}, 0.3, {
		onComplete = function()
			spr:kill()
		end
	})
	tween:tween(spr.scale, {x = 1.05, y = 1.05}, 0.3)
	state.stage:add(spr)
end

function postGoodNoteHit(note)
	if note.type == "weekend-1-cockgun" then
		createFadeSprite()
	end
end

function onGameOver(event)
	event.characterName = 'pico-dead'
	event.deathSoundName = 'gameplay/gameover/fnf_loss_sfx-pico'
	event.loopSoundName = 'gameOver-pico'
	event.endSoundName = 'gameOverEnd-pico'
end
function postGameOverCreate()
	local state = game.getState()
	state.gf.exists = false

	local stage = state.stage
	stage.color = {0.22, 0, 0.5}
	Tween.tween(stage.color, {0, 0, 0}, 0.5, {startDelay = 0.22, ease = Ease.quadOut})

	local bf = game.getState(true).boyfriend
	bf:setPosition(bf.x - 240, bf.y - 436)
	local x, y = bf:getGraphicMidpoint()
	game.getState(true).camFollow = Point(x - 330, y - 100)

	retry = Sprite(state.boyfriend.x + 188, state.boyfriend.y - 30)
	retry:setFrames(paths.getAtlas("characters/pico/Pico_Death_Retry"))
	game.getState(true):add(retry)
	retry.animation:addByPrefix("loop", "Retry Text Loop", 24, true)
	retry.animation:addByPrefix("confirm", "Retry Text Confirm", 24, false)
	retry.animation:get("confirm").offset:set(245, 220)
	retry.animation:play("loop")
	retry.visible = false
end

function postGameOverUpdate(dt)
	if game.getState(true).boyfriend.animation.curAnim.frame >= 36 then
		retry.visible = true
	end
end

function gameOverConfirm()
	game.getState(true).boyfriend.animation:play("deathLoop")
	retry.animation:play("confirm")
	retry.visible = true
end
