require 'thread'

module Fm
	extend self
	COPY_PRIORITY = -2

	COLUMNS = 4
	
	def self.initialize(pwd=nil)
		@bars = []
		@bars_thread = nil

		@entering_directory = true
		@sort_time = Time.now
		
		@buffer = ''
		@pwd = nil
		@search_string = ''
		@search_reset = true
		@copy = []
		@ignore_until = nil
		@trash = File.expand_path('~/.trash')
		pwd ||= Dir.getwd

		# `' and `` are the original PWD unless overwritten by .rangerrc
		@memory = {
			'`' => pwd,
			'\'' => pwd
		}

		# Read the .rangerrc
		@rangerrc = File.expand_path(Option.bookmark_file)
		if (File.exists?(@rangerrc))
			content = File.read(@rangerrc)
			unless content.empty?
				loaded = Marshal.load(content) rescue nil
				if Hash === loaded
					@memory.update(loaded)
				end
			end
		end
		@dump_config_on_exit = true

		# `0 is always the original PWD
		@memory['0'] = pwd

		boot_up(pwd)
	end

	attr_reader(:dirs, :pwd, :sort_time)

	def refresh()
		begin
			@pwd.refresh
			update_pointers
			draw if CLI.running?
		rescue
			lograise
		end
	end

	def edit( filename, mode=nil, flags=nil )
		file = Directory::Entry.new( filename )
		file.refresh
		raise "File doesn't exist" unless file.exists?
		runcontext = RunContext.new( file, mode, flags, 'editor' )
		externally do
			Action.run( runcontext )
		end
	end

	def reload_types()
		old_verbose_level = $VERBOSE
		$VERBOSE = nil
		load 'data/types.rb'
		load 'data/apps.rb'
		$VERBOSE = old_verbose_level
	end

	def dump_pwd_to_3()
		three = File.open(3, 'a')
		three.puts( Fm.pwd.path )
		three.close
	end

	def boot_up(pwd=nil)
		pwd ||= @pwd.path || Dir.getwd
		Scheduler.reset

		reload_types

		@dirs = Hash.new() do |hash, key|
			hash[key] = newdir = Directory.new(key)
#			newdir.schedule
			newdir
		end

		@path = [@dirs['/']]
		enter_dir(pwd)

		Scheduler.run
	end

	def lines
		CLI::lines - @bars.size
	end

	def externally(&block)
		closei
		yield if block_given?
		CLI.clear_keybuffer
		starti
	end

	def dump
		if defined? @dump_config_on_exit
			begin
				remember_dir
				dumped = Marshal.dump(@memory)
				File.open(@rangerrc, 'w') do |f|
					f.write(dumped)
				end
			rescue Exception
			end
		end
	end

	def on_interrupt
		@buffer = ''
		sleep 0.2
	end

	def terminal_killed?
		Process.ppid == 1
	end

	def main_loop
		bool = false
		while true
			exit if terminal_killed?
			@pwd.make_sure_cursor_is_in_range

			begin
				draw()
			rescue Interrupt
				on_interrupt
			rescue Exception
				log($!)
				log(caller)
			end

			begin
				key = geti
				CLI.clear_keybuffer
				press(key)
			rescue Interrupt
				on_interrupt
			end
		end
	end

	def current_path() @pwd.path end

	def reset_title() set_title("ranger: #{@pwd.path}") end

	def enter_dir_safely(dir)
		dir = File.expand_path(dir)
		if File.exists?(dir) and File.directory?(dir)
			olddir = @pwd.path
			begin
				enter_dir(dir)
				return true
			rescue
				log($!)
				log(caller)
				enter_dir(olddir)
				return false
			end
		end
	end

	def enter_dir(dir)
		@pwd.restore if @pwd
		@marked = []
		dir = File.expand_path(dir)
		return unless File.exists? dir

		oldpath = @path.dup

		# NOTE: @dirs[unknown] is not nil but Directory.new(unknown)
		## create @path, an array of directory objects
		@path = [@dirs['/']]
		unless dir == '/'
			dir.slice(0)
			accumulated = '/'
			for part in dir.split('/')
				unless part.empty?
					accumulated = File.join(accumulated, part)
					@path << @dirs[accumulated]
				end
			end
		end

		@pwd = @path.last
		@pwd.refresh! if @pwd.changed?
		@pwd.make_sure_cursor_is_in_range

		## initialize directories in @pwd
		@pwd.files_raw.dup.each do |x|
			@dirs[x] if File.directory?(x)
		end

		## set the title
		reset_title()

		## ???
		if @path.size < oldpath.size
			@pwd.pos = @pwd.files_raw.index(oldpath.last.path) || 0
		end

		i = 0

		@entering_directory = true
		Dir.chdir(@pwd.path)
	end

	def update_pointers
		@path.each_with_index do |p, i|
			## is this line necessary?
#			p.schedule
			unless i == @path.size - 1
				p.pointed_file = @path[i+1].path
			end
		end
	end

	def move_to_trash!(fn)
		unless File.exists?(@trash)
			Dir.mkdir(@trash)
		end
		new_path = File.join(@trash, fn.basename)

		Action.move(fn, new_path)

		return new_path
	end

	def move_to_trash(file)
		unless file
			return
		end

		if String === file
			file = Directory::Entry.new(file)
		end

		if file.exists?
			if file.dir?
				if !file.in?(@trash) and file.size > 0
					return move_to_trash!(file)
				else
					Dir.rmdir(file.path) rescue nil
				end
			elsif file.symlink?
				file.delete!
			else
				if !file.in?(@trash) and file.size > 0
					return move_to_trash!(file)
				else
					file.delete!
				end
			end
		end
		return nil
	end

	def bar_add(bar)
		if @bars.empty?
			# This thread updates the statusbars
			@bars_thread = Thread.new do
				while true
					draw_bars
					sleep 0.5
				end
			end
		end
		@bars << bar
	end

	def bar_del(bar)
		@bars.delete(bar)
		if @bars.empty?
			@bars_thread.kill
			@bars_thread = nil
			draw
		end
	end

	def currentfile
		@pwd.files[@pwd.pos]
	end
	def getfiles
		@marked.empty? ? [currentfile] : @marked.dup
	end
	alias selection getfiles
end

