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

require 'thread'

class Bar
	def kill(evil = true)
		Fm.bar_del(self)
		@thread.kill
	end

	def set_text_prefix(text)
		@text_prefix = text
	end
	def set_text(text)
		@text_prefix = nil
		@text = text
	end
	alias text= set_text

	attr_accessor :thread, :counter, :max
	def done
		if @counter.is_a? MutableNumber
			@counter.value.to_f / @max
		else
			0
		end
	end

	def update() end

	def text
		if @text_prefix
			"#{@text_prefix} #{(@counter.value.to_f * 10000/ @max).round.to_f/100}%"
		elsif @text
			@text
		else
			""
		end
	end
end

class CopyOrMoveBar < Bar
	def initialize(files, path)
		path = path.path unless path.is_a? String
		Fm.bar_add(self)
		log([files, path])

		
		@thread = Thread.new do
			begin
				for file in files
					file = file.path unless file.is_a? String
					if File.exists?(file)
						run_operation(file, path)
					end
				end
			rescue
				log $!
				log $!.backtrace
			ensure
				kill(false)
			end
		end
		@thread.priority = Fm::COPY_PRIORITY
	end
end

class CopyBar < CopyOrMoveBar
	def run_operation(file, path)
		if File.directory?(file)
			FileUtils.cp_r_in_bar(self, file, path)
		else
			FileUtils.cp_in_bar(self, file, path)
		end
	end
end

class MoveBar < CopyOrMoveBar
	def run_operation(file, path)
		FileUtils.mv_in_bar(self, file, path)
	end
end

