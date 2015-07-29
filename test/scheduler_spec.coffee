sinon     = require 'sinon'
{expect}  = require('chai').use(require('sinon-chai'))

Scheduler = require '../src/index'

DEFAULT_VIEW = '__dv'
BLACK_SCREEN = '__bs'

describe 'Scheduler', ->
  beforeEach ->
    @scheduler = new Scheduler {}, (->), (->)

  afterEach ->

  describe 'register', ->
    it 'should register a slot', ->
      expect(@scheduler._slots).to.not.have.key 'view'
      expect(@scheduler._viewOrder).to.have.length 0

      @scheduler.register 'view'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view']

    it 'should create a slot for the fallback view', ->
      @scheduler.register 'view', 'fallback'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view']

      expect(@scheduler._fallbackSlots.fallback).to.have.length 0
      expect(@scheduler._fallbackViewOrder).to.deep.equal ['fallback']

    it 'should only update view order on duplicate registrations', ->
      @scheduler.register 'view'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view']

      @scheduler.register 'view'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view', 'view']

    it 'should not update fallback view order on duplicate registrations with fallback', ->
      @scheduler.register 'view', 'fallback'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view']
      expect(@scheduler._fallbackSlots.fallback).to.have.length 0
      expect(@scheduler._fallbackViewOrder).to.deep.equal ['fallback']

      @scheduler.register 'another', 'fallback'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._slots.another).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view', 'another']
      expect(@scheduler._fallbackSlots.fallback).to.have.length 0
      expect(@scheduler._fallbackViewOrder).to.deep.equal ['fallback']

      @scheduler.register 'view', 'fallback'
      expect(@scheduler._slots.view).to.have.length 0
      expect(@scheduler._slots.another).to.have.length 0
      expect(@scheduler._viewOrder).to.deep.equal ['view', 'another', 'view']
      expect(@scheduler._fallbackSlots.fallback).to.have.length 0
      expect(@scheduler._fallbackViewOrder).to.deep.equal ['fallback']

  describe 'submitView', ->
    it 'should throw if duration is not numeric', ->
      @scheduler.register 'view'
      fn = =>
        @scheduler.submitView 'view', '<html>', 'invalid-duration', {}

      expect(fn).to.throw RangeError

    it 'should throw if duration is not in the range', ->
      @scheduler.register 'view'
      fn = =>
        @scheduler.submitView 'view', '<html>', -1, {}
      expect(fn).to.throw RangeError

      fn = =>
        @scheduler.submitView 'view', '<html>', 0, {}
      expect(fn).to.throw RangeError

      fn = =>
        # max is currently set to 60 seconds.
        @scheduler.submitView 'view', '<html>', 70000, {}
      expect(fn).to.throw RangeError

    it "should throw if slot doesn't exists", ->
      fn = =>
        @scheduler.submitView 'view', '<html>', 1000, {}

      expect(fn).to.throw Error

      @scheduler.register 'view'
      expect(fn).to.not.throw

    it 'should submit the view', ->
      @scheduler.register 'view'
      begin = ->
      ready = ->
      end = ->
      error = ->

      submit = sinon.spy @scheduler, '_submit'

      @scheduler.submitView 'view', '<html>', 5000, {
        begin: begin
        ready: ready
        end: end
        error: error
      }, {
        view: {
          label: 'test'
        }
      }

      expect(submit).to.have.been.calledOnce
      expect(submit).to.have.been.calledWith
        slot: 'view'
        view: '<html>'
        duration: 5000
        isVideo: false
        opts:
          view:
            label: 'test'
        callbacks:
          begin: begin
          ready: ready
          end: end
          error: error

  describe 'submitVideo', ->
    it 'should submit the view', ->
      @scheduler.register 'view'
      begin = ->
      ready = ->
      end = ->
      error = ->

      submit = sinon.spy @scheduler, '_submit'

      @scheduler.submitVideo 'view', 'video-file', {
        begin: begin
        ready: ready
        end: end
        error: error
      }, {
        audio:
          enable: true
          volume: 0.7
        view:
          label: 'test'
      }

      expect(submit).to.have.been.calledOnce
      expect(submit).to.have.been.calledWith
        slot: 'view'
        file: 'video-file'
        opts:
          audio:
            enable: true
            volume: 0.7
          view:
            label: 'test'
        isVideo: true
        callbacks:
          begin: begin
          ready: ready
          end: end
          error: error

  describe '_submit', ->
    it 'should add the view to its slot', ->
      view =
        slot: 'view'
        extra: 'data'

      @scheduler.register 'view'
      @scheduler.register 'another'

      @scheduler._submit view
      expect(@scheduler._defaultViewQueue).to.have.length 0
      expect(@scheduler._slots['view']).to.deep.equal [{slot: 'view', extra: 'data'}]
      expect(@scheduler._slots['another']).to.deep.equal []

      view =
        slot: 'another'
        key: 'value'

      @scheduler._submit view
      expect(@scheduler._defaultViewQueue).to.have.length 0
      expect(@scheduler._slots['view']).to.deep.equal [{slot: 'view', extra: 'data'}]
      expect(@scheduler._slots['another']).to.deep.equal [{slot: 'another', key: 'value'}]

      view =
        slot: 'view'
        extra: 'more data'

      @scheduler._submit view
      expect(@scheduler._defaultViewQueue).to.have.length 0
      expect(@scheduler._slots['view']).to.deep.equal [
        {slot: 'view', extra: 'data'}
        {slot: 'view', extra: 'more data'}]
      expect(@scheduler._slots['another']).to.deep.equal [{slot: 'another', key: 'value'}]

    it 'should add the view to fallback slot', ->
      view =
        slot: 'fallback'
        extra: 'data'

      @scheduler.register 'view', 'fallback'
      @scheduler._submit view
      expect(@scheduler._slots['view']).to.deep.equal []
      expect(@scheduler._defaultViewQueue).to.have.length 0
      expect(@scheduler._fallbackSlots['fallback']).to.deep.equal [{slot: 'fallback', extra: 'data'}]

    it 'should prefer primary slots over fallback slots', ->
      view =
        slot: 'primary'
        extra: 'data'

      @scheduler.register 'primary', 'fallback'
      @scheduler.register 'another', 'primary'

      @scheduler._submit view
      expect(@scheduler._defaultViewQueue).to.have.length 0
      expect(@scheduler._slots['primary']).to.deep.equal [{slot: 'primary', extra: 'data'}]
      expect(@scheduler._fallbackSlots['primary']).to.deep.equal []

    it 'should throw if slot is unknown', ->
      view =
        slot: 'view'

      fn = =>
        @scheduler._submit view

      expect(fn).to.throw Error

    it 'should add the stripped view to the default queue in track mode', ->
      @scheduler.register 'primary', 'fallback'
      @scheduler.setDefaultView 'primary'
      expect(@scheduler._defaultViewTrackMode).to.be.true

      view =
        slot: 'primary'
        view: '<html>'
        duration: 1000
        opts:
          k: 'v'
        callbacks: {}
        isVideo: false

      expect(@scheduler._defaultViewQueue).to.have.length 0
      @scheduler._submit view
      expect(@scheduler._defaultViewQueue).to.have.length 1
      expect(@scheduler._defaultViewQueue[0]).to.deep.equal
        slot: DEFAULT_VIEW
        view: '<html>'
        duration: 1000
        isVideo: false
        opts:
          k: 'v'

    it 'should add the original view to the default queue in non-track mode', ->
      @scheduler.register 'primary', 'fallback'
      @scheduler.setDefaultView 'default'
      expect(@scheduler._defaultViewTrackMode).to.be.false

      callbacks =
        begin: ->
      view =
        slot: 'default'
        view: '<html>'
        duration: 1000
        opts:
          k: 'v'
        callbacks: callbacks
        isVideo: false

      expect(@scheduler._defaultViewQueue).to.have.length 0
      @scheduler._submit view
      expect(@scheduler._defaultViewQueue).to.have.length 1
      expect(@scheduler._defaultViewQueue[0]).to.deep.equal
        slot: DEFAULT_VIEW
        view: '<html>'
        duration: 1000
        isVideo: false
        callbacks: callbacks
        opts:
          k: 'v'

  describe 'start', ->
    it 'should set the root node', ->
      sinon.stub @scheduler, '_run', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      win =
        k: 'v'
      doc =
        body: 'test'

      @scheduler.start win, doc
      expect(@scheduler.root).to.equal 'test'

      @scheduler.start win, doc, null
      expect(@scheduler.root).to.equal 'test'

      @scheduler.start win, doc, undefined
      expect(@scheduler.root).to.equal 'test'

      @scheduler.start win, doc, 'root'
      expect(@scheduler.root).to.equal 'root'

    it 'should set health check parameters', ->
      sinon.stub @scheduler, '_run', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      win =
        k: 'v'
      doc =
        body: 'test'

      expect(@scheduler._started).to.be.false
      expect(@scheduler._schedulerStartTime).to.equal 0

      @scheduler.start win, doc

      expect(@scheduler._started).to.be.true
      expect(@scheduler._schedulerStartTime).to.be.above 0

  describe 'onHealthCheck', ->
    beforeEach ->
      @now = new Date().getTime()
      @clock = sinon.useFakeTimers @now

    afterEach ->
      @clock.restore()

    it 'should succeed when exit flag is set', ->
      sinon.stub @scheduler, '_run', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      win =
        k: 'v'
      doc =
        body: 'test'
      @scheduler.start win, doc
      @scheduler.exit()
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true

    it 'should succeed when scheduler has not been started yet', ->
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true

    it 'should fail when last run time is too old', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      sinon.stub @scheduler, '_renderDefaultView', ->
      win =
        k: 'v'
      doc =
        body: 'test'
      @scheduler.start win, doc
      @scheduler._run()
      expect(@scheduler._lastRunTime).to.be.equal @now
      # Move the clock more than HC_LAST_RUN_THRESHOLD.
      timePassed = 6 * 60 * 1000
      @clock.tick timePassed
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.false
      expect(res.reason).to.match /Scheduler has stopped working/
      @scheduler._run()
      expect(@scheduler._lastRunTime).to.be.equal @now + timePassed
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true

    it 'should not fail due to black screens if application just started', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      sinon.stub @scheduler, '_renderDefaultView', ->
      win =
        k: 'v'
      doc =
        body: 'test'
      @scheduler.start win, doc
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true
      @scheduler._consecutiveBlackScreens = 1000
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true

    it 'should fail if number of black screens exceed the threshold', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      sinon.stub @scheduler, '_renderDefaultView', ->
      win =
        k: 'v'
      doc =
        body: 'test'
      @scheduler.start win, doc
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true
      @scheduler._consecutiveBlackScreens = 1000
      @scheduler._run()
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true
      @clock.tick 6 * 60 * 1000
      # this is needed to bypass the _run() health check.
      @scheduler._run()
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.false
      expect(res.reason).to.match /Application is rendering black screens/

    it 'should succeed when all health checks passes', ->
      sinon.stub @scheduler, '_initSchedulerRoot', ->
      sinon.stub @scheduler, '_renderDefaultView', ->
      win =
        k: 'v'
      doc =
        body: 'test'
      @scheduler.start win, doc
      @scheduler._consecutiveBlackScreens = 0
      @scheduler._run()
      res = @scheduler.onHealthCheck()
      expect(res.status).to.be.true

  describe '_run', ->
    it 'should show the default view if there are no views', ->
      renderDefaultView = sinon.stub @scheduler, '_renderDefaultView', ->
      @scheduler._run()
      expect(renderDefaultView).to.have.been.calledOnce

    it 'should set the last run time', (done) ->
      sinon.stub @scheduler, '_renderDefaultView', ->
      expect(@scheduler._lastRunTime).to.equal 0
      @scheduler._run()
      expect(@scheduler._lastRunTime).to.be.above 0
      lr = @scheduler._lastRunTime
      t = =>
        @scheduler._run()
        expect(@scheduler._lastRunTime).to.be.above lr
        done()
      setTimeout t, 10

  describe '_tryToRenderCurrent', ->
    it 'should return when viewOrder is empty', ->
      done = sinon.stub()
      render = sinon.spy @scheduler, '_render'
      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.false
      expect(render).to.not.have.been.called
      expect(done).to.not.have.been.called

    it 'should return when there are no views', ->
      @scheduler.register 'view'
      @scheduler.register 'another'
      expect(@scheduler._current).to.be.equal 0
      done = sinon.stub()
      render = sinon.spy @scheduler, '_render'

      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.false
      expect(done).to.not.have.been.called
      expect(render).to.not.have.been.called
      expect(@scheduler._current).to.be.equal 1

      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.false
      expect(done).to.not.have.been.called
      expect(render).to.not.have.been.called
      expect(@scheduler._current).to.be.equal 2

      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.false
      expect(done).to.not.have.been.called
      expect(render).to.not.have.been.called
      expect(@scheduler._current).to.be.equal 1

    it 'should consume a view', ->
      @scheduler.register 'view'
      @scheduler.register 'another'
      done = sinon.stub()
      render = sinon.stub @scheduler, '_render', (v, d) ->

      @scheduler.submitView 'view', '<html>', 1000, {}, {view: {label: 'test'}}
      @scheduler.submitView 'view', '<other html>', 1000, {}

      expect(@scheduler._slots.view).to.have.length 2
      expect(@scheduler._current).to.be.equal 0

      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.true
      expect(@scheduler._current).to.be.equal 1
      expect(render).to.have.been.calledOnce
      expect(render.args[0][1]).to.equal done
      expect(render.args[0][0]).to.deep.equal
        slot: 'view'
        view: '<html>'
        duration: 1000
        isVideo: false
        opts:
          view:
            label: 'test'
        callbacks: {}
      expect(@scheduler._slots.view).to.have.length 1

      # this will try to view 'another'
      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.false
      expect(render).to.have.been.calledOnce
      expect(@scheduler._current).to.be.equal 2
      expect(@scheduler._slots.view).to.have.length 1

      res = @scheduler._tryToRenderCurrent done
      expect(res).to.be.true
      expect(@scheduler._current).to.be.equal 1
      expect(render).to.have.been.calledTwice
      expect(render.args[1][1]).to.equal done
      expect(render.args[1][0]).to.deep.equal
        slot: 'view'
        view: '<other html>'
        duration: 1000
        isVideo: false
        opts: undefined
        callbacks: {}
      expect(@scheduler._slots.view).to.have.length 0

  describe '_renderFallbackElseDefaultView', ->
    it 'should show the default view if there are no fallback slots', ->
      defaultView = sinon.stub @scheduler, '_renderDefaultView', ->
      render = sinon.stub @scheduler, '_render', (v, d) ->
      @scheduler._renderFallbackElseDefaultView ->
      expect(render).to.not.have.been.called
      expect(defaultView).to.have.been.calledOnce

    it 'should show the default view if there are no fallback views', ->
      @scheduler.register 'view', 'fallback'
      defaultView = sinon.stub @scheduler, '_renderDefaultView', ->
      render = sinon.stub @scheduler, '_render', (v, d) ->
      @scheduler._renderFallbackElseDefaultView ->
      expect(render).to.not.have.been.called
      expect(defaultView).to.have.been.calledOnce

    it 'should consume a fallback view', ->
      @scheduler.register 'view', 'fallback'
      @scheduler.submitView 'fallback', '<html>', 1000, {}
      defaultView = sinon.stub @scheduler, '_renderDefaultView', ->
      render = sinon.stub @scheduler, '_render', (v, d) ->
      done = ->
      expect(@scheduler._fallbackSlots['fallback']).to.have.length 1
      @scheduler._renderFallbackElseDefaultView done
      expect(render).to.have.been.calledOnce
      expect(defaultView).to.not.have.been.called
      expect(render.args[0][1]).to.equal done
      expect(render.args[0][0]).to.deep.equal
        slot: 'fallback'
        view: '<html>'
        duration: 1000
        isVideo: false
        opts: undefined
        callbacks: {}
      expect(@scheduler._fallbackSlots['fallback']).to.have.length 0

  describe 'setDefaultView', ->
    it 'should set a default view', ->
      expect(@scheduler._defaultView).to.be.an 'undefined'
      @scheduler.setDefaultView 'default-view'
      expect(@scheduler._defaultViewTrackMode).to.be.false
      expect(@scheduler._defaultView).to.be.equal 'default-view'

    it 'should set a primary slot as default', ->
      expect(@scheduler._defaultView).to.be.an 'undefined'
      @scheduler.register 'view'
      @scheduler.setDefaultView 'view'
      expect(@scheduler._defaultViewTrackMode).to.be.true
      expect(@scheduler._defaultView).to.be.equal 'view'

    it 'should set a fallback slot as default', ->
      expect(@scheduler._defaultView).to.be.an 'undefined'
      @scheduler.register 'view', 'fallback'
      @scheduler.setDefaultView 'fallback'
      expect(@scheduler._defaultViewTrackMode).to.be.true
      expect(@scheduler._defaultView).to.be.equal 'fallback'

  describe '_submitDefaultView', ->
    it 'should add the view to the queue', ->
      view =
        slot: 'view'
      expect(@scheduler._defaultViewQueue).to.have.length 0
      @scheduler._submitDefaultView view
      expect(@scheduler._defaultViewQueue).to.have.length 1
      @scheduler._submitDefaultView view
      expect(@scheduler._defaultViewQueue).to.have.length 2

    it 'should replace old views when queue is full in track mode', ->
      sv = (v) =>
        @scheduler._newDefaultView v

      @scheduler._defaultViewTrackMode = true
      @scheduler._defaultViewQueueLen = 2
      expect(@scheduler._defaultViewQueue).to.have.length 0
      @scheduler._submitDefaultView id: 1
      expect(@scheduler._defaultViewQueue).to.have.length 1
      @scheduler._submitDefaultView id: 2
      expect(@scheduler._defaultViewQueue).to.have.length 2
      expect(@scheduler._defaultViewQueue).to.deep.equal [{id: 1}, {id: 2}]
      @scheduler._submitDefaultView id: 3
      expect(@scheduler._defaultViewQueue).to.have.length 2
      expect(@scheduler._defaultViewQueue).to.deep.equal [{id: 2}, {id: 3}]
      @scheduler._submitDefaultView id: 4
      expect(@scheduler._defaultViewQueue).to.have.length 2
      expect(@scheduler._defaultViewQueue).to.deep.equal [{id: 3}, {id: 4}]

    it 'should keep adding views to the queue when not in track mode', ->
      sv = (v) =>
        @scheduler._newDefaultView v

      @scheduler._defaultViewTrackMode = false
      @scheduler._defaultViewQueueLen = 2
      expect(@scheduler._defaultViewQueue).to.have.length 0
      @scheduler._submitDefaultView id: 1
      expect(@scheduler._defaultViewQueue).to.have.length 1
      @scheduler._submitDefaultView id: 2
      expect(@scheduler._defaultViewQueue).to.have.length 2
      expect(@scheduler._defaultViewQueue).to.deep.equal [{id: 1}, {id: 2}]
      @scheduler._submitDefaultView id: 3
      expect(@scheduler._defaultViewQueue).to.have.length 3
      expect(@scheduler._defaultViewQueue).to.deep.equal [
        {id: 1}, {id: 2}, {id: 3}]

  describe '_renderDefaultView', ->
    it 'should show a default view without consuming it in track mode', ->
      @scheduler.register 'ad-view'
      @scheduler.setDefaultView 'ad-view'
      expect(@scheduler._defaultViewTrackMode).to.be.true
      @scheduler.submitView 'ad-view', '<html>', 1000, {}
      render = sinon.stub @scheduler, '_render', (v, d) ->
      expect(@scheduler._defaultViewQueue).to.have.length 1
      expect(@scheduler._defaultViewRenderIndex).to.be.equal 0
      done = ->
      @scheduler._renderDefaultView done
      expect(render).to.have.been.calledOnce
      expect(render).to.have.been.calledWith
        slot: DEFAULT_VIEW
        view: '<html>'
        duration: 1000
        isVideo: false
        opts: undefined
      expect(@scheduler._defaultViewQueue).to.have.length 1
      expect(@scheduler._defaultViewRenderIndex).to.be.equal 1

    it 'should consume a default view in non-track mode', ->
      @scheduler.register 'ad-view'
      @scheduler.setDefaultView 'default'
      expect(@scheduler._defaultViewTrackMode).to.be.false
      callbacks =
        begin: ->
      @scheduler.submitView 'default', '<html>', 1000, callbacks
      render = sinon.stub @scheduler, '_render', (v, d) ->
      expect(@scheduler._defaultViewQueue).to.have.length 1
      expect(@scheduler._defaultViewRenderIndex).to.be.equal 0
      done = ->
      @scheduler._renderDefaultView done
      expect(render).to.have.been.calledOnce
      expect(render).to.have.been.calledWith
        slot: DEFAULT_VIEW
        view: '<html>'
        duration: 1000
        isVideo: false
        callbacks: callbacks
        opts: undefined
      expect(@scheduler._defaultViewQueue).to.have.length 0
      expect(@scheduler._defaultViewRenderIndex).to.be.equal 0

    it 'should render the black screen if there are no default views available', ->
      render = sinon.stub @scheduler, '_render', (v, d) ->
      done = ->
      expect(@scheduler._consecutiveBlackScreens).to.be.equal 0
      @scheduler._renderDefaultView done
      expect(render).to.have.been.calledOnce
      view = render.args[0][0]
      expect(view.slot).to.be.equal BLACK_SCREEN
      expect(@scheduler._consecutiveBlackScreens).to.be.equal 1

  describe '_render', ->
    beforeEach ->
      @clock = sinon.useFakeTimers()

    afterEach ->
      @clock.restore()

    it 'should call the begin callback', ->
      begin = sinon.stub()
      view =
        slot: 'view'
        view: '<html>'
        isVideo: false
        duration: 1000
        callbacks:
          begin: begin

      @scheduler._render view, ->
      expect(begin).to.have.been.calledOnce

    it 'should call the error callback on error', ->
      begin = sinon.stub()
      ready = sinon.stub()
      error = sinon.stub()
      end = sinon.stub()

      get = sinon.stub @scheduler, '_fadeOut', ->
        throw new Error('error')

      view =
        slot: 'view'
        view: '<html>'
        isVideo: false
        duration: 1000
        callbacks:
          begin: begin
          ready: ready
          end: end
          error: error

      done = sinon.stub()
      @scheduler._render view, done
      expect(get).to.have.been.calledOnce
      expect(begin).to.have.been.calledOnce
      expect(error).to.have.been.calledOnce
      expect(done).to.have.been.calledOnce
      expect(done).to.have.been.calledWith 'view'
      expect(ready).to.not.have.been.called
      expect(end).to.not.have.been.called

    it 'should render html', (done) ->
      begin = sinon.stub()
      ready = sinon.stub()
      error = sinon.stub()
      end = sinon.stub()
      div = {}
      @scheduler.document =
        body:
          appendChild: ->
      @scheduler.root = @scheduler.document.body
      fadeIn = sinon.stub @scheduler, '_fadeIn', ->
      video = sinon.stub @scheduler, '_renderVideoView', ->
      html = sinon.spy @scheduler, '_renderHtmlView'
      onViewEnd = sinon.stub @scheduler, '_onViewEnd', ->

      sinon.stub @scheduler, '_fadeOut', (root, cb) =>
        cb div

        expect(begin).to.have.been.calledOnce
        expect(ready).to.have.been.calledOnce
        expect(error).to.not.have.been.called
        expect(video).to.not.have.been.called
        expect(html).to.have.been.calledOnce
        expect(end).to.not.have.been.called
        expect(onViewEnd).to.not.have.been.called
        expect(renderDone).to.not.have.been.called
        expect(fadeIn).to.have.been.calledOnce

        @clock.tick 1000
        expect(onViewEnd).to.have.been.calledOnce
        expect(renderDone).to.have.been.calledOnce
        expect(renderDone).to.have.been.calledWith 'view'

        done()

      view =
        slot: 'view'
        view: '<html>'
        isVideo: false
        duration: 1000
        callbacks:
          begin: begin
          ready: ready
          end: end
          error: error

      renderDone = sinon.stub()
      @scheduler._render view, renderDone

    it 'should render video', (done) ->
      begin = sinon.stub()
      error = sinon.stub()
      end = sinon.stub()
      div = {}
      @scheduler.document =
        body:
          appendChild: ->
      @scheduler.root = @scheduler.document.body
      fadeIn = sinon.stub @scheduler, '_fadeIn', ->
      video = sinon.stub @scheduler, '_renderVideoView', ->
      html = sinon.stub @scheduler, '_renderHtmlView', ->
      onViewEnd = sinon.stub @scheduler, '_onViewEnd', ->

      sinon.stub @scheduler, '_fadeOut', (root, cb) =>
        cb div

        expect(begin).to.have.been.calledOnce
        expect(error).to.not.have.been.called
        expect(video).to.have.been.calledOnce
        expect(html).to.not.have.been.called
        expect(end).to.not.have.been.called
        expect(onViewEnd).to.not.have.been.called
        expect(renderDone).to.not.have.been.called
        expect(fadeIn).to.have.been.calledOnce

        @clock.tick 1000
        expect(onViewEnd).to.not.have.been.called
        expect(renderDone).to.not.have.been.called

        done()

      view =
        slot: 'view'
        file: 'video-file'
        isVideo: true
        duration: 1000
        callbacks:
          begin: begin
          end: end
          error: error

      renderDone = sinon.stub()
      @scheduler._render view, renderDone

  describe '_renderHtmlView', ->
    it 'should call the ready callback', ->
      ready = sinon.spy()

      view =
        slot: 'view'
        view: '<html>'
        isVideo: false
        duration: 1000
        callbacks:
          ready: ready

      div = {}
      @scheduler._renderHtmlView div, view
      expect(div.innerHTML).to.be.equal '<html>'
      expect(ready).to.have.been.calledOnce

  describe '_renderVideoView', ->
    it 'should clean up the previous view', (done) ->
      div =
        innerHTML = 'test'

      view =
        slot: 'view'
        file: 'video-file'
        isVideo: true
        duration: 1000

      @scheduler.onVideoView = (div, file, opts, ready, success, error) ->
        done()

      @scheduler._renderVideoView div, view, ->
      expect(div.innerHTML).to.be.empty

    it 'should call the ready and done callbacks when there are no errors', ->
      ready = sinon.spy()
      done = sinon.spy()
      end = sinon.spy()
      error = sinon.spy()
      div = {}
      view =
        slot: 'view'
        file: 'video-file'
        isVideo: true
        duration: 1000
        callbacks:
          ready: ready
          end: end
          error: error

      @scheduler.onVideoView = (div, file, opts, onready, onsuccess, onerror) ->
        onready()
        onsuccess()

      @scheduler._renderVideoView div, view, done
      expect(ready).to.have.been.calledOnce
      expect(end).to.have.been.calledOnce
      expect(done).to.have.been.calledOnce
      expect(error).to.not.have.been.called

    it 'should call the error callback when there is an error', ->
      ready = sinon.spy()
      end = sinon.spy()
      done = sinon.spy()
      error = sinon.spy()
      div = {}
      view =
        slot: 'view'
        file: 'video-file'
        isVideo: true
        duration: 1000
        callbacks:
          ready: ready
          end: end
          error: error

      @scheduler.onVideoView = (div, file, opts, onready, onsuccess, onerror) ->
        onerror()

      @scheduler._renderVideoView div, view, done
      expect(ready).to.not.have.been.called
      expect(end).to.not.have.been.called
      expect(error).to.have.been.calledOnce
      expect(done).to.have.been.calledOnce

  describe '_fadeOut', ->
    it 'should set elements opacity and _transitionEndCallback', ->
      el =
        style:
          setProperty: sinon.spy()

      cb = sinon.spy()

      @scheduler._fadeOut el, cb
      expect(cb).to.not.have.been.called
      expect(@scheduler._transitionEndCallback).to.equal cb
      expect(el.style.setProperty).to.have.been.calledOnce
      expect(el.style.setProperty).to.have.been.calledWith 'opacity', '0'

    it 'should call the callback immediately when element is empty', ->
      cb = sinon.spy()

      @scheduler._fadeOut undefined, cb
      expect(cb).to.have.been.calledOnce

  describe '_fadeIn', ->
    it 'should set elements opacity and _transitionEndCallback', ->
      el =
        style:
          setProperty: sinon.spy()

      cb = sinon.spy()

      @scheduler._fadeIn el, cb
      expect(cb).to.not.have.been.called
      expect(@scheduler._transitionEndCallback).to.equal cb
      expect(el.style.setProperty).to.have.been.calledOnce
      expect(el.style.setProperty).to.have.been.calledWith 'opacity', '1'

    it 'should call the callback immediately when element is empty', ->
      cb = sinon.spy()

      @scheduler._fadeIn undefined, cb
      expect(cb).to.have.been.calledOnce

  describe '_onTransitionEnd', ->
    it 'should call the callback and set it to undefined afterwards', ->
      cb = sinon.spy()
      @scheduler._transitionEndCallback = cb
      @scheduler._onTransitionEnd()
      expect(cb).to.have.been.calledOnce
      expect(@scheduler._transitionEndCallback).to.be.undefined

  describe '_newDefaultView', ->
    it 'should update slot name', ->
     callbacks =
        begin: ->
      v =
        slot: 'view'
        view: '<html>'
        duration: 5000
        isVideo: false
        opts:
          view:
            label: 'test'
        callbacks: callbacks
      nv = @scheduler._newDefaultView v
      expect(nv).to.deep.equal
        slot: DEFAULT_VIEW
        view: '<html>'
        duration: 5000
        isVideo: false
        opts:
          view:
            label: 'test'
        callbacks: callbacks

    it 'should strip callbacks in track mode', ->
     callbacks =
        begin: ->
      v =
        slot: 'view'
        view: '<html>'
        duration: 5000
        isVideo: false
        opts:
          view:
            label: 'test'
        callbacks: callbacks
      @scheduler._defaultViewTrackMode = true
      nv = @scheduler._newDefaultView v
      expect(nv).to.deep.equal
        slot: DEFAULT_VIEW
        view: '<html>'
        duration: 5000
        isVideo: false
        opts:
          view:
            label: 'test'

  describe '_onViewEnd', ->
    it 'should call the onViewEnd callback', ->
      view =
        slot: 'test'

      onViewEnd = sinon.spy()
      scheduler = new Scheduler {}, (->), onViewEnd
      scheduler._onViewEnd view
      expect(onViewEnd).to.have.been.calledOnce
      expect(onViewEnd).to.have.been.calledWith view

    it 'should reset the black screen counter when the view is not a black screen', ->
      view =
        slot: 'test'
      @scheduler._consecutiveBlackScreens = 10
      @scheduler._onViewEnd view
      expect(@scheduler._consecutiveBlackScreens).to.be.equal 0

    it 'should not reset the black screen counter when the view is a black screen', ->
      view =
        slot: BLACK_SCREEN
      @scheduler._consecutiveBlackScreens = 10
      @scheduler._onViewEnd view
      expect(@scheduler._consecutiveBlackScreens).to.be.equal 10
