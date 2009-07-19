#!/usr/bin/ruby -Ku
version = '0.2.4'

require 'pathname'
$: << MYDIR = File.dirname(Pathname(__FILE__).realpath)

if ARGV.size > 0
	case ARGV.first
	when '-k'
		exec "killall -9 #{File.basename($0)}"
	end
	pwd = ARGV.first
	if pwd =~ /^file:\/\//
		pwd = $'
	end

	unless File.exists?(pwd)
		pwd = nil
	end

else
	pwd = nil
end

for file in Dir.glob "#{MYDIR}/code/**/*.rb"
	require file [MYDIR.size + 1 ... -3]
end

## default options
opt = {
	:show_hidden            => false,
	:sort                   => :name,
	:list_dir_first         => true,
	:sort_reverse           => false,
	:bookmark_file          => '~/.ranger_bookmarks',
	:ascii_only             => true,
	:wide_bar               => true,
	:confirm_string         => "yes I am!",
	:confirm                => true,
	:file_preview           => true,
	:preview                => true,
	:mouse                  => true,
	:mouse_interval         => 200,
	:debug_level            => 3,
	:debug_file             => '/tmp/errorlog',
	:colorscheme            => 'default',
	:cd                     => ARGV.include?('--cd'),
	:evil                   => false
}

class OptionClass < Struct.new(*opt.keys)
	def confirm_string; confirm ? super : "" end
end

Option = OptionClass.new(*opt.values)
opt = nil

load 'ranger.conf'
load 'data/colorscheme/' + Option.colorscheme + '.rb'
load 'data/screensaver/clock.rb'

include Debug

Debug.setup( :name   => 'ranger',
             :file   => Option.debug_file,
             :level  => Option.debug_level )

if pwd and !ARGV.empty? and !File.directory?(pwd)
	file = Directory::Entry.new(pwd)
	file.get_data
	Action.run(RunContext.new(file, 0, 'c'))
	exit
end

include CLI

Signal.trap(Scheduler::UPDATE_SIGNAL) do
	Fm.refresh
end

CLI.init_mouse( Option.mouse_interval )

begin
	Fm.initialize( pwd )
	Fm.main_loop
ensure
	log "exiting!\n\n"

	closei if CLI.running?
	CLI.stop_mouse
	Fm.dump

	Fm.dump_pwd_to_3 if Option.cd rescue nil

	# Kill all other threads
	for thr in Thread.list
		unless thr == Thread.current
			thr.kill
		end
	end
end

