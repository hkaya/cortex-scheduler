# Copyright (C) 2015 Cortex Systems, LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

class Scheduler
  constructor: (defaultView) ->
    if not defaultView?
      throw 'Scheduler needs a valid default view.'

    @slots = {}
    @viewOrder = []
    @current = 0
    @defaultView = defaultView

  register: (sname) ->
    if not @slots[sname]?
      @slots[sname] = []

    @viewOrder.push sname

  submit: (sname, view) ->
    if sname of @slots
      @slots[sname].push view
    else
      throw "Scheduler doesn't know about slot: #{sname}"

  start: ->
    @_run()

  _run: ->
    st = new Date().getTime()
    done = =>
      et = new Date().getTime() - st
      console.log "View completed in #{et} msecs."
      @_run()

    if @viewOrder.length == 0
      # no view slots. show default view.
      @defaultView done

    else
      checked = 0
      loop
        if @_tryToViewCurrent done
          break

        else
          checked++
          if checked >= @viewOrder.length
            @defaultView done
            break

  _tryToViewCurrent: (done) ->
    if @viewOrder.length == 0
      return false

    if @current >= @viewOrder.length
      @current = 0

    sname = @viewOrder[@current]
    cslot = @slots[sname]
    @current++

    if cslot.length > 0
      view = cslot.shift()
      view done
      true
    else
      false

module.exports = Scheduler
