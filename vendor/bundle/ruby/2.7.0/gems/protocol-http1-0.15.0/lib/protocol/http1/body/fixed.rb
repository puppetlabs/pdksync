# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http/body/readable'

module Protocol
	module HTTP1
		module Body
			class Fixed < HTTP::Body::Readable
				def initialize(stream, length)
					@stream = stream
					@length = length
					@remaining = length
				end
				
				attr :length
				attr :remaining
				
				def empty?
					@remaining == 0
				end
				
				def close(error = nil)
					# If we are closing the body without fully reading it, the underlying connection is now in an undefined state.
					if @remaining != 0
						@stream.close
					end
					
					super
				end
				
				# @raises EOFError if the stream is closed before the expected length is read.
				def read
					if @remaining > 0
						# `readpartial` will raise `EOFError` if the stream is closed/finished:
						if chunk = @stream.readpartial(@remaining)
							@remaining -= chunk.bytesize
							
							return chunk
						# else
						# 	raise EOFError, "Stream closed with #{@remaining} bytes remaining!"
						end
					end
				end
				
				def join
					buffer = @stream.read(@remaining)
					
					@remaining = 0
					
					return buffer
				end
				
				def inspect
					"\#<#{self.class} length=#{@length} remaining=#{@remaining}>"
				end
			end
		end
	end
end
