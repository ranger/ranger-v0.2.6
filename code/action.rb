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

require 'fileutils'

module Action
	extend self

	def close_interface
		closei
	end

	def start_interface
		starti
	end

	def copy(files, path)
		files = [files] unless files.is_a? Array
		unless files.empty?
			CopyBar.new(files, path)
		end
	end

	def move(files, path)
		files = [files] unless files.is_a? Array
		unless files.empty?
			MoveBar.new(files, path)
		end
	end

	def run(rc = nil)
		rc ||= RunContext.new(Fm.getfiles)
		assert rc, RunContext

		all      = rc.all.or false
		files    = rc.files
		mode     = rc.mode.or 0

		return false if files.nil? or files.empty?

		handler = rc.exec

		return false unless handler

		wait     = rc.wait.or wait
		new_term = rc.new_term.or false
		detach   = rc.detach.or false

		log handler
		if detach
			run_detached(handler, rc)
		else
			run_inside(handler, rc)
		end
		return true
	end

	def run_detached(what, rc)
		if rc.new_term
			p = fork { exec('x-terminal-emulator', '-e', 'bash', '-c', what) }
#			Process.detach(p)
		else
			p = fork { exec "#{what} 2>> /dev/null >> /dev/null < /dev/null" }
			Process.detach(p)
		end
	end

	def run_inside(what, rc)
		close_interface unless rc.console
		system(*what)
		wait_for_enter if rc.wait
		start_interface unless rc.console
	end

	def wait_for_enter
		print "Press [ENTER] to continue..."
		$stdin.gets
	end

	def delete!(*entries)
		for file in entries
			if file.is_a? Directory::Entry
				file = file.path
			end

			begin
				FileUtils.remove_entry_secure(file)
			rescue
				begin
					FileUtils.remove_entry(file)
				rescue
					lograise
				end
			end
		end
	end
end

