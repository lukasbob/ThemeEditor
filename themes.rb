require 'coffee-script'
require 'haml'
require 'json'
require 'nokogiri'
require 'nokogiri-plist'
require 'rack/coffee'
require 'sass'
require 'sinatra'
require './partials'


module Themes
	class Application < Sinatra::Base

		set :file_root, "~/Library/Application Support/Sublime Text 2/Packages"
		set :haml, :format => :html5, :ugly => true
		set :sass, :style => :compact

		before do
			content_type :html, 'charset' => 'utf-8'
		end

		use Rack::Coffee, {
			:root => 'public',
			:urls => '/src'
		}

		helpers Sinatra::Partials

		helpers do

			def build_plist(object)
				builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
					xml.doc.create_internal_subset("plist",
						"-//Apple//DTD PLIST 1.0//EN",
						"http://www.apple.com/DTDs/PropertyList-1.0.dtd")
					xml.plist(:version => "1.0") { xml << object.to_plist_xml }
				end
				builder.to_xml
			end

			def files
				themefiles = File.join(File.expand_path(settings.file_root), "./**", "*.tmTheme")
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
			File.open(file, 'w') { |f| f.write(build_plist(plist)) }
			File.mtime(file).strftime("%d-%m-%Y %H:%M:%S").to_json
		end
	end
end
