# Protocol::HTTP1

Provides a low-level implementation of the HTTP/1 protocol.

[![Development Status](https://github.com/socketry/protocol-http1/workflows/Test/badge.svg)](https://github.com/socketry/protocol-http1/actions?workflow=Test)

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'protocol-http1'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install protocol-http1

## Usage

Here is a basic HTTP/1.1 client:

``` ruby
require 'async'
require 'async/io/stream'
require 'async/http/endpoint'
require 'protocol/http1/connection'

Async do
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com/search?q=kittens", alpn_protocols: ["http/1.1"])
	
	peer = endpoint.connect
	
	puts "Connected to #{peer} #{peer.remote_address.inspect}"
	
	# IO Buffering...
	stream = Async::IO::Stream.new(peer)
	client = Protocol::HTTP1::Connection.new(stream)
	
	def client.read_line
		@stream.read_until(Protocol::HTTP1::Connection::CRLF) or raise EOFError
	end
	
	puts "Writing request..."
	client.write_request("www.google.com", "GET", "/search?q=kittens", "HTTP/1.1", [["Accept", "*/*"]])
	client.write_body(nil)
	
	puts "Reading response..."
	response = client.read_response("GET")
	
	puts "Got response: #{response.inspect}"
	
	puts "Closing client..."
	client.close
end
```

## Contributing

1.  Fork it
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create new Pull Request

## License

Released under the MIT license.

Copyright, 2019, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
