# Video Renamer
require 'active_record'
require 'active_support'
# require 'active_support/core_ext/time/calculations'
# require 'active_support/dependencies/autoload'
# require 'active_support/inflector'
# require 'active_support/number_helper'
require 'date'
require 'fileutils'
require 'progress_bar'
require 'pg'
require 'string/similarity'
require 'streamio-ffmpeg'
require 'time'
require 'yaml'
require './models/Person'
require './models/Video'
require 'handbrake'

config = YAML::safe_load(File.open('../config/config.yml'))['default']
ActiveRecord::Base.establish_connection(config)