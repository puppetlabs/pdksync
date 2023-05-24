# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2023, by Samuel Williams.

require 'protocol/http/error'

module Protocol
	module HTTP1
		class Error < HTTP::Error
		end
		
		class InvalidRequest < Error
		end
		
		# The specified content length and the given content's length do not match.
		class ContentLengthError < Error
		end
		
		# The request was parsed correctly, but was invalid for some other reason.
		class BadRequest < Error
		end
		
		class BadHeader < Error
		end
		
		class BadResponse < Error
		end
	end
end
