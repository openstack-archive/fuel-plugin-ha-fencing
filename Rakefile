###############################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################
#
# Rakefile
#   This file implements the lint and spec tasks for rake so that it will check
#   the plugin's puppet modules in the deployment_scripts/puppet/modules
#   folder by running the respective lint or test tasks for each module.
#   It will then return 0 if there are issues or return 1 if any of the modules
#   fail.
#
# Acknowledgements
#   The Rakefile is based on the work of Alex Schultz <aschultz@mirantis.com>,
#   https://raw.githubusercontent.com/openstack/fuel-library/master/Rakefile
#
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'
require 'rake'

MODULES_PATH="./deployment_scripts/puppet/modules"
PuppetSyntax.exclude_paths ||= []
PuppetSyntax.exclude_paths << "spec/fixtures/**/*"
PuppetSyntax.exclude_paths << "pkg/**/*"
PuppetSyntax.exclude_paths << "vendor/**/*"

# Main task list
task :spec => ["spec:gemfile"]
task :lint => ["lint:manual"]

namespace :common do
  desc 'Task to generate a list of puppet modules'
  task :modulelist, [:skip_file] do |t,args|
    args.with_defaults(:skip_file => nil)

    cdir = Dir.pwd
    skip_module_list = []
    $module_directories = []
    # NOTE(bogdando): some dependent modules may have no good tests an we need
    # this file to exclude those
    if not args[:skip_file].nil? and File.exists?(args[:skip_file])
      File.open(args[:skip_file], 'r').each_line { |line|
        skip_module_list << line.chomp
      }
    end

    Dir.glob("#{MODULES_PATH}/*") do |mod|
      next unless File.directory?(mod)
      if skip_module_list.include?(File.basename(mod))
        $stderr.puts "Skipping tests... modules.disable_rspec includes #{mod}"
        next
      end
      $module_directories << mod
    end
  end
end

# The spec task to loop through the modules and run the tests
namespace :spec do
  desc 'Run spec tasks via module bundler with Gemfile'
  task :gemfile do |t|
    Rake::Task["common:modulelist"].invoke('./modules.disable_rspec')
    cdir = Dir.pwd
    status = true

    ENV['GEM_HOME']="#{cdir}/.bundled_gems"
    system("gem install bundler --no-rdoc --no-ri --verbose")
    system("./pre_build_hook")

    $module_directories.each do |mod|
      next unless File.exists?("#{mod}/Gemfile")
      $stderr.puts '-'*80
      $stderr.puts "Running tests for #{mod}"
      $stderr.puts '-'*80
      Dir.chdir(mod)
      begin
        system("bundle install")
        result = system("bundle exec rake spec")
        if !result
          status = false
          $stderr.puts "!"*80
          $stderr.puts "Unit tests failed for #{mod}"
          $stderr.puts "!"*80
        end
        rescue Exception => e
          $stderr.puts "ERROR: Unable to run tests for #{mod}, #{e.message}"
          status = false
        end
        Dir.chdir(cdir)
    end
    fail unless status
  end
end

# The lint tasks
namespace :lint do
  desc 'Find all the puppet files and run puppet-lint on them'
  task :manual do |t|
    Rake::Task["common:modulelist"].invoke('./modules.disable_rspec rake-lint')
    # lint checks to skip if no Gemfile or Rakefile
    skip_checks = [ "--no-80chars-check",
        "--no-autoloader_layout-check",
        "--no-nested_classes_or_defines-check",
        "--no-only_variable_string-check",
        "--no-2sp_soft_tabs-check",
        "--no-trailing_whitespace-check",
        "--no-hard_tabs-check",
        "--no-class_inherits_from_params_class-check",
        "--with-filename"]
    cdir = Dir.pwd
    status = true

    ENV['GEM_HOME']="#{cdir}/.bundled_gems"
    system("gem install bundler --no-rdoc --no-ri --verbose")

    $module_directories.each do |mod|
      $stderr.puts '-'*80
      $stderr.puts "Running lint for #{mod}"
      $stderr.puts '-'*80
      Dir.chdir(mod)
      begin
        result = true
        Dir.glob("**/**.pp") do |puppet_file|
          result = false unless system("puppet-lint #{skip_checks.join(" ")} #{puppet_file}")
        end
        if !result
          status = false
          $stderr.puts "!"*80
          $stderr.puts "puppet-lint failed for #{mod}"
          $stderr.puts "!"*80
        end
      rescue Exception => e
          $stderr.puts "ERROR: Unable to run lint for #{mod}, #{e.message}"
          status = false
      end
     Dir.chdir(cdir)
    end
    fail unless status
  end

  desc 'Run lint tasks from modules with an existing Gemfile/Rakefile'
  task :rakefile do |t|
    Rake::Task["common:modulelist"].invoke('./modules.disable_rspec rake-lint')
    cdir = Dir.pwd
    status = true

    ENV['GEM_HOME']="#{cdir}/.bundled_gems"
    system("gem install bundler --no-rdoc --no-ri --verbose")

    $module_directories.each do |mod|
      next unless File.exists?("#{mod}/Rakefile")
      $stderr.puts '-'*80
      $stderr.puts "Running lint for #{mod}"
      $stderr.puts '-'*80
      Dir.chdir(mod)
      begin
        result = system("bundle exec rake lint > /dev/null")
        $stderr.puts result
        if !result
          status = false
          $stderr.puts "!"*80
          $stderr.puts "rake lint failed for #{mod}"
          $stderr.puts "!"*80
        end
      rescue Exception => e
        $stderr.puts "ERROR: Unable to run lint for #{mod}, #{e.message}"
        status = false
      end
      Dir.chdir(cdir)
    end
    fail unless status
  end
end
