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

# This thread inspects directories
module Scheduler
	extend self

	UPDATE_SIGNAL = 31
	PRIORITY = -1

	def reset()
		@scheduled = []
		@active = false

		@thread ||= Thread.new do
			## I have two ways of doing this. the first is somewhat better
			## but leads to problems with ncurses:
			## sometimes if you close the terminal window by clicking on
			## the X or pressing alt+F4 or in any other way that the window
			## manager provides, it will not properly exit and keep running
			## in the background, using up 100% CPU.
			if Option.evil
				Thread.current.priority = PRIORITY

				while true
					Thread.stop
					manage unless @scheduled.empty? or !@active
				end

			else
				while true
					sleep 0.1
					manage unless @scheduled.empty? or !@active
				end
			end
		end
	end

	def run
		@active = true
	end

	def stop
		@active = false
	end

	def <<(dir)
		dir.scheduled = true
		unless @scheduled.include? dir
			@scheduled << dir
		end
		@thread.run if Option.evil
	end

	private
	def manage
		while dir = @scheduled.shift
			dir.refresh(true)
			dir.resize
		end
		force_update
	end

	def force_update
		Process.kill( UPDATE_SIGNAL, Process.pid )
	end
end

