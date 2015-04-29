(function() {
  var CortexEventApi, Scheduler, ref;

  CortexEventApi = (ref = window.Cortex) != null ? ref.event : void 0;

  Scheduler = (function() {
    function Scheduler(defaultView) {
      if (defaultView == null) {
        throw 'Scheduler needs a valid default view.';
      }
      this.slots = {};
      this.viewOrder = [];
      this.fallbackSlots = {};
      this.fallbackViewOrder = [];
      this.current = 0;
      this.defaultView = defaultView;
    }

    Scheduler.prototype.register = function(sname, fallback) {
      if (this.slots[sname] == null) {
        this.slots[sname] = [];
      }
      this.viewOrder.push(sname);
      if (!!fallback) {
        if (this.fallbackSlots[fallback] == null) {
          this.fallbackSlots[fallback] = [];
          return this.fallbackViewOrder.push(fallback);
        }
      }
    };

    Scheduler.prototype.submit = function(sname, view) {
      if (sname in this.slots) {
        return this.slots[sname].push(view);
      } else if (sname in this.fallbackSlots) {
        return this.fallbackSlots[sname].push(view);
      } else {
        throw "Scheduler doesn't know about slot: " + sname;
      }
    };

    Scheduler.prototype.start = function() {
      return this._run();
    };

    Scheduler.prototype._run = function() {
      var checked, done, results, st;
      st = new Date().getTime();
      done = (function(_this) {
        return function() {
          var et;
          et = new Date().getTime() - st;
          console.log("View completed in " + et + " msecs.");
          return _this._run();
        };
      })(this);
      if (this.viewOrder.length === 0) {
        this.defaultView(done);
        return this._publishEvent('Default View');
      } else {
        checked = 0;
        results = [];
        while (true) {
          if (this._tryToViewCurrent(done)) {
            break;
          } else {
            checked++;
            if (checked >= this.viewOrder.length) {
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
      if (this.viewOrder.length === 0) {
        return false;
      }
      if (this.current >= this.viewOrder.length) {
        this.current = 0;
      }
      sname = this.viewOrder[this.current];
      cslot = this.slots[sname];
      this.current++;
      if (cslot.length > 0) {
        view = cslot.shift();
        view(done);
        this._publishEvent(sname);
        return true;
      } else {
        return false;
      }
    };

    Scheduler.prototype._viewFallbackElseDefaultView = function(done) {
      var fallback, i, len, ref1, slot, sname;
      if (this.fallbackViewOrder.length > 0) {
        ref1 = this.fallbackViewOrder;
        for (i = 0, len = ref1.length; i < len; i++) {
          sname = ref1[i];
          slot = this.fallbackSlots[sname];
          if (slot.length > 0) {
            console.log("Displaying a fallback view from slot: " + sname);
            fallback = slot.shift();
            fallback(done);
            this._publishEvent(sname);
            return;
          }
        }
      }
      this.defaultView(done);
      return this._publishEvent('Default View');
    };

    Scheduler.prototype._publishEvent = function(name) {
      if (CortexEventApi != null) {
        return CortexEventApi.publish(name);
      }
    };

    return Scheduler;

  })();

  module.exports = Scheduler;

}).call(this);
