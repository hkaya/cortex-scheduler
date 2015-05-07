(function() {
  var BLACK_SCREEN, BLACK_SCREEN_SLOT_NAME, CONTENT_DIV_ID, DEFAULT_VIEW, MAX_VIEW_DURATION, Scheduler, TAG;

  TAG = 'scheduler:';

  MAX_VIEW_DURATION = 60 * 1000;

  CONTENT_DIV_ID = '__cortex_main';

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
    function Scheduler(onVideoView, onViewEnd) {
      var obj;
      this.onVideoView = onVideoView;
      this.onViewEnd = onViewEnd;
      this._slots = (
        obj = {},
        obj["" + DEFAULT_VIEW] = [],
        obj
      );
      this._viewOrder = [];
      this._fallbackSlots = {};
      this._fallbackViewOrder = [];
      this._current = 0;
    }

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

    Scheduler.prototype.submitDefaultView = function(view, duration, callbacks) {
      return this.submitView(DEFAULT_VIEW, view, duration, callbacks);
    };

    Scheduler.prototype.submitView = function(sname, view, duration, callbacks) {
      console.log(TAG + " New view to be submitted to slot " + sname + " with duration " + duration);
      if (!this._isNumeric(duration)) {
        throw new RangeError("View duration should be in the range of (0, " + MAX_VIEW_DURATION + ")");
      }
      duration = Number(duration);
      if (duration <= 0 || duration > MAX_VIEW_DURATION) {
        throw new RangeError("View duration should be in the range of (0, " + MAX_VIEW_DURATION + ")");
      }
      return this._submit({
        slot: sname,
        view: view,
        duration: duration,
        callbacks: callbacks,
        isVideo: false
      });
    };

    Scheduler.prototype.submitVideo = function(sname, file, callbacks) {
      return this._submit({
        slot: sname,
        file: file,
        callbacks: callbacks,
        isVideo: true
      });
    };

    Scheduler.prototype._submit = function(view) {
      if (view.slot in this._slots) {
        return this._slots[view.slot].push(view);
      } else if (view.slot in this._fallbackSlots) {
        return this._fallbackSlots[view.slot].push(view);
      } else {
        throw new Error("Unknown view slot: " + view.slot);
      }
    };

    Scheduler.prototype.start = function(window, document) {
      this.window = window;
      this.document = document;
      return this._run();
    };

    Scheduler.prototype._run = function() {
      var checked, done, results, st;
      st = new Date().getTime();
      done = (function(_this) {
        return function(sname) {
          var et;
          et = new Date().getTime() - st;
          console.log(TAG + " " + sname + " completed in " + et + " msecs.");
          return _this._run();
        };
      })(this);
      if (this._viewOrder.length === 0) {
        return this._showDefaultView(done);
      } else {
        checked = 0;
        results = [];
        while (true) {
          if (this._tryToViewCurrent(done)) {
            break;
          } else {
            checked++;
            if (checked >= this._viewOrder.length) {
              this._viewFallbackElseDefaultView(done);
              break;
            } else {
              results.push(void 0);
            }
          }
        }
        return results;
      }
    };

    Scheduler.prototype._tryToViewCurrent = function(done) {
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

    Scheduler.prototype._viewFallbackElseDefaultView = function(done) {
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
      return this._showDefaultView(done);
    };

    Scheduler.prototype._showDefaultView = function(done) {
      var slot, view;
      slot = this._slots[DEFAULT_VIEW];
      if (slot.length > 0) {
        view = slot.shift();
        console.log(TAG + " Rendering the default view for " + view.duration + " msecs.");
        return this._render(view, done);
      } else {
        console.log(TAG + " BLACK SCREEN!!!!!!! for " + BLACK_SCREEN.duration + " msecs.");
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
        return this._cleanAndGetContainer((function(_this) {
          return function(div) {
            var end;
            if (view.isVideo) {
              _this._renderVideoView(div, view, done);
            } else {
              _this._renderHtmlView(div, view);
              end = function() {
                var ref1;
                done(view.slot);
                _this._onViewEnd(view.slot);
                return (ref1 = view.callbacks) != null ? typeof ref1.end === "function" ? ref1.end() : void 0 : void 0;
              };
              setTimeout(end, view.duration);
            }
            _this.document.body.appendChild(div);
            return _this._fadeIn(div, function() {});
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
      return div.innerHTML = view.view;
    };

    Scheduler.prototype._renderVideoView = function(div, view, done) {
      return typeof this.onVideoView === "function" ? this.onVideoView(this.document, div, view.file, ((function(_this) {
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

    Scheduler.prototype._cleanAndGetContainer = function(cb) {
      var div;
      div = this.document.getElementById(CONTENT_DIV_ID);
      if (div != null) {
        return this._fadeOut(div, (function(_this) {
          return function() {
            _this.document.body.removeChild(div);
            return cb(_this._newDiv());
          };
        })(this));
      } else {
        return cb(this._newDiv());
      }
    };

    Scheduler.prototype._newDiv = function() {
      var div;
      div = this.document.createElement('div');
      div.setAttribute('id', CONTENT_DIV_ID);
      div.style.overflow = 'hidden';
      div.style.overflowX = 'hidden';
      div.style.overflowY = 'hidden';
      div.style.height = '100%';
      div.style.width = '100%';
      div.style.backgroundColor = '#000';
      div.style.display = 'block';
      div.style.opacity = 0;
      return div;
    };

    Scheduler.prototype._fadeOut = function(element, cb) {
      var decrease, opacity;
      opacity = 1;
      decrease = (function(_this) {
        return function() {
          opacity -= 0.15;
          if (opacity <= 0) {
            element.style.opacity = 0;
            element.style.display = 'none';
            return typeof cb === "function" ? cb() : void 0;
          } else {
            element.style.opacity = opacity;
            return _this.window.requestAnimationFrame(decrease);
          }
        };
      })(this);
      return decrease();
    };

    Scheduler.prototype._fadeIn = function(element, cb) {
      var increase, opacity;
      opacity = 0;
      element.style.display = 'block';
      increase = (function(_this) {
        return function() {
          opacity += 0.15;
          if (opacity >= 1) {
            element.style.opacity = 1;
            return typeof cb === "function" ? cb() : void 0;
          } else {
            element.style.opacity = opacity;
            return _this.window.requestAnimationFrame(increase);
          }
        };
      })(this);
      return increase();
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
