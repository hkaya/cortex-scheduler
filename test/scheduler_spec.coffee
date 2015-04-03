sinon     = require 'sinon'
{expect}  = require('chai').use(require('sinon-chai'))

Scheduler = require '../src/index'

describe 'Scheduler', ->
  beforeEach ->
    @scheduler = new Scheduler ->

  afterEach ->

  it 'should fail if no default view provided', ->
    expect(-> new Scheduler()).to.throw 'Scheduler needs a valid default view.'
    expect(-> new Scheduler(undefined)).to.throw 'Scheduler needs a valid default view.'
    expect(-> new Scheduler(null)).to.throw 'Scheduler needs a valid default view.'
    expect(-> new Scheduler(->)).to.not.throw 'Scheduler needs a valid default view.'

  describe 'register', ->
    it 'should create a new slot', ->
      @scheduler.register('test-view')
      expect(@scheduler.slots).to.have.key 'test-view'
      expect(@scheduler.viewOrder).to.have.length 1
      expect(@scheduler.viewOrder).to.contain 'test-view'

    it 'should update the view order', ->
      @scheduler.register('test-view')
      expect(@scheduler.slots['test-view']).to.have.length 0
      expect(@scheduler.viewOrder).to.have.length 1
      expect(@scheduler.viewOrder).to.deep.equal ['test-view']

      @scheduler.slots['test-view'].push (->)

      @scheduler.register('test-view')
      expect(@scheduler.slots['test-view']).to.have.length 1
      expect(@scheduler.viewOrder).to.have.length 2
      expect(@scheduler.viewOrder).to.deep.equal ['test-view', 'test-view']

      @scheduler.register('another-view')
      expect(@scheduler.slots['test-view']).to.have.length 1
      expect(@scheduler.slots['another-view']).to.have.length 0
      expect(@scheduler.viewOrder).to.have.length 3
      expect(@scheduler.viewOrder).to.deep.equal ['test-view', 'test-view', 'another-view']

    it 'should create a fallback slot', ->
      @scheduler.register('test-view', 'fallback')
      expect(@scheduler.slots).to.have.key 'test-view'
      expect(@scheduler.viewOrder).to.have.length 1
      expect(@scheduler.viewOrder).to.contain 'test-view'
      expect(@scheduler.fallbackSlots).to.have.key 'fallback'
      expect(@scheduler.fallbackViewOrder).to.have.length 1
      expect(@scheduler.fallbackViewOrder).to.contain 'fallback'

    it 'should update the fallback order only when a new fallback slot added', ->
      @scheduler.register('test-view', 'fallback')
      expect(@scheduler.slots).to.have.key 'test-view'
      expect(@scheduler.viewOrder).to.have.length 1
      expect(@scheduler.viewOrder).to.contain 'test-view'
      expect(@scheduler.fallbackSlots).to.have.key 'fallback'
      expect(@scheduler.fallbackViewOrder).to.have.length 1

      @scheduler.register('test-view', 'fallback')
      expect(@scheduler.slots).to.have.key 'test-view'
      expect(@scheduler.viewOrder).to.have.length 2
      expect(@scheduler.viewOrder).to.deep.equal ['test-view', 'test-view']
      expect(@scheduler.fallbackSlots).to.have.key 'fallback'
      expect(@scheduler.fallbackViewOrder).to.have.length 1

      @scheduler.register('another-view', 'another-fallback')
      expect(@scheduler.slots).to.have.property 'test-view'
      expect(@scheduler.slots).to.have.property 'another-view'
      expect(@scheduler.viewOrder).to.have.length 3
      expect(@scheduler.viewOrder).to.deep.equal ['test-view', 'test-view', 'another-view']
      expect(@scheduler.fallbackViewOrder).to.have.length 2
      expect(@scheduler.fallbackSlots).to.have.property 'fallback'
      expect(@scheduler.fallbackSlots).to.have.property 'another-fallback'
      expect(@scheduler.fallbackViewOrder).to.deep.equal ['fallback', 'another-fallback']

  describe 'submit', ->
    it 'should fail if the slot does not exist', ->
      expect(=> @scheduler.submit('test-view', ->)).to.throw /Scheduler doesn't know about slot/

    it 'should add the view to proper slot', ->
      @scheduler.register('first-view')
      expect(@scheduler.slots['first-view']).to.have.length 0

      fview = (done) ->
      @scheduler.submit 'first-view', fview
      expect(@scheduler.slots['first-view']).to.have.length 1
      expect(@scheduler.slots['first-view']).to.deep.equal [fview]

      @scheduler.register('second-view')
      expect(@scheduler.slots['first-view']).to.have.length 1
      expect(@scheduler.slots['second-view']).to.have.length 0

      sview = (done) ->
      @scheduler.submit 'second-view', sview
      expect(@scheduler.slots['second-view']).to.deep.equal [sview]
      expect(@scheduler.slots['first-view']).to.deep.equal [fview]

      fview2 = (done) ->
      @scheduler.submit 'first-view', fview2
      expect(@scheduler.slots['second-view']).to.deep.equal [sview]
      expect(@scheduler.slots['first-view']).to.deep.equal [fview, fview2]

    it 'should add the view to the fallback slot', ->
      @scheduler.register 'primary', 'fallback'
      expect(@scheduler.slots['primary']).to.have.length 0
      expect(@scheduler.fallbackSlots['fallback']).to.have.length 0

      fview = (done) ->
      @scheduler.submit 'fallback', fview
      expect(@scheduler.slots['primary']).to.have.length 0
      expect(@scheduler.fallbackSlots['fallback']).to.have.length 1

  describe 'run', ->
    describe 'tryToViewCurrent', ->
      it 'should return false if view order is empty', ->
        expect(@scheduler._tryToViewCurrent(->)).to.be.false

      it 'should return try the first slot if current is too large', ->
        @scheduler.register('view')
        @scheduler.submit 'view', ->

        expect(@scheduler.current).to.equal 0

        @scheduler.current = 10
        @scheduler._tryToViewCurrent(->)
        # it first resets current to 0, then increments it.
        expect(@scheduler.current).to.equal 1

      it 'should return false if there are no views to display', ->
        @scheduler.register('view')
        expect(@scheduler._tryToViewCurrent(->)).to.be.false

      it 'should increment current even if there are no views to display', ->
        @scheduler.register('view')
        expect(@scheduler.current).to.equal 0
        expect(@scheduler._tryToViewCurrent(->)).to.be.false
        expect(@scheduler.current).to.equal 1

      it 'should call a view and remove it from the slot', (done) ->
        @scheduler.register('view')

        @scheduler.submit 'view', (cb) =>
          expect(@scheduler.current).to.equal 1
          expect(@scheduler.slots['view']).to.have.length 0
          cb()

        expect(@scheduler.slots['view']).to.have.length 1

        res = @scheduler._tryToViewCurrent done
        expect(res).to.be.true

    it 'should run default view if there are no registered views', (done) ->
      defaultView = (cb) =>
        done()

      scheduler = new Scheduler defaultView
      scheduler._run()

    it 'should run a fallback view if there are no available views', ->
      defaultView = sinon.spy()
      fallbackView = sinon.spy()

      scheduler = new Scheduler defaultView
      scheduler.register 'first', 'fallback'
      scheduler.register 'second'
      scheduler.submit 'fallback', fallbackView
      scheduler._run()

      expect(defaultView).to.not.have.been.called
      expect(fallbackView).to.have.been.called

    it 'should run default view if there are no available views', (done) ->
      defaultView = (cb) =>
        done()

      scheduler = new Scheduler defaultView
      scheduler.register 'first'
      scheduler.register 'second'
      scheduler._run()

    it 'should call views', ->
      defaultView = sinon.spy()

      scheduler = new Scheduler defaultView
      scheduler.register 'first'
      scheduler.register 'second'
      scheduler.register 'third'

      first = sinon.spy()
      second = sinon.spy()
      third = sinon.spy()

      scheduler.submit 'first', first
      scheduler.submit 'second', second
      scheduler.submit 'third', third

      scheduler._run()

      expect(defaultView).to.not.have.been.called
      expect(first).to.have.been.calledOnce
      expect(second).to.not.have.been.called
      expect(third).to.not.have.been.called

      expect(scheduler.slots['first']).to.have.length 0
      expect(scheduler.slots['second']).to.have.length 1
      expect(scheduler.slots['third']).to.have.length 1

      scheduler._run()

      expect(defaultView).to.not.have.been.called
      expect(first).to.have.been.calledOnce
      expect(second).to.have.been.calledOnce
      expect(third).to.not.have.been.called

      expect(scheduler.slots['first']).to.have.length 0
      expect(scheduler.slots['second']).to.have.length 0
      expect(scheduler.slots['third']).to.have.length 1

      scheduler._run()

      expect(defaultView).to.not.have.been.called
      expect(first).to.have.been.calledOnce
      expect(second).to.have.been.calledOnce
      expect(third).to.have.been.calledOnce

      expect(scheduler.slots['first']).to.have.length 0
      expect(scheduler.slots['second']).to.have.length 0
      expect(scheduler.slots['third']).to.have.length 0

      scheduler._run()

      expect(defaultView).to.have.been.calledOnce
      expect(first).to.have.been.calledOnce
      expect(second).to.have.been.calledOnce
      expect(third).to.have.been.calledOnce

      expect(scheduler.slots['first']).to.have.length 0
      expect(scheduler.slots['second']).to.have.length 0
      expect(scheduler.slots['third']).to.have.length 0

      scheduler.submit 'first', first
      scheduler._run()

      expect(defaultView).to.have.been.calledOnce
      expect(first).to.have.been.calledTwice
      expect(second).to.have.been.calledOnce
      expect(third).to.have.been.calledOnce

      expect(scheduler.slots['first']).to.have.length 0
      expect(scheduler.slots['second']).to.have.length 0
      expect(scheduler.slots['third']).to.have.length 0
