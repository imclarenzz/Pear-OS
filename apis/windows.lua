-- Window API by Jummit
-- http://www.computercraft.info/forums2/index.php?/topic/29514-multitasking-window-api/
-- Edited by SamH
--

local width, height = term.getSize()
programs = {}
local userEvents = {"mouse_click", "mouse_up", "mouse_drag", "char", "key", "monitor_touch", "key_up", "paste", "terminate"}

programs.new = function(func, x, y, w, h, name)
  local x = x or 1
  local y = y or 1
  local w = w or widht
  local h = h or height
  local name = name or "Empty"
  local program = {
    x = x, y = y, w = w, h = h, name = name,
    term = window.create(
      term.current(), x, y, w, h
    ),
    selected = false,
    blinking = false,
    blinkX = 0,
    blinkY = 0,
    blinkCol = 0,
    coroutine = coroutine.create(func),
    reposition = function(self, x, y)
      self.x, self.y = x, y
      self.term.reposition(x, y)
    end,
    resize = function(self, w, h)
      oldX, oldY = self.term.getPosition()
      self.term.reposition(oldX, oldY, w, h)
      os.queueEvent("term_resize")
    end,
    reset = function(self, x, y, w, h)
      self.x, self.y, self.w, self.h = x, y, w, h
      self.term.reposition(x, y, w, h)
      os.queueEvent("term_resize")
    end
  }
  return program
end

local updateProgram = function(programs, programNum, event, var1, var2, var3, isUserEvent)
  local program = programs[programNum]
  local event, var1, var2, var3 = event, var1, var2, var3

  -- redirect to programs terminal
  if program then

    local oldTerm = term.redirect(program.term)
    cX, cY = term.getCursorPos()
    col = term.getTextColor()

    -- give the mouse click as seen from the program window
    if string.sub(event, 1, #"mouse") == "mouse" then
      var2 = var2-program.x+1
      var3 = var3-program.y+1
    end

    -- find out if the program window is clicked
    if event == "mouse_click" and var2>=0 and var3>=0 and var2<=program.w and var3<=program.h then
      -- select this program and deselect every other one
      for programNum = 1, #programs do
        programs[programNum].selected = false
      end
      program.selected = true
      if var3 == 0 then
        program.barSelected = true
        program.barSelectedX = var2
        if var2 == 1 then
          program.resizeIconSelected = true
        end
        if var2 == program.w then
          table.remove(programs, programNum)
          term.redirect(oldTerm)
          return
        end
      end

      -- resort program table

      local selectedProgram
      for i = 1, #programs do
        if programs[i].selected then
          selectedProgram = programs[i]
          table.remove(programs, i)
          break
        end
      end
      table.insert(programs, selectedProgram)
    end

    -- move window when mouse is dragged
    if event == "mouse_drag" and program.barSelected then
      if program.resizeIconSelected then
        program:reset(program.x + var2-program.barSelectedX, program.y+var3, program.w-var2+1, program.h-var3)
      else
        program:reposition(program.x + var2-program.barSelectedX, program.y+var3)
      end
    end

    -- deselect bar if mouse is released
    if event == "mouse_up" then
      program.barSelected = false
      program.resizeIconSelected = false
    end

    -- only give program user events if selected
    if isUserEvent and not program.selected then
      event, var1, var2, var3 = ""
    end

    program.blinking = term.getCursorBlink()
    -- resume program
    coroutine.resume(program.coroutine, event, var1, var2, var3)

    -- delete program if it is finished
    if coroutine.status(program.coroutine) == "dead" then
      table.remove(programs, programNum)
      term.redirect(oldTerm)
      return true
    end

    program.term.redraw()
    term.redirect(oldTerm)

    -- draw line above program
    if program.selected then
      term.setBackgroundColor(colors.lightGray)
      term.setTextColor(colors.gray)
    else
      term.setBackgroundColor(colors.gray)
      term.setTextColor(colors.lightGray)
    end
    paintutils.drawLine(program.x, program.y-1, program.x+program.w-1, program.y-1)

    -- draw resize icon
    term.setCursorPos(program.x, program.y-1)
    term.write("/")

    -- draw name
    term.setTextColor(colors.white)
    term.setCursorPos(program.x+2, program.y-1)
    term.write(program.name)

    -- draw close icon
    term.setCursorPos(program.x+program.w-1, program.y-1)
    term.setTextColor(colors.orange)
    term.write("x")

    program.blinkCol = col
    program.blinkX, program.blinkY = program.x+cX-1, program.y+cY-1
  end
end

programs.update = function(programs, event, var1, var2, var3)
  -- check if event is made from the user
  local isUserEvent = false
  for userEventNum = 1, #userEvents do
    local userEvent = userEvents[userEventNum]
    if event == userEvent then
      isUserEvent = true
      break
    end
  end

  -- update every program
  for programNum = 1, #programs do
    if updateProgram(programs, programNum, event, var1, var2, var3, isUserEvent) then break end
  end
end