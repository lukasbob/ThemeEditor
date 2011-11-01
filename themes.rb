require 'sinatra'
require 'haml'
require 'coffee-script'
require 'sass'
require 'nokogiri'
require 'nokogiri-plist'
require 'json'
require 'manifesto'
require 'rack/coffee'

module Themes
	class Application < Sinatra::Base

		before do
			content_type :html, 'charset' => 'utf-8'
		end

		use Rack::Coffee, {
			:root => 'public',
			:urls => '/src'
		}

		set :haml, :format => :html5, :ugly => true
		set :sass, :style => :compact

		helpers do
			def build_plist(fragment)
				builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
					xml.doc.create_internal_subset("plist",
						"-//Apple Computer//DTD PLIST 1.0//EN",
						"http://www.apple.com/DTDs/PropertyList-1.0.dtd")
					xml.plist(:version => "1.0") { xml << fragment }
				end
				builder.to_xml
			end
			def files
				themefiles = File.join("../**", "*.tmTheme")
				Dir.glob(themefiles).collect{ |f|
					{
						:file => f,
						:file_escaped =>  CGI.escape(f),
						:name => File.basename(f, ".tmTheme")
					}
				}
			end
		end

		get '/sass/*.css' do |f|
			content_type :css
			sass f.to_sym
		end

		get "/" do
			@files = files
			if params[:f]
				@file = CGI.unescape params[:f]
				@plist = Nokogiri::PList(open(@file))
				@title = "Theme: #{@plist["name"]}"
				if params[:o] == "json"
					content_type :json
					@plist.to_json
				else
					haml :show
				end
			else
				@title = "File listing"
				@files = files
				haml :list
			end

		end

		post "/" do
			file = params[:f]
			content_type :json
			plist = JSON.parse(request.body.read.force_encoding("UTF-8"))
			xml = build_plist(plist.to_plist_xml)
			File.open(file, 'r+') { |f| f.write(xml) }
			true.to_json
		end
	end
end
