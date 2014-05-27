#!/usr/bin/env rake
require "bundler/gem_tasks"
require "bundler/setup"
require 'rspec/core/rake_task'

desc "Run all specs with default options"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
end

desc "Run specs with TCP socket"
RSpec::Core::RakeTask.new("spec:tcp") do |t|
  ENV['TYPE'] = 'tcp'
  t.verbose = false
end

desc "Run specs with UDP socket"
RSpec::Core::RakeTask.new("spec:udp") do |t|
  ENV['TYPE'] = 'udp'
  t.verbose = false
end

task :default => ["spec:tcp", "spec:udp"]