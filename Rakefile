require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |f|
  f.test_files = Rake::FileList['test/**/*_test.rb']
end

task :benchmark do
  ruby "benchmark/server.rb"
end

task default: :test
