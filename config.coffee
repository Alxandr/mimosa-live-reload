path = require "path"

"use strict"

exports.defaults = ->
  liveReload:
    enabled:true
    additionalDirs:["views"]

exports.placeholder = ->
  """
  \t

    # liveReload:                   # Configuration for live-reload
      # enabled:true                # Whether or not live-reload is enabled
      # additionalDirs:["views"]    # Additional directories outside the watch.compiledDir
                                    # that you would like to have trigger a page refresh,
                                    # like, by default, static views
  """

exports.validate = (config) ->
  errors = []
  if config.liveReload?
    if typeof config.liveReload is "object" and not Array.isArray(config.liveReload)
      if config.liveReload.enabled?
        unless typeof config.liveReload.enabled is "boolean"
          errors.push "liveReload.enabled must be a boolean."

      if config.liveReload.additionalDirs?
        if Array.isArray(config.liveReload.additionalDirs)
          for dir in config.liveReload.additionalDirs
            unless typeof dir is "string"
              errors.push "liveReload.additionalDirs must be an array of strings"
              break
        else
          errors.push "liveReload.additionalDirs must be an array"

    else
      errors.push "liveReload configuration must be an object."

  if config.isBuild
    config.liveReload.enabled = false

  if errors.length is 0
    config.liveReload.additionalDirs = config.liveReload.additionalDirs.map (dir) ->
      path.join config.root, dir

  errors
