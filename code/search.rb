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

module Fm
	def goto(arg)
		if arg.is_a? Directory::Entry
			@pwd.pointed_file = arg.path

		elsif arg.is_a? String
			@pwd.pointed_file = arg

		elsif arg.is_a? Numeric
			@pwd.pos = arg

		else
			lograise ArgumentError.new
		end
	end

	FIND_PROPERTIES = {
		's' => :size,
		'm' => :mtime,
		'c' => :ctime,
	}
	FIND_KEY_REGEXP = /^f([#{ FIND_PROPERTIES.keys.join("") }])$/
	
	def quicksearch(n)
		case Option.search_method
		when *FIND_PROPERTIES.values
			quicksearch_by_property(n, Option.search_method)

		when :handler
			quicksearch_by_handler(n)

		when :regexp
			quicksearch_by_regexp(n)

		else
			raise "Wrong search method!"

		end rescue lograise
	end

	def quicksearch_by_property(n, property)
		sorted = @pwd.files.sort do |a, b|
			b.send(property) <=> a.send(property)
		end

		if @search_reset
			@search_reset = false
		else
			sorted.wrap(sorted.index(currentfile) + n)
		end

		goto(sorted.first)
	end

	def quicksearch_by_handler(n)
		sorted = @pwd.files.sort do |a, b|
			a.handler.to_s <=> b.handler.to_s
		end

		goto(sorted.first)
	end

	def quicksearch_by_regexp(n)
		begin
			rx = Regexp.new(@search_string, Regexp::IGNORECASE)
		rescue
			return false
		end

		ary = @pwd.files.dup
		ary.wrap(@pwd.pos)
		if n < 0
			ary.wrap(1)
			ary.reverse!
		end
		ary.wrap(n.abs)

		for file in ary
			if file.basename =~ rx
				return goto(file)
			end
		end
	end

	def search_reset!
		@search_reset = true
	end

	def search_reset(array)
		if @search_reset
			@search_reset = false
			sorted.wrap(sorted.index(currentfile) + n)
		end
	end

	def search(str, offset=0, backwards=false)
		begin
			rx = Regexp.new(str, Regexp::IGNORECASE)
		rescue
			return false
		end

		ary = @pwd.files_raw.dup
		ary.wrap(@pwd.pos + offset)

		ary.reverse! if backwards

		for f in ary
			g = File.basename(f)
			if g =~ rx
				@pwd.pointed_file = f
				break
			end
		end
	end

	def hints(str)
		begin
			rx = Regexp.new(str, Regexp::IGNORECASE)
		rescue
			return false
		end

		ary = @pwd.files_raw.dup
		ary.wrap(@pwd.pos)

		n = 0
		pointed = false
		for f in ary
			g = File.basename(f)
			if g =~ rx
				unless pointed
					log "point at #{f}"
					@pwd.pointed_file = f
					pointed = true
				end
				n += 1
			end
		end

		return n
	end

end
