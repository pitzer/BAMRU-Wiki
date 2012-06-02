require 'rubygems'
require 'bundler/setup'
require File.expand_path('./lib/env_settings', File.dirname(__FILE__))

# ===== App Config =====
set :app_name,    APP_NAME         # <- this comes from lib/env_settings
set :application, "BAMRU-Private"
set :repository,  "https://github.com/andyl/#{application}.git"
set :vhost_names, %w(wiki wikitest)
set :web_port,    8888

# ===== Stage-Specific Code =====
stage = "vagrant"            # <--- set to one of [vagrant|staging|production]
require File.expand_path("config/deploy/#{stage}", File.dirname(__FILE__))

# ===== Common Code for All Stages =====
load 'deploy'
base_dir = File.expand_path(File.dirname(__FILE__))
Dir.glob("config/deploy/shared/base/*.rb").each {|f| require base_dir + '/' + f}
Dir.glob("config/deploy/shared/recipes/*.rb").each {|f| require base_dir + '/' + f}

# ===== Package Definitions =====
require base_dir + "/config/deploy/shared/packages/nginx"
require base_dir + "/config/deploy/shared/packages/foreman"
require base_dir + "/config/deploy/shared/packages/sqlite"
require base_dir + "/config/deploy/shared/packages/postgresql"

# ===== App-Specific Tasks =====

