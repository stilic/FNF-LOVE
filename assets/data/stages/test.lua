local fft, fftBars

function create()
	camZoom = 0.7

	boyfriendPos:set(1300, 890)
	gfPos:set(800, 710)
	dadPos:set(535, 890)

	boyfriendCam:set(boyfriendCam.x - 100, boyfriendCam.y - 80)
	dadCam:set(dadCam.x + 90, dadCam.y - 60)

	local bg = BackDrop(128)
	bg.scrollFactor:mul(0.2)
	bg.blend = "add"
	bg.alpha = 0.1
	bg.moves = true
	bg.velocity:set(20, 20)
	add(bg)

	local ground = ActorSprite(270, 460, 300, paths.getImage('menus/menuDesat'))
	ground:updateHitbox()
	ground.fov, ground.scale.x, ground.scale.y = 40, 2, 2
	ground.rotation.x = -90
	add(ground)
	game.camera.bgColor = Color.GRAY

	local path = "songs/" .. paths.formatToSongPath(PlayState.SONG.song) .. "/Inst.ogg"
	fft = FFT(46, path, game.sound.music._source)
	fft.fftSize = 1024

	fftBars = SpriteGroup(140, 577)
	fftBars.scrollFactor:mul(0.46795)
	for i = 1, 46 do
		local g = Graphic(26 * i, 0, 26, 1, Color.WHITE)
		g.origin.y = 1
		fftBars:add(g)
	end
	add(fftBars)

	refresh()
end

function postCreate()
	local char = gf
	if char then
		char.scale:mul(0.8)
		char.scrollFactor:mul(0.61)
	end
	char = boyfriend
	if char then
		char.scrollFactor:mul(1.1185)
	end
	char = dad
	if char then
		char.scrollFactor:mul(1.11)
	end
end

function draw()
	fft:update(0)
	for i, member in ipairs(fftBars.members) do
		local member = fftBars.members[i]
		member.scale.y = fft.bars[i] * 70
	end
end
