# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'protocol/http/body/readable'

module Protocol
	module HTTP1
		module Body
			class Remainder < HTTP::Body::Readable
				BLOCK_SIZE = 1024 * 64
				
				# block_size may be removed in the future. It is better managed by stream.
				def initialize(stream)
					@stream = stream
				end
				
				def empty?
					@stream.eof? or @stream.closed?
				end
				
				def close(error = nil)
					# We can't really do anything in this case except close the connection.
					@stream.close
					
					super
				end
				
				# TODO this is a bit less efficient in order to maintain compatibility with `IO`.
				def read
					@stream.readpartial(BLOCK_SIZE)
				rescue EOFError, IOError
					# I noticed that in some cases you will get EOFError, and in other cases IOError!?
					return nil
				end
				
				def call(stream)
					self.each do |chunk|
						stream.write(chunk)
					end
					
					stream.flush
				end
				
				def join
					@stream.read
				end
				
				def inspect
					"\#<#{self.class} #{@stream.closed? ? 'closed' : 'open'}>"
				end
			end
		end
	end
end
