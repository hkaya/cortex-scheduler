# Cortex Scheduler

Scheduler is a simple library for Cortex apps to view a set of pages in order.

## Usage

- Initialize the scheduler:
```coffeescript
container = $('#container')
scheduler = new Scheduler (done) ->
  # The default view. This view will get rendered if the scheduler
  # fails to render all other views. 
  container.html 'default view'
  done()
```

- Register views:
```coffeescript
scheduler.register 'main'
scheduler.register 'ads'
```
Scheduler keeps buckets of view requests. Each register request will create a new bucket that the caller can submit rendering requests to.

Once a view is registered, the scheduler will accept rendering requests for that view and fullfill them whenever possible.

Registration has two purposes:
  1. Makes the scheduler ready for rendering requests.
  2. Define the order of render requests.

There is no extra paramaters to make #2 work. Simply call the register() with the same parameter to define the rendering order:
```coffeescript
scheduler.register 'main'
scheduler.register 'ads'
scheduler.register 'video'
scheduler.register 'ads'
```
The above code block will make the scheduler loop over the views in the following order: 'main', 'ads', 'video', 'ads' and start over with 'main'.

- Submit render tasks:
Once a view is registered, caller can submit view requests to the scheduler as:
```coffeescript
scheduler.submit 'main', (done) =>
  # render content
  done()
```

Once submitted, a task will wait to get executed by the scheduler. Scheduler will go over the tasks in the order defined by the caller (through register calls). Tasks will get deleted when they are executed. It is up to the caller to resubmit the task.

##Important Note On Tasks
- It is important that the tasks only perform rendering and no I/O. Once submitted, the task should be able to render properly without any further I/O operation.
- Tasks should explicitly call the callback passed to them to notify the scheduler that the tasks is finished. The callback needs to be called even when there is an error.

## Common Task Structure
```coffeescript
class View
  constructor: (@scheduler) ->
  
  render: (container) ->
    # perform I/O and any other time consuming tasks.
    # when everything needed is ready:
    @scheduler.submit 'queue', (done) =>
      # actually render html
      container.html 'some content'
      callback = =>
        # resubmit the task.
        @render()
        # notify the scheduler that current task is done.
        done()
      # show current screen for 5 seconds.
      setTimeout callback, 5000
      
scheduler = new Scheduler (done) ->
  container.html 'default view...'
  # most of the time rendering the default view means that something went wrong with other views.
  # sleep for a short time to let them recover.
  setTimeout done, 1000

view = new View(scheduler)
scheduler.register 'queue' # this should match the name we're using in View.render()
container = $('#container') # assuming that the View will render something to DOM.
view.render(container) # submit the first task.

# finally, start the scheduler to execute the tasks:
scheduler.start()
# at this point, View.render() will get rendered indefinitely.
```

See https://github.com/hkaya/cortex-transit for a more comprehensive implementation.
  
