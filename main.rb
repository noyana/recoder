# Video Renamer
require 'rails'
require 'active_record/railtie'
require 'active_record'
require 'active_support'
require 'date'
require 'fileutils'
require 'pg'
require 'string/similarity'
require 'streamio-ffmpeg'
require 'time'
require 'yaml'
require './models/Person'
require './models/Video'
require 'handbrake'

# HandBrake run command
class MyRunner < HandBrake::CLI::PopenRunner
  def command(args)
    LOG.info('Convert') { "\"#{args.unshift(@cli.bin_path).collect { |a| a.gsub(/"/) { %('""') } }.join('" "')}\" 2>> hb.logs" }
    "\"#{args.unshift(@cli.bin_path).collect { |a| a.gsub(/"/) { %('""') } }.join('" "')}\" 2>> hb.log"
  end
end

MY_PATH = File.dirname(__FILE__)
config  = YAML.safe_load(File.open("#{MY_PATH}/config/config.yml"))['default']
ActiveRecord::Base.establish_connection(config)
FFMPEG.ffmpeg_binary = "#{MY_PATH}/ffmpeg.exe"

video_paths      = config['video_paths']
raw_files        = config['raw_files']
a_videos         = config['a_videos']
b_videos         = config['b_videos']
log_path         = config['log_name']
mov_videos       = config['c_videos']
unpopular_stars  = config['unpopular_stars']
unpopular_match  = config['unpopular_match']
# popular_stars  = config['popular_stars']

clear_people      = true
clear_videos      = true
add_new           = true
duplicate_people  = true
duplicate_videos  = true
rename_video      = true
recode_video      = true
clear_log         = false
clear_global      = false
force_recollect   = false
ARGV.each do |command|
  case command
  when '-no-add'
    add_new = false
  when '-no-clear-videos'
    clear_videos = false
  when '-no-clear-people'
    clear_people = false
  when '-no-duplicate-videos'
    duplicate_videos = false
  when '-no-duplicate-people'
    duplicate_people = false
  when '-no-rename'
    rename_video = false
  when '-no-recode'
    recode_video = false
  when '-clear-global'
    clear_global = true
  when '-no-log'
    clear_log = true
  when '-no-clear-log'
    clear_log = false
  when '-force'
    force_recollect = true
    Video.destroy_all
    Person.destroy_all
  end
end

begin
  File.delete(log_path) if clear_log && File.exist?(log_path)
end
LOG = Logger.new log_path, 'daily'
LOG.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')}\t#{severity}\t#{progname}\t #{msg}\n"
end

def clear_old_videos
  puts "\nClearing deleted videos"
  Video.all.each do |video|
    LOG.info('Clear Old Videos') { "Deleted #{video.file_name}" } unless File.exist?(video.file_name)
    video.destroy unless File.exist?(video.file_name)
  end
end

# clear people with no video
def clear_old_people
  puts "\nClearing deleted people"
  Person.find_each do |person|
    LOG.info('Clear Old People') { "Deleted #{person.name}" } if person.videos.count.zero?
    person.destroy if person.videos.count.zero?
  end
end

def reset_people_count
  puts "\nResetting people counts"
  Person.find_each do |p|
    p.count = 0
    p.save
  end
end

def clear_new_files(video_paths, force_recollect)
  puts "\nSorting new videos"
  all_files_count = 0
  video_paths.each { |yol| all_files_count += Dir["#{yol}*.mp4"].count }
  video_paths.each do |yol|
    Dir["#{yol}**/*.mp4"].each do |vf|
      next unless File.exist?(vf)

      video = Video.where(file_name: vf).first_or_initialize # .gsub(/_/,'_')).first_or_initialize
      unless video.new_record?
        date_no_match = (video.file_date - File.ctime(vf)).to_i != 0
        size_no_match = video.file_size != File.size(vf)
        next unless size_no_match || date_no_match || video.duration.nil? || force_recollect
      end
      mpeg              = FFMPEG::Movie.new(vf)
      video.duration    = mpeg.duration
      video.tr_duration = (mpeg.duration / 10).round(0) * 10
      video.width       = mpeg.width
      video.height      = mpeg.height
      video.frame_rate  = mpeg.frame_rate
      video.file_size   = File.size(vf)
      video.file_date   = File.ctime(vf)
      video.ext         = File.extname(vf).chomp
      video.is_movie    = !vf.match(/_/).nil?
      count_str         = video.is_movie ? /_, \w+(\d+)/ : / \((\d+)\)/
      f_count           = File.basename(vf).match(count_str) ? (File.basename(vf).match(count_str)[1]).to_i : 1
      video.file_count  = f_count
      base              = File.basename(vf)[0..(-1 * (video.ext.length + 1))]
      fc_string         = base.match(count_str) ? base.match(count_str)[0] : ''
      wo_count          = base[0..-(fc_string.length + 1)]
      video.name        = wo_count.tr('_', '')
      video.save
      LOG.info('New Video ') { "Video: #{video.file_name}" }
      next if video.is_movie

      ppl = video.name.split(/,/)
      ppl.collect! { |person| person.strip || person }
      ppl.each do |pn|
        person       = Person.find_or_create_by! name: pn
        person.count += 1 unless person.new_record?
        person.videos << video unless person.videos.include?(video)
        LOG.info('New Person') { "Person: #{person.name}" }
        person.save
      end
    end
  end
end


def add_new_files(video_paths, force_recollect)
  puts "\nAdding new videos"
  all_files_count = 0
  video_paths.each { |yol| all_files_count += Dir["#{yol}*.mp4"].count }
  video_paths.each do |yol|
    # puts "\n#{yol}"
    Dir["#{yol}**/*.mp4"].each do |vf|
      next if vf =~ %r{/Raw\/DL/}
      next unless File.exist?(vf)

      video = Video.where(file_name: vf).first_or_initialize # .gsub(/_/,'_')).first_or_initialize
      unless video.new_record?
        date_no_match = (video.file_date - File.ctime(vf)).to_i != 0
        size_no_match = video.file_size != File.size(vf)
        next unless size_no_match || date_no_match || video.duration.nil? || force_recollect
      end
      mpeg             = FFMPEG::Movie.new(vf)
      video.duration   = mpeg.duration
      video.tr_duration= (mpeg.duration / 10).round(0) * 10
      video.width      = mpeg.width
      video.height     = mpeg.height
      video.frame_rate = mpeg.frame_rate
      video.file_size  = File.size(vf)
      video.file_date  = File.ctime(vf)
      video.ext        = File.extname(vf).chomp
      video.is_movie   = !vf.match(/_/).nil?
      count_str        = video.is_movie ? /_, \w+(\d+)/ : / \((\d+)\)/
      f_count          = File.basename(vf).match(count_str) ? (File.basename(vf).match(count_str)[1]).to_i : 1
      video.file_count = f_count
      base             = File.basename(vf)[0..(-1 * (video.ext.length + 1))]
      fc_string        = base.match(count_str) ? base.match(count_str)[0] : ''
      wo_count         = base[0..-(fc_string.length + 1)]
      video.name       = wo_count.tr('_', '')
      video.save
      LOG.info('New Video ') { "Video: #{video.file_name}" }
      next if video.is_movie

      ppl = video.name.split(/,/)
      ppl.collect! { |person| person.strip || person }
      ppl.each do |pn|
        person       = Person.find_or_create_by! name: pn
        person.count += 1 unless person.new_record?
        person.videos << video unless person.videos.include?(video)
        LOG.info('New Person') { "Person: #{person.name}" }
        person.save
      end
    end
  end
end

def find_duplicate_people
  puts "\nFinding duplicate people"
  Person.all.order(:id).reverse_order.each do |person|
    Person.where('id > ?', person.id).order(:id).reverse_order.each do |person_compare|
      similarity = String::Similarity.cosine(person.name, person_compare.name)
      LOG.info('Dup Person') { "#{person.name} ~= #{person_compare.name} : #{person.id} ~= #{person_compare.id} by #{similarity}" } if similarity >= 0.93
    end
  end
end

def find_duplicate_videos
  puts "\nFinding duplicate videos"
  Person.order(:count).reverse_order.each do |person|
    person.videos.each do |video|
      next if video.file_date <= 1.weeks.ago

      person.videos.each do |vcompare|
        next if vcompare.id == video.id

        next if vcompare.people.count != video.people.count

        ratio = vcompare.duration > video.duration ? (vcompare.duration * 1.0) / (video.duration * 1.0) : (video.duration * 1.0) / (vcompare.duration * 1.0)
        next if ratio > 1.001

        LOG.info('Dup Video') { "#{person.name}: #{ratio} #{video.name} ~ #{vcompare.name}, #{video.duration} <> #{vcompare.duration}" }
      end
    end
  end
end

def find_global_duplicate_videos
  puts "\nFinding global duplicate videos"
  Video.all.each do |video|
    fark = video.duration * 0.001
    Video.where("duration <= #{video.duration + fark} AND duration >= #{video.duration - fark} AND id > #{video.id}").each do |vcompare|
      next if vcompare.id == video.id

      next if vcompare.people.count != video.people.count

      diff  = (vcompare.duration - video.duration).abs
      ratio = vcompare.duration > video.duration ? (vcompare.duration * 1.0) / (video.duration * 1.0) : (video.duration * 1.0) / (vcompare.duration * 1.0)
      next if ratio > 1.001 or diff > 61

      LOG.info('Dup Video') { "#{ratio}: #{video.name} ~ #{vcompare.name}, #{video.duration} <> #{vcompare.duration}" } 
    end
  end
end

def rename_videos
  puts "\nRenaming videos"
  Person.all.order(:count).reverse_order.each do |person|
    her_videos = person.videos.order(:file_date)
    her_videos.each do |h|
      pn     = h.people.all.order(:count).reverse_order.select(:name, :count).distinct.map(&:name).join(', ')
      h.name = pn
      h.save if h.changed?
    end
  end
  say      = 1
  prev     = Video.where(is_movie: 0).order(:name).order(:file_date).first.name
  Video.where(is_movie: 0).order(:name).order(:file_date).order(:id).each do |video|
    say    = video.name == prev ? say + 1 : 1
    prev   = video.name unless video.name == prev
    video.name = "#{video.name} (#{say})"
    video.save
    new_name = (File.dirname(video.file_name) + '/' + video.name + video.ext)
    if video.file_name != new_name
      # LOG.info('Renamed') { "#{video.file_name} ->  #{new_name} @ #{video.file_date}, #{video.id}" }
      new_unique = new_name
      new_count  = new_name.match(/\(\d+\)/) ? new_name.match(/ \((\d+)\)/)[1].to_i : 1
      while File.exist? new_unique
        new_count  += 1
        new_ext    = " (#{new_count}).mp4"
        new_unique = new_unique.match(/ \(\d+\)\.mp4/) ? "#{new_unique.gsub(/ \(\d+\)\.mp4/, new_ext)}" : "#{new_unique.gsub(/\.mp4/, new_ext)}"
      end
      if (d = Video.where("file_name = '#{new_name}'").first)
        begin
          File.rename(d.file_name, new_unique)
          d.file_name = new_unique
          d.save
        rescue
          LOG.info('Rename Video') { "Can't rename #{d.file_name}" }
        end
      end
      begin
        File.rename(video.file_name, new_name)
        video.file_name = new_name
        video.save
      rescue
        LOG.info('Rename Video') { "Can't rename #{video.file_name} to new name #{new_name}" }
      end
    end
  end
end

def correct_people_count
  puts "\nCorrecting people video counts"
  Person.all.each do |p|
    p.count = p.videos.count
    p.save if p.changed?
  end
end

def count_videos(raw_files)
  vid_formats     = %w[.avi .flv .mkv .mov .mp4 .mpg .wmv] #  add more extensions if anything is left
  all_files_count = 0
  all_files       = []
  vid_formats.each do |vf|
    Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!.each { |nv| all_files << nv }
    # Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.each { |nv| all_files << nv }
    all_files_count += Dir["#{raw_files}**/*#{vf}"].count
  end
  return all_files_count
end

def recode_videos(raw_files, a_videos, b_videos, mov_videos)
  puts "\nRecoding new videos"
  vid_formats     = %w[.avi .flv .mkv .mov .mp4 .mpg .wmv] #  add more extensions if anything is left
  all_files_count = 0
  all_files       = []
  vid_formats.each do |vf|
    Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!.each { |nv| all_files << nv }
    # Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.each { |nv| all_files << nv unless }
    all_files_count += Dir["#{raw_files}**/*#{vf}"].count
  end
  vid_formats.each do |vf|
    # nf = Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.first
    nf = Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!.first
    while nf
      mpeg  = FFMPEG::Movie.new(nf)
      video = Video.where(duration: mpeg.duration).first
      if video
        LOG.info('PossibleDuplicate') { "#{nf} is as long as #{video.file_name}" }
        is_movie  = !nf.match(/_/).nil?
        ext       = File.extname(nf).chomp
        count_str = is_movie ? /_, \w+(\d+)/ : / \((\d+)\)/
        base      = File.basename(nf)[0..(-1 * (ext.length + 1))]
        fc_string = base.match(count_str) ? base.match(count_str)[0] : ''
        wo_count  = base[0..-(fc_string.length + 1)]
        name      = wo_count.tr('_', '')
        ppl       = []
        unless is_movie
          ppl = name.split(/,/)
          ppl.collect! { |p| p.strip || p }
        end
        if video.people.pluck(:name).to_set == ppl.to_set && video.file_name != nf
          begin
            File.rename(nf, "#{nf}.dup.sil")
            nf = Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!.first
            LOG.info('Deleted') { "Renamed #{nf} to #{nf}.dup.sil, duplicate of #{video.file_name}" }
          rescue
            LOG.info('Deleted') { "Can't rename duplicate video #{nf} to #{nf}.dup.sil, duplicate of #{video.file_name}" }
            nf = (Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!)[2]
          end
          next
        else
          if File.basename(nf).match(/TS /) or File.basename(nf).match(/Trans /) or File.basename(nf).match(/Bi /) or File.basename(nf).match(/Bisex/) or File.basename(nf).match(/Trann/) or File.basename(nf).match(/uckold/) or File.basename(nf).match(/shemale/) 
            new_unique = "#{b_videos}#{File.basename(nf)}" 
          elsif File.basename(nf).match(/^_/)
            new_unique = "#{mov_videos}#{File.basename(nf)}" 
          else
            new_unique = "#{a_videos}#{File.basename(nf)}"
          end
          new_count  = new_unique.match(/ \(\d+\)/) ? new_unique.match(/ \(\d+\)/)[1].to_i : 2
          while File.exist? new_unique
            new_count  += 1
            new_ext    = " (#{new_count}).mp4"
            new_unique = new_unique.match(/ \(\d+\)\.mp4/) ? "#{new_unique.gsub(/ \(\d+\)\.mp4/, new_ext)}" : "#{new_unique.gsub(/\.mp4/, new_ext)}"
          end
          # LOG.info('Recoded') { "Recoded #{nf} -> #{new_unique}" }
          # recoded = HandBrake::CLI.new(bin_path: "#{MY_PATH}/HandBrakeCLI.exe", runner: lambda { |cli| MyRunner.new(cli) }, trace: false)
          # recoded.input(nf).preset_import_file("#{MY_PATH}/Galaxy.json").preset('Galaxy').subtitle('none').output(new_unique)
           options = { video_codec: "libx264", resolution: "854x480", video_bitrate: 768, audio_codec: "aac", audio_bitrate: 128, audio_sample_rate: 44100, custom: %w(-y -preset fast -tune film -map 0:0 -map 0:1) }
           mpeg.transcode("#{new_unique}", options)
          # LOG.info('Recoded') { "Deleted #{nf}, recoded to #{new_unique}" }
          begin
            # File.rename(nf, "#{nf}.rec.sil")
            if File.size(new_unique) > 120024024
              File.delete nf
            else
              File.rename(nf, "#{nf}.poss_con_err.sil")

            end
          rescue
            LOG.info('Recode Video') { "Can't delete recoded #{nf}" }
            nf = Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse![2]
            next
          end
        end
      else
        if File.basename(nf).match(/TS /) or File.basename(nf).match(/Trans /) or File.basename(nf).match(/Bi /) or File.basename(nf).match(/Bisex/) or File.basename(nf).match(/Trann/) or File.basename(nf).match(/shemale/) 
          new_unique = "#{b_videos}#{File.basename(nf)}" 
        elsif File.basename(nf).match(/^_/)
          new_unique = "#{mov_videos}#{File.basename(nf)}" 
        else
          new_unique = "#{a_videos}#{File.basename(nf)}"
        end
        new_count  = new_unique.match(%r{ \(\d+\)}) ? new_unique.match(%r{ \(\d+\)})[1].to_i : 1
        while File.exist? new_unique
          new_count  += 1
          new_ext    = " (#{new_count}).mp4"
          new_unique = new_unique.match(/ \(\d+\)\.mp4/) ? "#{new_unique.gsub(/ \(\d+\)\.mp4/, new_ext)}" : "#{new_unique.gsub(/\.mp4/, new_ext)}"
        end
        # LOG.info('recode_videos') { "recoded #{nf} -> #{new_unique}" }
        # recoded = HandBrake::CLI.new(bin_path: "#{MY_PATH}/HandBrakeCLI.exe", runner: lambda { |cli| MyRunner.new(cli) }, trace: false)
        # recoded.input(nf).preset_import_file("#{MY_PATH}/Galaxy.json").preset('Galaxy').subtitle('none').output(new_unique)
        options = { video_codec: "libx264", resolution: "854x480", video_bitrate: 768, audio_codec: "aac", audio_bitrate: 128, audio_sample_rate: 44100, custom: %w(-y -preset fast -tune film -map 0:0 -map 0:1) }
        mpeg.transcode("#{new_unique}", options)
      # LOG.info('recode_videos') { "deleted #{nf}, recoded to #{new_unique}" }
        begin
          # File.rename(nf, "#{nf}.rec.sil")
          if File.size(new_unique) > 120024024
            File.delete nf
          else
            File.rename(nf, "#{nf}.poss_con_err.sil")
          end
        rescue
          LOG.info('Recode Video') { "Can't delete recoded #{nf}, recoded to #{new_unique}" }
          nf = (Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!)[2]
          next
        end
      end
      # nf = Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.first
      nf = Dir["#{raw_files}**/*#{vf}"].sort_by { |x| File.size(x) }.reverse!.first
    end
  end
end

clear_old_videos if clear_videos
recode_videos(raw_files, a_videos, b_videos, mov_videos) if recode_video
add_new_files video_paths, force_recollect if add_new
clear_old_people if clear_people
correct_people_count
rename_videos if rename_video
add_new_files video_paths, false if add_new
correct_people_count
clear_old_videos if clear_videos
clear_old_people if clear_people
find_duplicate_people if duplicate_people
find_duplicate_videos if duplicate_videos
find_global_duplicate_videos if clear_global
skip = false
pd = 0
wd = 0 
rd = 0
ls = []
File.open('one_old_delete.bat', 'w') do |f|
  Person.where('count<=6').each do |p|
    next if p.name =~ %r{/#/}

    p.videos.where('file_date<?', 1.weeks.ago).order(:file_date).reverse_order.each do |v|
      next if v.file_name.match(unpopular_match)

      skip = false
      v.people.each do |vp|
        skip = true if vp.count > 1
      end
      next if skip or ls.include?(v.id)

      ls << v.id 
      f.puts "move \"#{v.file_name.gsub(%r{/}, '\\')}\" \"#{unpopular_stars.gsub(%r{/}, '\\')}\""
      pd += v.file_size if v.file_name.match('P:/')
      wd += v.file_size if v.file_name.match('W:/')
    end
  end
  Video.where("file_name LIKE '%#{unpopular_match}%'").each do |v|
    v.people.where('count > 6').each do |p|
      f.puts "move \"#{v.file_name.gsub(%r{/}, '\\')}\" \"#{raw_files.gsub(%r{/}, '\\')}\""
      rd += v.file_size if v.file_name.match(unpopular_match)
    end
  end
end
LOG.info('Main') { "P->R : #{ActiveSupport::NumberHelper.number_to_human_size(pd)}" }
LOG.info('Main') { "W->R : #{ActiveSupport::NumberHelper.number_to_human_size(wd)}" }
LOG.info('Main') { "R->L : #{ActiveSupport::NumberHelper.number_to_human_size(rd)}" }
LOG.info('Main') { 'DONE.' }

=begin
new_movie_size = 0
Video.all.each do |video|
  next unless video.is_movie
  next if video.file_name[0] == 'P'
  FileUtils.mv "#{video.file_name.gsub(%r{/}, '\\')}", "#{mov_videos}"
  video.file_name = video.file_name.match(/TS /) ? video.file_name.gsub("#{b_videos}", "#{mov_videos}") : video.file_name.gsub("#{a_videos}", "#{mov_videos}")
  # video.file_name = video.file_name.gsub("#{a_videos}", "#{mov_videos}")
  new_movie_size += video.file_size
  video.save
end
LOG.info('Main') { "-> M : #{ActiveSupport::NumberHelper.number_to_human_size(new_movie_size)}" }
File.open('popular.bat', 'w') do |f|
  say       = 0
  ppsize    = 0
  done_list = []
  # done_list = ['Adriana Chechik', 'Anissa Kate', 'Belle Claire', 'Cherie Deville', 'Eveline Dellai', 'Megan Rain', 'TS Chanel Santini']
  # done_list = done_list + ['Angela White', 'Tina Kay', 'Anna Polina', 'Billie Star', 'Arya Fae', 'Keisha Grey', 'Jasmine Jae', 'Lana Rhoades', 'Mai Thai', 'Lena Paul', 'Jillian Janson', 'Kate England', 'Lucy Li', 'Marley Brinx', 'Stella Cox']
  # done_list = done_list + ['TS Aubrey Kate', 'Abella Danger', 'Ria Sunn', 'Valentina Nappi', 'Selvaggia', 'Ivana Sugar', 'Kitana Lure']
  # done_list = done_list + ['AJ Applegate', 'Alison Tyler', 'Dakota Skye', 'Emily Thorne', 'Holly Hendrix', 'Katrin Tequila', 'Mea Melone', 'Kira Thorn', 'Silvia Dellai']
  # done_list = done_list + ['Casey Calvert', 'Jennifer White', 'Natalia Starr', 'July Sun', 'Nikky Dream', 'Timea Bella', 'Adria Rae', 'Francys Belle', 'Phoenix Marie']
  # done_list = done_list + ['Amirah Adara', 'Blanche Bradburry', 'Foxy Di', 'Kelsie Monroe', 'Lara Onyx', 'Lauren Phillips', 'Luna Rival', 'Mandy Muse', 'TS Venus Lux']
  Person.order(:count).reverse_order.all.each do |person|
    say += 1
    next if done_list.include?(person.name) || ppsize >= 24 * 1024 * 1024 * 1024
    person.videos.all.each do |video|
      f.puts "move \"#{video.file_name.gsub(%r{/}, '\\')}\" #{to_phone}"
      ppsize += video.file_size
    end
  end
  LOG.info('Main') { "-> T : #{ActiveSupport::NumberHelper.number_to_human_size(ppsize)}" }
end
=end