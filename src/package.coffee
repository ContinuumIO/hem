fs           = require('fs')
pathlib         = require('path')
eco          = require('eco')
uglify       = require('uglify-js')
compilers    = require('./compilers')
_ = require('underscore')
Dependency   = require('./dependency')
Stitch       = require('./stitch')
{toArray}    = require('./utils')

#templates
stitch       = require('../assets/stitch')
individual   = require('../assets/individual')
stitchindividual   = require('../assets/stitchindividual')

class Package
  constructor: (config = {}) ->
    @identifier   = config.identifier
    @libs         = toArray(config.libs || [])
    @paths        = toArray(config.paths || [])
    @dependencies = toArray(config.dependencies || [])
    @target_dir       = config.target_dir
    @target_file       = config.target_file #only used for single
    @extrajs_file       = '_extra.js'
    @targets_file       = 'targets.json'
    @extraJS      = config.extraJS or ""
    @test         = config.test
    @uglify       = config.uglify #only for js
    @split        = config.split #only for js

  write_package_single : () ->
    source = @compile_single()
    target = pathlib.join(@target_dir, @target_file)
    console.log(target)
    fs.writeFileSync(target, source)
    fs.writeFileSync(pathlib.join(@target_dir, @targets_file),
      JSON.stringify([target])
    )

  write_package_split : () ->
    sources = @compile_split()
    fnames = _.map(this.modules, (module) ->
      return module.id.split("/").join("_") + ".js"
    )
    fnames.push(@target_file)
    for result in _.zip(fnames, sources.modules)
      [fname, source] = result
      fs.writeFileSync(pathlib.join(@target_dir, fname), source)
    fs.writeFileSync(pathlib.join(@target_dir, @extrajs_file),
      sources.extraJS)
    fnames.push(@extrajs_file)
    fnames = _.map(fnames, (fname) => return pathlib.join(@target_dir, fname))
    fnames = fnames.concat(@libs)
    fs.writeFileSync(pathlib.join(@target_dir, @targets_file),
      JSON.stringify(fnames)
    )

  write_package : () ->
    if @split
      @write_package_split()
    else
      @write_package_single()

  compileModules: (split) ->
    @dependency or= new Dependency(@dependencies)
    @stitch       = new Stitch(@paths)
    @modules      = @dependency.resolve().concat(@stitch.resolve())
    if not split
      return stitch(identifier: @identifier, modules: @modules)
    else
      result = []
      for m in @modules
        result.push(individual({m : m}))
      result.push(stitchindividual({identifier : @identifier}))
      return result

  compileLibs: ->
    (fs.readFileSync(path, 'utf8') for path in @libs).join("\n")

  compile_single: () ->
    try
      result = [@compileLibs(), @compileModules(), @extraJS].join("\n")
      result = uglify(result) if @uglify
      result
    catch ex
      if ex.stack
        console.error ex
      else
        console.trace ex
      result = "console.log(\"#{ex}\");"

  compile_split : () ->
    try
      result =
        libs : null # we just need to add libs to target.json
        modules : @compileModules(true),
        extra : @extraJS
      return result
    catch ex
      if ex.stack
        console.error ex
      else
        console.trace ex
      result = "console.log(\"#{ex}\");"

  unlink: ->
    fs.unlinkSync(@target) if fs.existsSync(@target)

  createServer: ->
    (env, callback) =>
      callback(200,
        'Content-Type': 'text/javascript',
        @compile_single())

module.exports =
  compilers:  compilers
  Package:    Package
  createPackage: (config) ->
    new Package(config)
