local ChartingState = State:extend("PlayState")

function ChartingState:enter()
    self.time = 0
    self.notefields = {}
    local chart = Song("bopeebo"):getChart("hard")
    self:makeNotefield(chart.notes.enemy, 0)
	self:makeNotefield(chart.notes.player, 1)
end

function ChartingState:makeNotefield(notes, i)
    local notefield = Notefield(0, 0, 4, Skin("default"))
        notefield:screenCenter()
        notefield.x = notefield.x - 250 + 500 * i
        notefield:setNoteBuffer(notes)
        self:add(notefield)
        table.insert(self.notefields, notefield)
end

function ChartingState:update(dt)
    if game.mouse.wheel > 0 then
        self.time = self.time - 0.05
        for _, notefield in ipairs(self.notefields) do
            notefield.time = self.time
        end
    elseif game.mouse.wheel < 0 then
        self.time = self.time + 0.05
        for _, notefield in ipairs(self.notefields) do
            notefield.time = self.time
        end
    end
    ChartingState.super.update(self, dt)
end

return ChartingState
