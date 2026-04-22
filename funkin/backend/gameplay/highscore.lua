local Highscore = {
	scores = {
		songs = {},
		weeks = {}
	}
}

Highscore.save = game.save("highscores")

function Highscore.load()
	Highscore.save:load()

	if Highscore.save.data and Highscore.save.data.songs then
		Highscore.scores = Highscore.save.data
	else
		Highscore.save.data = Highscore.scores
	end
end

function Highscore.saveScore(song, score, diff)
	local formatSong = paths.formatToSongPath(song) .. '-' .. diff:lower()

	if not Highscore.scores.songs[formatSong] or Highscore.scores.songs[formatSong] < score then
		Highscore.scores.songs[formatSong] = score
	end

	Highscore.save.data = Highscore.scores
	Highscore.save:save()
end

function Highscore.saveWeekScore(week, score, diff)
	local formatWeek = week .. '-' .. diff:lower()

	if not Highscore.scores.weeks[formatWeek] or Highscore.scores.weeks[formatWeek] < score then
		Highscore.scores.weeks[formatWeek] = score
	end

	Highscore.save.data = Highscore.scores
	Highscore.save:save()
end

function Highscore.getScore(song, diff)
	local formatSong = paths.formatToSongPath(song) .. '-' .. diff:lower()
	return Highscore.scores.songs[formatSong] or 0
end

function Highscore.getWeekScore(week, diff)
	local formatWeek = week .. '-' .. diff:lower()
	return Highscore.scores.weeks[formatWeek] or 0
end

function Highscore.resetAll()
	Highscore.save:delete()
	Highscore.scores = {songs = {}, weeks = {}}
	Highscore.save.data = Highscore.scores
	Highscore.save:save()
end

return Highscore
