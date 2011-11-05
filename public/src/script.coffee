hexColorRegex = /^#([0-9a-f]{2}){3,4}/i

window.helpers =
	titleCase: (word) ->
		word.replace(/([A-Z])/g, " $1").replace /(^[a-z])/, (s, group) ->
			group.toUpperCase()

	pad: (word, charCount, char = " ") ->
		return word if word.length >= charCount
		padding = charCount - word.length
		paddingString = ""
		paddingString = "#{char}#{paddingString}" for x in [0...padding]
		"#{word}#{paddingString}"

	shorten: (word, charCount) ->
		return word if word.length <= charCount + 3
		$('<div/>').append($('<span/>').attr("title", word).text("#{word.substr(0, charCount)}...")).html()

	getField: (key, value) ->
		if hexColorRegex.test value
			rgba = new ColorModel(color: value).rgba()
			include = "<span class='colorwell'>
				<input id='main_#{key}' data-key='#{key}' style='background-color: #{rgba};' value='#{value}'>
				<label for='main_#{key}' class='color'>#{helpers.pad value, 9} : #{rgba}</label>
			</span>"
		else if $.isNumeric value
			include = "<input id='main_#{key}' data-key='#{key}' value='#{value}' type='number' class='txt'>"
		else
			include = "<input id='main_#{key}' data-key='#{key}' value='#{value}' class='txt'>"

		include

$ ->

 ##########################################################################
 #                                                                        #
 #   ___        _     _  _               _    _                           #
 #  / __| _  _ | |__ | |(_) _ __   ___  | |_ | |_   ___  _ __   ___  ___  #
 #  \__ \| || || '_ \| || || '  \ / -_) |  _|| ' \ / -_)| '  \ / -_)(_-<  #
 #  |___/ \_,_||_.__/|_||_||_|_|_|\___|  \__||_||_|\___||_|_|_|\___|/__/  #
 #                                                                        #
 #                  - A Theme Editor for Sublime Text 2                   #
 #                                                                        #
 #                       (c) Mads Jacobsen, 2011                          #
 #                                                                        #
 ##########################################################################

	_.templateSettings =
		interpolate : /\{\{(.+?)\}\}/g
		evaluate: /\<\@(.+?)\@\>/gim

###############################################################################

	window.Plist = class Plist extends Backbone.RelationalModel

		relations: [{
			type: Backbone.HasMany
			key: "settings"
			relatedModel: "Rule"
			collectionType: "RuleList"
			reverseRelation:
				key: "list"
				includeInJSON: false
		}]

		initialize: ->
			@bind "change", @save
			@get("settings").bind "change", @save
			@get("settings").bind "remove", @save
			wStatusModel.set
				thinking: no
				text: "#{helpers.shorten @get("name"), 15} is ready!"

		save: =>
			wStatusModel.set
				thinking: yes
				text: "Saving..."
			$.ajax
				url: document.location.href
				type: 'POST'
				dataType: 'json'
				data: JSON.stringify @toJSON()
				contentType: 'application/json; charset=utf-8'
				success: (data) ->
					wStatusModel.set
						thinking: no
						text: "Saved #{data}"
					$(window).trigger "save"

###############################################################################

	window.Rule = class Rule extends Backbone.RelationalModel

		relations: [{
			type: Backbone.HasOne
			key: "settings"
			relatedModel: "Settings"
			reverseRelation:
				type: Backbone.HasOne
				key: "rule"
				includeInJSON: no
		}]

		initialize: -> unless @get("settings")? then @set settings: new Settings

		fontStyle: -> @get("settings").get "fontStyle"

###############################################################################

	window.Settings = class Settings extends Backbone.RelationalModel

		initialize: -> @bind "change", -> @get("rule").change()

###############################################################################

	window.RuleList = class RuleList extends Backbone.Collection
		model: Rule

###############################################################################

	class RulesView extends Backbone.View

		el: $("#content")

		events:
			'click button.add': 'addRule'

		initialize: ->
			@model.get("settings").bind 'add', (rule) =>
				@renderRule(rule).activate()

		render: =>
			settings = @model.get("settings").first().get "settings"
			@$('.table tbody').empty()
			@$('.table').css
				backgroundColor: settings.get "background"
				color: settings.get "foreground"

			@model.get("settings").each (rule, index) =>
				if index is 0
					@renderMainSettings rule
				else
					@renderRule rule
			@

		renderRule: (rule) ->
			view = new RuleView  model: rule
			@$('.table tbody').append view.render().el
			view

		renderMainSettings: (rule) ->
			@$(".mainSettings").html (new SettingsView model: rule).render().el

		addRule: =>
			@model.get("settings").add new Rule
				name: "Unnamed style"
				scope: "Unnamed scope selector"
				settings: {}


###############################################################################

	class RuleView extends Backbone.View

		tagName: "tr"

		template: _.template($("#settingsItemTemplate").html())

		events:
			"change .b"              : "b"
			"change .i"              : "i"
			"change .u"              : "u"
			"change .name"           : "name"
			"change .fg"             : "fg"
			"change .bg"             : "bg"
			"click .delete"          : "delete"
			"click .colorwell input" : "showColorPicker"
			"focus .colorwell input" : "showColorPicker"
			"click"                  : "focus"
			"focus"                  : "select"
			'dblclick span'          : "activate"
			'blur [name*="name"]'    : "deactivate"
			'keydown'                : "handleKeypress"

		initialize: ->
			@model.get("settings").bind "change", => @render()
			@model.bind "change:name", => @render()

		render: ->
			viewDefaults =
				scope: "No scope"
				name: "No name"

			content = @template _.extend viewDefaults, @model.toJSON()

			$(@el).empty().html content
			$(@el).attr tabindex: 0
			fontStyle = @model.fontStyle()
			@$('.b').prop "checked", fontStyle?.indexOf("bold") > -1
			@$('.i').prop "checked", fontStyle?.indexOf("italic") > -1
			@$('.u').prop "checked", fontStyle?.indexOf("underline") > -1
			@

		setFontStyle: (style, add) ->
			if add then @addFontStyle(style) else @removeFontStyle(style)

		addFontStyle: (style) ->
			fontStyle = @model.fontStyle()?.split(" ") or []
			fontStyle.push style
			@model.get("settings").set fontStyle: $.trim fontStyle.join " "

		removeFontStyle: (style) ->
			@model.get("settings").set
				fontStyle: $.trim @model.fontStyle().replace style, ""

		delete: ->
			@model.get("list").get("settings").remove @model
			@remove()

		showColorPicker: (e) ->
			cell = e.currentTarget
			wColorPicker.model = new ColorModel color: cell.value
			wColorPicker.options.anchor = cell
			wColorPicker.render().show().bind "commit", (color) ->
				$(cell).val(color).change()

		activate: -> $(@el).addClass("active").find('[name*="name"]').focus()

		deactivate: -> $(@el).removeClass "active"

		focus: -> $(@el).focus()

		select: ->
			$(@el).parent().find(".selected").removeClass "selected"
			$(@el).addClass "selected"
			window.active.model = @model
			window.active.render()

		handleKeypress: (e) ->
			return unless $(@el).is ":focus"
			switch e.keyCode
				when 8, 46 # delete or backspace
					e.preventDefault()
					@delete() if confirm "Delete this rule?"
				when 13 # return
					@activate()

		b: (e)    -> @setFontStyle "bold", e.currentTarget.checked
		i: (e)    -> @setFontStyle "italic", e.currentTarget.checked
		u: (e)    -> @setFontStyle "underline", e.currentTarget.checked
		name: (e) -> @model.set "name": e.currentTarget.value
		fg: (e)   -> @model.get("settings").set "foreground": e.currentTarget.value
		bg: (e)   -> @model.get("settings").set "background": e.currentTarget.value

###############################################################################

	class SettingsView extends Backbone.View

		tagName: "fieldset"

		template: _.template $("#settingsTemplate").html()

		events:
			"click .colorwell input" : "showColorPicker"
			"focus .colorwell input" : "showColorPicker"
			"change input"           : "update"
			"click .delete"          : "delete"

		initialize: ->
			@model.get("settings").bind "change", => @render()

		render: ->
			content = @template @model.toJSON()
			$(@el).empty().html content
			@

		showColorPicker: (e) =>
			wColorPicker.model = new ColorModel color: e.currentTarget.value
			wColorPicker.options.anchor = e.currentTarget
			wColorPicker.render().show().bind "commit", (color) =>
				$(e.currentTarget).val(color).change()

		update: (e) =>
			setter = {}
			setter[$(e.currentTarget).data("key")] = e.currentTarget.value
			@model.get("settings").set setter

		delete: (e) =>
			key = $(e.currentTarget).data "key"
			if confirm "Delete the #{key} setting?"
				@model.get("settings").unset key


	window.ColorModel = class ColorModel extends Backbone.Model
		defaults:
			color: "#ffffff00"

		initialize: ->
			if @get("color") is "" then @set color: @defaults.color
			@parseColor()
			@bind "change", @buildColor

		parseColor: =>
			[r, g, b, a] = @get("color").replace("#", '').match /.{2}/g
			@set r: @toInt(r), g: @toInt(g), b: @toInt(b), a: a or 100

		toHex: (i) =>
			output = parseInt(i, 10).toString 16
			if output.length is 1 then "0#{output}" else output

		toInt: (hex) => parseInt (if hex then hex else 0), 16

		alpha: (i) =>
			output = parseInt i, 10
			return "" if output is 100
			if output.toString().length is 1 then "0#{output}" else "#{output}"

		rgba: =>
			if @get("color") is "#ffffff00"
				""
			else
				"rgba(#{@get "r"},#{@get "g"},#{@get "b"},#{parseInt(@get("a"), 10)/100})"

		hex:  =>
			"##{@toHex @get "r"}#{@toHex @get "g"}#{@toHex @get "b"}#{@alpha @get "a"}"

		bestTextColor: =>
			threshold = 105
			bgDelta = (0.299 * @get "r") + (0.587 * @get "g") + (0.114 * @get "b")
			if (255 - bgDelta) * @get("a") / 100 < threshold then "#000" else "#fff"

		buildColor: (m) =>
			if m.hasChanged "color" then @parseColor()
			else @set color: @hex(), rgba: @rgba()

###############################################################################
	class HeaderView extends Backbone.View

		el: $("header")

		render: ->
			@$("h1").text @model.get "name"
			@$(".author").text @model.get "author"
			@

	class ActiveView extends Backbone.View

		el: $("div.selected")

		events:
			"change input": "update"

		render: ->
			@$('input').val @model.get "scope"

		update: (e) => @model.set scope: e.currentTarget.value

	class SidebarView extends Backbone.View

		el: $("#sidebar")

		events:
			"click a": "select"

		select: (e) =>
			wStatusModel.set
				thinking: yes
				text: "Loading #{$(e.currentTarget).text()}..."
			$.getJSON "#{e.currentTarget.href}&o=json", (data) =>
				window.myList = new Plist data
				window.rules.model = myList
				window.rules.render()

				window.header.model = myList
				window.header.render()
				document.title = "Theme: #{myList.get("name")}"
				history.pushState {}, "", e.currentTarget.href

				@$(".selected").removeClass "selected"
				$(e.currentTarget).addClass "selected"
			e.preventDefault()

###############################################################################

	class StatusView extends Backbone.View

		template: _.template($("#statusTemplate").html())

		className: "status"

		initialize: ->
			@model.bind "change:thinking", @setThinking
			@model.bind "change:text", @updateText

		render: ->
			content = @template @model.toJSON()
			$(@el).empty().html content
			@

		setThinking: (m, thinking) =>
			if thinking then $(@el).addClass 'thinking'
			else $(@el).removeClass 'thinking'

		updateText: (m, content) => @$('.text').html content

###############################################################################

	class ColorPickerView extends Backbone.View

		className: "colorpicker hide"

		template: _.template($("#colorTemplate").html())

		events:
			"change input"        : "update"
			"click button.ok"     : "commit"
			"click button.cancel" : "hide"

		render: ->
			# Make sure there is nothing bound to the commit event.
			@unbind "commit"
			@model.bind "change:color", @renderColor
			@model.bind "change:r", @renderRangeControls
			@model.bind "change:g", @renderRangeControls
			@model.bind "change:b", @renderRangeControls
			@model.bind "change:a", @renderRangeControls

			content = @template _.extend @model.toJSON(), {
				rgba: @model.rgba(),
				textColor: @model.bestTextColor()
			}

			$(@el).empty().html content
			@

		renderColor: =>
			@$(".preview").css({
				color: @model.bestTextColor(),
				backgroundColor: @model.rgba()
			}).val @model.get "color"

		renderRangeControls: =>
			@$("#red").val @model.get "r"
			@$("#green").val @model.get "g"
			@$("#blue").val @model.get "b"
			@$("#alpha").val @model.get "a"

		setPosition: =>
			pos       = $(@options.anchor).offset()
			winHeight = $(window).height()
			elHeight  = $(@el).outerHeight()
			elWidth   = $(@el).outerWidth()
			hOffset   = elHeight / 2 - $(@options.anchor).outerHeight() / 2
			wOffset   = $(@options.anchor).width()
			posTop    = pos.top - hOffset
			posLeft   = pos.left - elWidth - 5
			orgPosTop = posTop

			# Adjust top position to stay on screen.
			posTop    = 10 if posTop < 10
			posTop    = winHeight - elHeight - 10 if elHeight + posTop > winHeight

			# Move the pointer if there is any adjustment to the top position.
			hAdjust =  orgPosTop - posTop
			if hAdjust isnt 0
				pTopMargin = parseInt @$('.tr').css("margin-top").split("px")[0], 10
				@$('.tr').css
					marginTop: hAdjust + pTopMargin

			$(@el).css
				top: posTop
				left: posLeft
			@

		update: (e) =>
			setter = {}
			setter[e.currentTarget.name] = e.currentTarget.value
			@model.set(setter)

		commit: =>
			@trigger "commit", @model.get "color"
			@hide()

		handleKeypress: (e) =>
			switch e.keyCode
				when 13 then @commit()
				when 27 then @hide()

		show: =>
			$(window).bind "keydown.colorpicker", @handleKeypress
			@setPosition()
			$(@el).removeClass('hidden')
			_.delay (=> $(@el).removeClass('hide')), 1
			@

		hide: =>
			$(window).unbind "keydown.colorpicker"
			@model.destroy()
			$(@el).addClass('hide')
			_.delay (=> $(@el).addClass('hidden')), 150

###############################################################################

	window.wStatusModel = new Backbone.Model text: "Loading...", thinking: yes

	window.myList = new Plist plist

	window.rules = new RulesView(model: myList).render()

	window.header = new HeaderView(model: myList).render()

	window.active = new ActiveView

	$(window.header.el).append new StatusView(model: wStatusModel).render().el

	new SidebarView

	window.wColorPicker = new ColorPickerView model: new ColorModel
	$('body').append wColorPicker.el
