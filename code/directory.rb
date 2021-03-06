# Copyright (C) 2009, 2010  Roman Zimbelmann <romanz@lavabit.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'code/extensions/basic'

class Directory
	@@filter = nil
	# The timestamp 1 has a special meaning.
	# I hope no directory will ever have this timestamp :).
	# If it does, you will have to load the directory yourself by pressing R
	BAD_TIME = Time.at(1) 

	def initialize(path, allow_delay=false)
		@path = path
		@pos = 0
		@files = []
		@file_size = 0
		@pointed_file = nil
		@sort_time = BAD_TIME
		@mtime = BAD_TIME
		@width = 1000
		@read = false
		@free_space = nil
		@empty = true
		@scheduled = false

		refresh
	end

	def inspect
		"<Directory: #{path}>"
	end
	alias to_s inspect

	def read_dir
		@mtime = File.mtime(@path)
		log @path
		files = Dir.new(@path).to_a rescue []
		if Option.show_hidden
			files -= ['.', '..']
		else
			files.reject!{|x| x[0] == ?. or x == 'lost+found'}
		end

		if @@filter
			files.reject!{|x| x !~ @@filter}
		end

		if files.empty?
			files = ['.']
		end

		@files_raw = files.map{|bn| File.join(@path, bn)}
		files.map!{|basename| Entry.new(@path, basename)}
		@files = files
	end

	attr_reader(:path, :files, :pos, :width, :files_raw,
					:file_size, :read, :sort_time, :pointed_file)
	attr_accessor(:scheduled)

	def self.filter=(x)
		@@filter = Regexp.new(x, Regexp::IGNORECASE) rescue nil
	end
	def self.filter() @@filter end

	def schedule_resort() @sort_time = BAD_TIME end
	def scheduled?() @scheduled end
	def read?() @read end

	def pos=(x)
		@pos = x
		make_sure_cursor_is_in_range()
		@pointed_file = @files_raw[x]
		resize
	end

	def make_sure_cursor_is_in_range()
		if @files.size <= 1 or @pos < 0
			@pos = 0
		elsif @pos > @files.size - 1
			@pos = @files.size - 1
		end
	end

	def find_file(x)
		x = File.basename(x)

		files.each_with_index do |file, i|
			if file.basename == x
				self.pos = i
			end
		end
	end

	def empty?()
		Dir.entries(@path).size <= 2
	end

	def restore()
		for f in @files
			f.marked = false
		end
	end

	def pointed_file=(x)
		if @files_raw.include?(x)
			@pointed_file = x
			@pos = @files_raw.index(x)
		else
			self.pos = 0
		end
		resize
	end

	def free_space()
		if @free_space then return @free_space end

		@free_space = 0
		out = `df -Pk #{~path}`
		out = out[out.index("\n")+1, out.index("\n", out.index("\n"))]
		if out =~ /^[^\s]+ \s+ \d+ \s+ \d+ \s+  (\d+)  \s+/x
			@free_space = $1.to_i * 1024
		end
		@free_space
	end

	def size() @files.size end

	def resize()
		pos = Fm.get_offset(self, lines)
		if @files.empty?
			@width = 0
		else
			@width = 0
			@files[pos, lines-2].each_with_index do |fn, ix|
				ix += pos
				sz = fn.displayname.size + fn.infostring.size + 2
				@width = sz + 3 if @width < sz
			end
#			@width = @files[pos,lines-2].map{|x| File.basename(x).size}.max
		end
	end

	def get_file_info()
		@file_size = 0
		@files.each do |f|
			f.refresh
			@file_size += f.size if f.file?
		end
		@read = true
		schedule_resort
	end

	def refresh(info=false)
		oldfile = @pointed_file

		if File.mtime(@path) != @mtime
			read_dir
		end
		if info
			log("getting file info of #{@path}")
			get_file_info 
		end
		sort_if_needed

		if @files.include? oldfile
			self.pointed_file = oldfile
		end
	end

	def schedule()
		Scheduler << self
	end

	def refresh!()
		oldfile = @pointed_file
		read_dir
		get_file_info
		sort

		if @files.include? oldfile
			self.pointed_file = oldfile
		end
	end

	def sort_if_needed
		if @sort_time < Fm.sort_time
			sort
		end
	end

	def sort_sub(x, y)
		case Option.sort
		when :ext
			x.ext <=> y.ext
		when :type
			x.ext.filetype <=> y.ext.filetype
		when :size
			x.size <=> y.size
		when :ctime
			x.ctime <=> y.ctime
		when :mtime
			x.mtime <=> y.mtime
		when :name, Object
			x.basename <=> y.basename
		end
	end

	def sort()
		@sort_time = Time.now
		files = @files.sort {|x,y|
			if Option.list_dir_first
				if x.dir?
					if y.dir? then sort_sub(x, y) else -1 end
				else
					if y.dir? then 1 else sort_sub(x, y) end
				end
			else
				sort_sub(x, y)
			end
		}
		files.reverse! if Option.sort_reverse
		@files_raw = files.map{|x| x.to_s}
		@files = files
	end

	def changed?
		File.mtime(@path) != @mtime
	end
end

