(function() {
  var BLACK_SCREEN, BLACK_SCREEN_SLOT_NAME, DEFAULT_VIEW, Scheduler, TAG;

  TAG = 'scheduler:';

  DEFAULT_VIEW = '__dv';

  BLACK_SCREEN_SLOT_NAME = '__bs';

  BLACK_SCREEN = {
    slot: BLACK_SCREEN_SLOT_NAME,
    view: "",
    duration: 1000,
    isVideo: false,
    callbacks: {
      error: function(err) {
        return console.log(TAG + " Even black screens fail... err=" + (err != null ? err.message : void 0));
      }
    }
  };

  Scheduler = (function() {
    function Scheduler(opts, onVideoView, onViewEnd) {
      this.onVideoView = onVideoView;
      this.onViewEnd = onViewEnd;
      if (opts == null) {
        opts = {};
      }
      this._maxViewDuration = 60 * 1000;
      if (opts.maxViewDuration != null) {
        this._maxViewDuration = opts.maxViewDuration;
      }
      this._defaultViewQueueLen = 10;
      if (opts.defaultViewQueueLen != null) {
        this._defaultViewQueueLen = opts.defaultViewQueueLen;
      }
      this._defaultView = void 0;
      this._defaultViewQueue = [];
      this._defaultViewRenderIndex = 0;
      this._slots = {};
      this._viewOrder = [];
      this._fallbackSlots = {};
      this._fallbackViewOrder = [];
      this._current = 0;
      this._transitionEndCallback = void 0;
      this._exit = false;
    }

    Scheduler.prototype.exit = function() {
      return this._exit = true;
    };

    Scheduler.prototype.register = function(sname, fallback) {
      console.log(TAG + " Registering new slot: " + sname + " with fallback: " + fallback);
      if (this._slots[sname] == null) {
        this._slots[sname] = [];
      }
      this._viewOrder.push(sname);
      if (!!fallback) {
        if (this._fallbackSlots[fallback] == null) {
          this._fallbackSlots[fallback] = [];
          return this._fallbackViewOrder.push(fallback);
        }
      }
    };

    Scheduler.prototype.setDefaultView = function(sname) {
      console.log(TAG + " Setting default view to " + sname);
      if (sname in this._slots || sname in this._fallbackSlots) {
        return this._defaultView = sname;
      } else {
        throw new Error("Unknown view slot: " + sname);
      }
    };

    Scheduler.prototype._submitDefaultView = function(view) {
      if (this._defaultViewQueue.length >= this._defaultViewQueueLen) {
        this._defaultViewQueue.shift();
      }
      return this._defaultViewQueue.push(view);
    };

    Scheduler.prototype.submitView = function(sname, view, duration, callbacks) {
      console.log(TAG + " New view to be submitted to slot " + sname + " with duration " + duration);
      if (!this._isNumeric(duration)) {
        throw new RangeError("View duration should be in the range of (0, " + this._maxViewDuration + ")");
      }
      duration = Number(duration);
      if (duration <= 0 || duration > this._maxViewDuration) {
        throw new RangeError("View duration should be in the range of (0, " + this._maxViewDuration + ")");
      }
      return this._submit({
        slot: sname,
        view: view,
        duration: duration,
        callbacks: callbacks,
        isVideo: false
      });
    };

    Scheduler.prototype.submitVideo = function(sname, file, callbacks, opts) {
      return this._submit({
        slot: sname,
        file: file,
        callbacks: callbacks,
        opts: opts,
        isVideo: true
      });
    };

    Scheduler.prototype._submit = function(view) {
      if (view.slot === this._defaultView) {
        this._submitDefaultView(this._newDefaultView(view));
      }
      if (view.slot in this._slots) {
        return this._slots[view.slot].push(view);
      } else if (view.slot in this._fallbackSlots) {
        return this._fallbackSlots[view.slot].push(view);
      } else {
        throw new Error("Unknown view slot: " + view.slot);
      }
    };

    Scheduler.prototype.start = function(window, document, root) {
      if (this._defaultView == null) {
        console.warn("Scheduler: No default view is set. Consider selecting\none of the view slots as default by calling setDefaultView(slotName). Views from the default slot will get played automatically when everything else fail.");
      }
      this.window = window;
      this.document = document;
      this.root = root || document.body;
      this._initSchedulerRoot();
      return this._run();
    };

    Scheduler.prototype._initSchedulerRoot = function() {
      var onTransitionEnd;
      if (this.root == null) {
        console.warn(TAG + " No root node specified.");
        return;
      }
      onTransitionEnd = (function(_this) {
        return function() {
          return _this._onTransitionEnd();
        };
      })(this);
      this.root.addEventListener('webkitTransitionEnd', onTransitionEnd, false);
      this.root.style.setProperty('opacity', '1');
      return this.root.style.setProperty('transition', 'opacity 0.5s linear');
    };

    Scheduler.prototype._onTransitionEnd = function() {
      console.log(TAG + " Transition ended: " + (new Date().getTime()));
      if (this._transitionEndCallback != null) {
        this._transitionEndCallback();
        return this._transitionEndCallback = void 0;
      }
    };

    Scheduler.prototype._run = function() {
      var checked, done, results, st;
      if (this._exit) {
        console.log(TAG + " Scheduler will exit.");
        return;
      }
      st = new Date().getTime();
      done = (function(_this) {
        return function(sname) {
          var et;
          et = new Date().getTime() - st;
          console.log(TAG + " " + sname + " completed in " + et + " msecs.");
          return process.nextTick(function() {
            return _this._run();
          });
        };
      })(this);
      if (this._viewOrder.length === 0) {
        return this._renderDefaultView(done);
      } else {
        checked = 0;
        results = [];
        while (true) {
          if (this._tryToRenderCurrent(done)) {
            break;
          } else {
            checked++;
            if (checked >= this._viewOrder.length) {
              this._renderFallbackElseDefaultView(done);
              break;
            } else {
              results.push(void 0);
            }
          }
        }
        return results;
      }
    };

    Scheduler.prototype._tryToRenderCurrent = function(done) {
      var cslot, sname, view;
      if (this._viewOrder.length === 0) {
        return false;
      }
      if (this._current >= this._viewOrder.length) {
        this._current = 0;
      }
      sname = this._viewOrder[this._current];
      cslot = this._slots[sname];
      this._current++;
      if ((cslot != null ? cslot.length : void 0) > 0) {
        view = cslot.shift();
        console.log(TAG + " Rendering a view from " + sname + " for " + view.duration + " msecs.");
        this._render(view, done);
        return true;
      }
      return false;
    };

    Scheduler.prototype._renderFallbackElseDefaultView = function(done) {
      var fallback, i, len, ref, slot, sname;
      if (this._fallbackViewOrder.length > 0) {
        ref = this._fallbackViewOrder;
        for (i = 0, len = ref.length; i < len; i++) {
          sname = ref[i];
          slot = this._fallbackSlots[sname];
          if (slot.length > 0) {
            fallback = slot.shift();
            console.log(TAG + " Rendering a fallback view from " + sname + " for " + fallback.duration + " msecs.");
            this._render(fallback, done);
            return;
          }
        }
      }
      return this._renderDefaultView(done);
    };

    Scheduler.prototype._renderDefaultView = function(done) {
      var view;
      if (this._defaultViewQueue.length > 0) {
        if (this._defaultViewRenderIndex >= this._defaultViewQueue.length) {
          this._defaultViewRenderIndex = 0;
        }
        view = this._defaultViewQueue[this._defaultViewRenderIndex];
        this._defaultViewRenderIndex += 1;
        console.warn(TAG + " Rendering the default view for " + view.duration + " msecs.");
        return this._render(view, done);
      } else {
        console.warn(TAG + " BLACK SCREEN!!!!!!! for " + BLACK_SCREEN.duration + " msecs.");
        return this._render(BLACK_SCREEN, done);
      }
    };

    Scheduler.prototype._render = function(view, done) {
      var err, ref, ref1;
      try {
        console.log(TAG + " Rendering view " + view.slot + ", video=" + view.isVideo);
        if ((ref = view.callbacks) != null) {
          if (typeof ref.begin === "function") {
            ref.begin();
          }
        }
        return this._fadeOut(this.root, (function(_this) {
          return function() {
            var end;
            if (view.isVideo) {
              _this._renderVideoView(_this.root, view, done);
            } else {
              _this._renderHtmlView(_this.root, view);
              end = function() {
                var ref1;
                done(view.slot);
                _this._onViewEnd(view.slot);
                return (ref1 = view.callbacks) != null ? typeof ref1.end === "function" ? ref1.end() : void 0 : void 0;
              };
              global.setTimeout(end, view.duration);
            }
            return _this._fadeIn(_this.root, function() {});
          };
        })(this));
      } catch (_error) {
        err = _error;
        console.log(TAG + " Error while rendering " + view.slot + " view. video=" + view.isVideo + ", e=" + (err != null ? err.message : void 0));
        done(view.slot);
        return (ref1 = view.callbacks) != null ? typeof ref1.error === "function" ? ref1.error(err) : void 0 : void 0;
      }
    };

    Scheduler.prototype._renderHtmlView = function(div, view) {
      var ref;
      div.innerHTML = view.view;
      return (ref = view.callbacks) != null ? typeof ref.ready === "function" ? ref.ready() : void 0 : void 0;
    };

    Scheduler.prototype._renderVideoView = function(div, view, done) {
      if (div != null) {
        while (div.firstChild != null) {
          div.removeChild(div.firstChild);
        }
      }
      return typeof this.onVideoView === "function" ? this.onVideoView(div, view.file, view.opts, (function() {
        var ref;
        return (ref = view.callbacks) != null ? typeof ref.ready === "function" ? ref.ready() : void 0 : void 0;
      }), ((function(_this) {
        return function() {
          var ref;
          done(view.slot);
          _this._onViewEnd(view.slot);
          return (ref = view.callbacks) != null ? typeof ref.end === "function" ? ref.end() : void 0 : void 0;
        };
      })(this)), (function(err) {
        var ref;
        done(view.slot);
        return (ref = view.callbacks) != null ? typeof ref.error === "function" ? ref.error(err) : void 0 : void 0;
      })) : void 0;
    };

    Scheduler.prototype._fadeOut = function(element, cb) {
      if (element == null) {
        cb();
        return;
      }
      element.style.setProperty('opacity', '0');
      return this._transitionEndCallback = cb;
    };

    Scheduler.prototype._fadeIn = function(element, cb) {
      if (element == null) {
        cb();
        return;
      }
      element.style.setProperty('opacity', '1');
      return this._transitionEndCallback = cb;
    };

    Scheduler.prototype._newDefaultView = function(view) {
      var nview;
      nview = {
        slot: DEFAULT_VIEW
      };
      if (view.isVideo) {
        nview.isVideo = true;
        nview.file = view.file;
      } else {
        nview.isVideo = false;
        nview.view = view.view;
        nview.duration = view.duration;
      }
      return nview;
    };

    Scheduler.prototype._onViewEnd = function(sname) {
      return typeof this.onViewEnd === "function" ? this.onViewEnd(sname) : void 0;
    };

    Scheduler.prototype._isNumeric = function(n) {
      return !isNaN(parseFloat(n)) && isFinite(n);
    };

    return Scheduler;

  })();

  module.exports = Scheduler;

}).call(this);
