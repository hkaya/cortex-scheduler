TAG                     = 'scheduler:'

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
  constructor: (opts, @onVideoView, @onViewEnd) ->
    opts ?= {}

    @_maxViewDuration = 60 * 1000
    if opts.maxViewDuration?
      @_maxViewDuration = opts.maxViewDuration

    @_defaultViewQueueLen = 10
    if opts.defaultViewQueueLen?
      @_defaultViewQueueLen = opts.defaultViewQueueLen

    @_defaultView = undefined
    @_defaultViewQueue = []
    @_defaultViewRenderIndex = 0

    @_slots = {}
    @_viewOrder = []
    @_fallbackSlots = {}
    @_fallbackViewOrder = []
    @_current = 0

    @_transitionEndCallback = undefined

    @_exit = false

  exit: ->
    @_exit = true

  register: (sname, fallback) ->
    console.log "#{TAG} Registering new slot: #{sname} with fallback: #{fallback}"
    if not @_slots[sname]?
      @_slots[sname] = []

    @_viewOrder.push sname

    if not not fallback
      if not @_fallbackSlots[fallback]?
        @_fallbackSlots[fallback] = []
        @_fallbackViewOrder.push fallback

  setDefaultView: (sname) ->
    console.log "#{TAG} Setting default view to #{sname}"
    if sname of @_slots or sname of @_fallbackSlots
      @_defaultView = sname
    else
      throw new Error("Unknown view slot: #{sname}")

  _submitDefaultView: (view) ->
    if @_defaultViewQueue.length >= @_defaultViewQueueLen
      @_defaultViewQueue.shift()

    @_defaultViewQueue.push view

  submitView: (sname, view, duration, callbacks, opts) ->
    console.log "#{TAG} New view to be submitted to slot #{sname} with duration #{duration}"
    if not @_isNumeric(duration)
      throw new RangeError("View duration should be in the range of (0, #{@_maxViewDuration})")

    duration = Number(duration)
    if duration <= 0 or duration > @_maxViewDuration
      throw new RangeError("View duration should be in the range of (0, #{@_maxViewDuration})")

    @_submit
      slot:       sname
      view:       view
      duration:   duration
      callbacks:  callbacks
      opts:       opts
      isVideo:    false

  submitVideo: (sname, file, callbacks, opts) ->
    @_submit
      slot:       sname
      file:       file
      callbacks:  callbacks
      opts:       opts
      isVideo:    true

  _submit: (view) ->
    if view.slot is @_defaultView
      @_submitDefaultView @_newDefaultView(view)

    if view.slot of @_slots
      @_slots[view.slot].push view
    else if view.slot of @_fallbackSlots
      @_fallbackSlots[view.slot].push view
    else
      throw new Error("Unknown view slot: #{view.slot}")

  start: (window, document, root) ->
    if not @_defaultView?
      console.warn """Scheduler: No default view is set. Consider selecting
        one of the view slots as default by calling setDefaultView(slotName). \
        Views from the default slot will get played automatically when \
        everything else fail."""

    @window = window
    @document = document
    @root = root || document.body

    @_initSchedulerRoot()

    @_run()

  _initSchedulerRoot: ->
    if not @root?
      console.warn "#{TAG} No root node specified."
      return

    onTransitionEnd = =>
      @_onTransitionEnd()
    @root.addEventListener 'webkitTransitionEnd', onTransitionEnd, false
    @root.style.setProperty 'opacity', '1'
    @root.style.setProperty 'transition', 'opacity 0.5s linear'

  _onTransitionEnd: ->
    console.log "#{TAG} Transition ended: #{new Date().getTime()}"
    if @_transitionEndCallback?
      @_transitionEndCallback()
      # make sure this callback will not be called again.
      @_transitionEndCallback = undefined

  _run: ->
    if @_exit
      console.log "#{TAG} Scheduler will exit."
      return

    st = new Date().getTime()
    done = (sname) =>
      et = new Date().getTime() - st
      console.log "#{TAG} #{sname} completed in #{et} msecs."
      process.nextTick => @_run()

    if @_viewOrder.length == 0
      @_renderDefaultView done

    else
      checked = 0
      loop
        if @_tryToRenderCurrent done
          break

        else
          checked++
          if checked >= @_viewOrder.length
            @_renderFallbackElseDefaultView done
            break

  _tryToRenderCurrent: (done) ->
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

  _renderFallbackElseDefaultView: (done) ->
    if @_fallbackViewOrder.length > 0
      for sname in @_fallbackViewOrder
        slot = @_fallbackSlots[sname]
        if slot.length > 0
          fallback = slot.shift()
          console.log "#{TAG} Rendering a fallback view from #{sname} for #{fallback.duration} msecs."
          @_render fallback, done
          return

    @_renderDefaultView done

  _renderDefaultView: (done) ->
    if @_defaultViewQueue.length > 0
      if @_defaultViewRenderIndex >= @_defaultViewQueue.length
        @_defaultViewRenderIndex = 0

      view = @_defaultViewQueue[@_defaultViewRenderIndex]
      @_defaultViewRenderIndex += 1
      console.warn "#{TAG} Rendering the default view for #{view.duration} msecs."
      @_render view, done

    else
      console.warn "#{TAG} BLACK SCREEN!!!!!!! for #{BLACK_SCREEN.duration} msecs."
      @_render BLACK_SCREEN, done

  _render: (view, done) ->
    try
      console.log "#{TAG} Rendering view #{view.slot}, video=#{view.isVideo}"

      view.callbacks?.begin?()

      @_fadeOut @root, =>
        if view.isVideo
          @_renderVideoView @root, view, done

        else
          @_renderHtmlView @root, view

          end = =>
            done view.slot
            @_onViewEnd view
            view.callbacks?.end?()

          global.setTimeout end, view.duration

        @_fadeIn @root, ->

    catch err
      console.log "#{TAG} Error while rendering #{view.slot} view. video=#{view.isVideo}, e=#{err?.message}"
      done view.slot
      view.callbacks?.error? err

  _renderHtmlView: (div, view) ->
    div.innerHTML = view.view
    view.callbacks?.ready?()

  _renderVideoView: (div, view, done) ->
    # clear existing content first.
    if div?
      while div.firstChild?
        div.removeChild div.firstChild

    @onVideoView? div, view.file, view.opts, (
      ->
        view.callbacks?.ready?()
    ), (
      =>
        done view.slot
        @_onViewEnd view
        view.callbacks?.end?()
    ), (
      (err) ->
        done view.slot
        view.callbacks?.error? err
    )

  _fadeOut: (element, cb) ->
    if not element?
      cb()
      return

    element.style.setProperty 'opacity', '0'
    @_transitionEndCallback = cb

  _fadeIn: (element, cb) ->
    if not element?
      cb()
      return

    element.style.setProperty 'opacity', '1'
    @_transitionEndCallback = cb

  _newDefaultView: (view) ->
    nview =
      slot: DEFAULT_VIEW

    if view.isVideo
      nview.isVideo = true
      nview.file = view.file

    else
      nview.isVideo = false
      nview.view = view.view
      nview.duration = view.duration

    nview

  _onViewEnd: (view) ->
    @onViewEnd? view

  _isNumeric: (n) ->
    !isNaN(parseFloat(n)) && isFinite(n)


module.exports = Scheduler
