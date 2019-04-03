# çici
require 'active_record'
require 'active_support/core_ext/time/calculations'
require 'active_support/dependencies/autoload'
require 'active_support/number_helper'
require 'date'
require 'fileutils'
require 'progress_bar'
require 'string/similarity'
require 'streamio-ffmpeg'
require 'time'
require 'yaml'
require './models/Person'
require './models/Video'
require 'handbrake'

db_config = {
    'adapter'  => 'postgresql',
    'host'     => 'localhost',
    'port'     => 5432,
    'username' => 'noyana',
    'password' => 'Ankara88',
    'database' => 'videos'
}
ActiveRecord::Base.establish_connection(db_config)
# HandBrake run command
class MyRunner < HandBrake::CLI::PopenRunner
  def command(args)
    "\"#{args.unshift(@cli.bin_path).collect { |a| a.gsub(/"/) { %('""') } }.join('" "')}\" > nul 2>&1"
    # File.open('recode_old.bat', 'a') do |f|
    #  f.puts "\"#{args.unshift(@cli.bin_path).collect { |a| a.gsub(/"/) { %('""') } }.join('" "')}\" > nul 2>&1"
    # end
  end
end

MY_PATH = File.dirname(__FILE__)
config  = YAML.safe_load(File.open("#{MY_PATH}/config/config.yml"))['default']
unpopular_stars = config['unpopular_stars']

File.open('one_old_delete.bat', 'w') do |f|
  Person.where("count<3").each do |p|
    p.videos.where("file_date<?",6.months.ago).order(:file_date).reverse_order.each do |v|
      next if v.file_name.match("ProjectCSD")
      skip = false
      v.people.each do |vp|
        skip = true if vp.count > 1
      end
      f.puts "move \"#{v.file_name.gsub(%r{/}, '\\')}\" #{unpopular_stars.gsub(%r{/}, '\\')}" unless skip
    end
  end
  Video.where("file_name LIKE '%ProjectCSD%'").each do |v|
    v.people.where("count>2").each do |p|
      f.puts "move \"#{v.file_name.gsub(%r{/}, '\\')}\" #{unpopular_stars.gsub(%r{/}, '\\')}" unless skip
    end
  end
end
exit
progress = ProgressBar.new(Video.all.count, :bar, :percentage, :counter, :rate, :eta)
Video.find_each do |v|
  v.destroy unless File.exist?(v.file_name)
  progress.increment!
end
puts
puts "Nonmovie avg size : #{ActiveSupport::NumberHelper.number_to_human_size(Video.where(is_movie: 0).average(:file_size), precision: 2)}"
puts "Movie avg size    : #{ActiveSupport::NumberHelper.number_to_human_size(Video.where(is_movie: -1).average(:file_size), precision: 2)}"
puts "Total avg size    : #{ActiveSupport::NumberHelper.number_to_human_size(Video.average(:file_size), precision: 2)}"
puts "Hi Frame local    : #{ActiveSupport::NumberHelper.number_to_human_size(Video.where("frame_rate>=30 AND (file_name LIKE 'W:%')").sum(:file_size), precision: 2)}"
puts "Hi Frame movie    : #{ActiveSupport::NumberHelper.number_to_human_size(Video.where("frame_rate>=30 AND (file_name LIKE 'P:%')").sum(:file_size), precision: 2)}"
Dir["P:/Diziler/Movie/*.mp4"].each do |v|
  nf = v.gsub(/~/, '_')
  File.rename v, nf
  progress.increment!
end

p = 0
n = 0
progress = ProgressBar.new(Video.where("file_name LIKE 'P:%'").count, :bar, :percentage, :counter, :rate, :eta)
Video.where("file_name LIKE 'P%'").order(:frame_rate).reverse_order.order(:file_size).reverse_order.each do |video|
  nf = video.file_name.gsub(/~/, '_')
  puts nf
  File.rename video.file_name, nf
  v.file_name = nf
  v.save
  progress.increment!
  puts "Before : #{ActiveSupport::NumberHelper.number_to_human_size(p)}"
  puts "Now    : #{ActiveSupport::NumberHelper.number_to_human_size(n)}"
  puts "Gain   : #{ActiveSupport::NumberHelper.number_to_human_size(p-n)}"
end

p = 0
n = 0
progress = ProgressBar.new(Video.where("frame_rate>=30").count, :bar, :percentage, :counter, :rate, :eta)
Video.where("frame_rate>=30").each do |v|
  nf = v.file_name.gsub(/mp4$/, 'mpeg')
  File.rename v.file_name, nf
  p = p + v.file_size
  recoded = HandBrake::CLI.new(bin_path: 'W:/Pilot/Videos/HandBrakeCLI.exe', runner: lambda { |cli| MyRunner.new(cli) }, trace: false)
  recoded.input(nf).preset_import_file('W:/Pilot/Videos/Galaxy.json').preset('Galaxy').output(v.file_name)
  File.delete nf
  n = n + File.size(v.file_name)
  progress.increment!
  puts "Before : #{ActiveSupport::NumberHelper.number_to_human_size(p)}"
  puts "Now    : #{ActiveSupport::NumberHelper.number_to_human_size(n)}"
  puts "Gain   : #{ActiveSupport::NumberHelper.number_to_human_size(p-n)}"
end