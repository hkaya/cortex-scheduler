# Cortex Scheduler [![Build Status](https://travis-ci.org/hkaya/cortex-scheduler.svg?branch=master)](https://travis-ci.org/hkaya/cortex-scheduler)

Scheduler is a simple library for Cortex apps to view a set of pages in order.

> Prior to Cortex Player v1.6, apps were required to ship with cortex-scheduler. With v1.6, cortex-scheduler is part of the Cortex api. Instead of using the scheduler directly, you should use window.Cortex.view API.

A `slot` is a bucket of similar views. Usually, Cortex apps will consist of multiple pages and each page is expected to register a `slot` to submit view requests.

A `view` is a single instance of a display request. A `view` can either be a video play request or HTML request. When the time comes, the scheduler will consume a `view` from a `slot` by either playing the video or rendering the HTML.

## View Priorities
There are three priority levels that apps can submit view requests to.

- `Normal (L1)`: This is the common level where apps should submit regular view requests.
- `Fallback (L2)`: Views in this level will only get displayed when no L1 view is available.
- `Default (L3)`: When both L1 and L2 fails, scheduler will display views in L3. When marked as default, cortex-scheduler will track submissions to a slot and automatically play them as L3 views.

## View Order
You may define the view order of the slots by registering slots in the order you want. Take the following example:

```coffeescript
scheduler.register 'ads'
scheduler.register 'editorial'
scheduler.register 'ads'
scheduler.register 'ads'
```

With this registration order, the scheduler will try to show an ad view, then an editorial view followed by two ad views. If at any time a slot doesn't have any views, scheduler will move on to the next slot in the given view order.

## Usage

### Registering slots
- `register(slotName, fallbackSlotName)`: This will create a slot named `slotName`. If provided, it will also create a fallback slot named `fallbackSlotName` and show views from `fallbackSlotName` when there are no views to display.
- Multiple calls to `register()` with the same slot name is valid. It will modify the view order.

### Setting a default view
- `setDefaultView(slotName)`: Scheduler will track submissions to the slot `slotName` and use them when everything else fails. `slotName` must be already registered. It is not mandatory to set a default view but it is a good practice to prevent black screens.

### Submitting views
- `submitView(slotName, html, duration, callbacks)`: Submit an HTML view to `slotName`. All resources (images, etc.) being used in html should already be cached.
- `submitVideo(slotName, videoFile, callbacks)`: Submit a video to `slotName`. Video file should already be cached.
- `submit` methods accept an optional `callbacks` object. `callbacks` can have `begin`, `end` and `error` properties. Scheduler will call the `callbacks.begin()` right before it starts to process the view and call the `callbacks.end()` when the view finishes. At anytime, when an error occurs, it will call the `callbacks.error()` function.

### Configuration options
- `defaultViewQueueLen`: Number of views to track for the default view.
- `maxViewDuration`: Max view duration in milliseconds. Views with longer duration will get rejected.

## Sample usage
Following is a sample usage based on Cortex.view API.

```coffeescript
CortexView = window?.Cortex.view
EditorialView = require '...'

class AdView
  run: ->
    onerror = (err) =>
      run = => @run()
      # Delay the next run a bit to prevent looping too fast in case of temporary problems. 
      setTimeout run, 1000
    callbacks =
      error: onerror
      begin: =>
        # this will make sure we prepare another ad while the current one is being displayed.
        @run()
      end: -> console.log "AdView finished rendering an ad."
      
    ad = getSomeAd()
    cacheAd(ad).then =>
      if isVideo(ad)
        CortexView.submitVideo 'AdView', cachedVideoFile, callbacks
      else
        CortexView.submitView 'AdView', @render(ad), adDuration, callbacks
        
    .catch onerror
      
adView = new AdView()
editorialView = new EditorialView()

CortexView.register 'AdView', 'EditorialView'
CortexView.setDefaultView 'AdView'

adView.run()
editorialView.run()

CortexView.start()
```
