coffee      = require 'gulp-coffee'
gulp        = require 'gulp'
gutil       = require 'gulp-util'
mocha       = require 'gulp-mocha'
source      = require 'vinyl-source-stream'

project =
  dist: './lib'
  test: './test/**/*_spec.coffee'

gulp.task 'default', ['dist']

gulp.task 'dist', ->
  gulp.src('./src/**/*.coffee')
    .pipe(coffee())
    .pipe(gulp.dest(project.dist))

gulp.task 'test', ->
  gulp.src(project.test, read: false)
    .pipe(mocha())
    .on 'error', (err) ->
      gutil.log(err.toString())
