TAG                     = 'scheduler:'

MAX_VIEW_DURATION       = 60 * 1000
CONTENT_DIV_ID          = '__cortex_main'
DEFAULT_VIEW            = '__dv'
BLACK_SCREEN_SLOT_NAME  = '__bs'
BLACK_SCREEN =
  slot:     BLACK_SCREEN_SLOT_NAME
  view:     ""
  duration: 1000
  isVideo:  false
  callbacks:
    error: (err) ->
      console.log "#{TAG} Even black screens fail... err=#{err?.message}"

class Scheduler
  constructor: (@onVideoView, @onViewEnd) ->
    @_slots =
      "#{DEFAULT_VIEW}": []
    @_viewOrder = []
    @_fallbackSlots = {}
    @_fallbackViewOrder = []
    @_current = 0

  register: (sname, fallback) ->
    console.log "#{TAG} Registering new slot: #{sname} with fallback: #{fallback}"
    if not @_slots[sname]?
      @_slots[sname] = []

    @_viewOrder.push sname

    if not not fallback
      if not @_fallbackSlots[fallback]?
        @_fallbackSlots[fallback] = []
        @_fallbackViewOrder.push fallback

  submitDefaultView: (view, duration, callbacks) ->
    @submitView DEFAULT_VIEW, view, duration, callbacks

  submitView: (sname, view, duration, callbacks) ->
    console.log "#{TAG} New view to be submitted to slot #{sname} with duration #{duration}"
    if not @_isNumeric(duration)
      throw new RangeError("View duration should be in the range of (0, #{MAX_VIEW_DURATION})")

    duration = Number(duration)
    if duration <= 0 or duration > MAX_VIEW_DURATION
      throw new RangeError("View duration should be in the range of (0, #{MAX_VIEW_DURATION})")

    @_submit
      slot:       sname
      view:       view
      duration:   duration
      callbacks:  callbacks
      isVideo:    false

  submitVideo: (sname, file, callbacks) ->
    @_submit
      slot:       sname
      file:       file
      callbacks:  callbacks
      isVideo:    true

  _submit: (view) ->
    if view.slot of @_slots
      @_slots[view.slot].push view
    else if view.slot of @_fallbackSlots
      @_fallbackSlots[view.slot].push view
    else
      throw new Error("Unknown view slot: #{view.slot}")

  start: (window, document) ->
    @window = window
    @document = document
    @_run()

  _run: ->
    st = new Date().getTime()
    done = (sname) =>
      et = new Date().getTime() - st
      console.log "#{TAG} #{sname} completed in #{et} msecs."
      @_run()

    if @_viewOrder.length == 0
      @_showDefaultView done

    else
      checked = 0
      loop
        if @_tryToViewCurrent done
          break

        else
          checked++
          if checked >= @_viewOrder.length
            @_viewFallbackElseDefaultView done
            break

  _tryToViewCurrent: (done) ->
    if @_viewOrder.length == 0
      return false

    if @_current >= @_viewOrder.length
      @_current = 0

    sname = @_viewOrder[@_current]
    cslot = @_slots[sname]
    @_current++

    if cslot?.length > 0
      view = cslot.shift()
      console.log "#{TAG} Rendering a view from #{sname} for #{view.duration} msecs."
      @_render view, done
      return true

    false

  _viewFallbackElseDefaultView: (done) ->
    if @_fallbackViewOrder.length > 0
      for sname in @_fallbackViewOrder
        slot = @_fallbackSlots[sname]
        if slot.length > 0
          fallback = slot.shift()
          console.log "#{TAG} Rendering a fallback view from #{sname} for #{fallback.duration} msecs."
          @_render fallback, done
          return

    @_showDefaultView done

  _showDefaultView: (done) ->
    slot = @_slots[DEFAULT_VIEW]
    if slot.length > 0
      view = slot.shift()
      console.log "#{TAG} Rendering the default view for #{view.duration} msecs."
      @_render view, done

    else
      console.log "#{TAG} BLACK SCREEN!!!!!!! for #{BLACK_SCREEN.duration} msecs."
      @_render BLACK_SCREEN, done

  _render: (view, done) ->
    try
      console.log "#{TAG} Rendering view #{view.slot}, video=#{view.isVideo}"

      view.callbacks?.begin?()

      @_cleanAndGetContainer (div) =>
        if view.isVideo
          @_renderVideoView div, view, done

        else
          @_renderHtmlView div, view
          end = =>
            done view.slot
            @_onViewEnd view.slot
            view.callbacks?.end?()

          setTimeout end, view.duration

        @document.body.appendChild div
        @_fadeIn div, ->
    catch err
      console.log "#{TAG} Error while rendering #{view.slot} view. video=#{view.isVideo}, e=#{err?.message}"
      done view.slot
      view.callbacks?.error? err

  _renderHtmlView: (div, view) ->
    div.innerHTML = view.view

  _renderVideoView: (div, view, done) ->
    @onVideoView? div, view.file, (
      =>
        done view.slot
        @_onViewEnd view.slot
        view.callbacks?.end?()
    ), (
      (err) ->
        done view.slot
        view.callbacks?.error? err
    )
    
  _cleanAndGetContainer: (cb) ->
    div = @document.getElementById(CONTENT_DIV_ID)
    if div?
      @_fadeOut div, =>
        @document.body.removeChild div
        cb @_newDiv()

    else
      cb @_newDiv()

  _newDiv: ->
    div = @document.createElement('div')
    div.setAttribute 'id', CONTENT_DIV_ID
    div.style.overflow = 'hidden'
    div.style.overflowX = 'hidden'
    div.style.overflowY = 'hidden'
    div.style.height = '100%'
    div.style.width = '100%'
    div.style.backgroundColor = '#000'
    div.style.display = 'block'
    div.style.opacity = 0
    div

  _fadeOut: (element, cb) ->
    opacity = 1
    decrease = =>
      opacity -= 0.15
      if opacity <= 0
        element.style.opacity = 0
        element.style.display = 'none'
        cb?()
      else
        element.style.opacity = opacity
        @window.requestAnimationFrame decrease

    decrease()

  _fadeIn: (element, cb) ->
    opacity = 0
    element.style.display = 'block'
    increase = =>
      opacity += 0.15
      if opacity >= 1
        element.style.opacity = 1
        cb?()
      else
        element.style.opacity = opacity
        @window.requestAnimationFrame increase

    increase()

  _onViewEnd: (sname) ->
    @onViewEnd? sname

  _isNumeric: (n) ->
    !isNaN(parseFloat(n)) && isFinite(n)


module.exports = Scheduler
