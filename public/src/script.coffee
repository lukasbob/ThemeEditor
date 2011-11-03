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

	_.templateSettings = { interpolate : /\{\{(.+?)\}\}/g }

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
			statusModel.set
				thinking: no
				text: "#{@get("name")} is ready!"

		save: =>
			statusModel.set
				thinking: yes
				text: "Saving..."
			$.ajax
				url: document.location.href
				type: 'POST'
				dataType: 'json'
				data: JSON.stringify @toJSON()
				contentType: 'application/json; charset=utf-8'
				success: (data) ->
					statusModel.set
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
			@$('tbody').empty()
			@$('.table').css
				backgroundColor: @model.get("settings").first().get("settings").get("background")
				color: @model.get("settings").first().get("settings").get("foreground")

			@model.get("settings").each (rule, index) =>
				if index is 0
					@renderMainSettings rule
				else
					@renderRule rule
			@

		renderRule: (rule) ->
			@$('tbody').append((newRule = new RuleView { model: rule }).render().el)
			newRule

		renderMainSettings: (rule) ->
			@$(".mainSettings").html((new SettingsView { model: rule }).render().el)

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
			"change .b"                : "bold"
			"change .i"                : "italic"
			"change .u"                : "underline"
			"change .name"             : "name"

			"change .fg"               : "fg"
			"change .bg"               : "bg"
			"click .delete"            : "delete"
			"click .colorwell input"   : "showColorPicker"
			"focus .colorwell input"   : "showColorPicker"
			"click"                    : "focus"
			"focus"                    : "select"
			'dblclick span'            : "activate"
			'blur input[name*="name"]' : "deactivate"
			'keydown'                 : "handleKeypress"

		isSelected: => $(@el).hasClass('selected')

		initialize: ->
			@model.get("settings").bind "change", => @render()
			@model.bind "change:name", => @render()

		render: ->
			viewDefaults =
				scope: "No scope"
				name: "No name"

			content = @template _.extend viewDefaults, @model.toJSON()
			@el.innerHTML = content
			$(@el).attr tabindex: 0
			fontStyle = @model.get("settings").get "fontStyle"
			@$('.b').prop "checked", fontStyle?.indexOf("bold") > -1
			@$('.i').prop "checked", fontStyle?.indexOf("italic") > -1
			@$('.u').prop "checked", fontStyle?.indexOf("underline") > -1
			@

		toggleFontStyle: (style, add) =>
			if add then @addFontStyle(style) else @removeFontStyle(style)

		addFontStyle: (style) =>
			fontStyle = @model.get("settings").get("fontStyle")?.split(" ") or []
			fontStyle.push style
			@model.get("settings").set fontStyle: $.trim fontStyle.join(" ")

		removeFontStyle: (style) =>
			@model.get("settings").set
				fontStyle: $.trim @model.get("settings").get("fontStyle").replace(style, '')

		delete: =>
			@model.get("list").get("settings").remove @model
			@remove()

		showColorPicker: (e) =>
			cell = e.currentTarget
			window.colorPicker.model = new ColorModel { color: cell.value }
			window.colorPicker.options.anchor = cell
			window.colorPicker.render().reveal().bind "commit", (color) =>
				$(cell).val(color).change()

		activate: => $(@el).addClass("active").find('input[name*="name"]').focus()

		deactivate: => $(@el).removeClass("active")

		focus: =>	$(@el).focus()

		select: =>
			$(@el).parent().find(".selected").removeClass("selected")
			$(@el).addClass('selected')
			window.active.model = @model
			window.active.render()

		handleKeypress: (e) =>
			if (e.keyCode is 8 or e.keyCode is 46) and $(@el).is(":focus")
				e.preventDefault()
				@delete() if confirm "Delete this rule?"

			if (e.keyCode is 13) and $(@el).is(":focus")
				@activate()



		bold: (e)      => @toggleFontStyle "bold", e.currentTarget.checked
		italic: (e)    => @toggleFontStyle "italic", e.currentTarget.checked
		underline: (e) => @toggleFontStyle "underline", e.currentTarget.checked
		name: (e)      => @model.set "name": e.currentTarget.value
		fg: (e)        =>	@model.get("settings").set "foreground": e.currentTarget.value
		bg: (e)        =>	@model.get("settings").set "background": e.currentTarget.value

###############################################################################

	class SettingsView extends Backbone.View

		tagName: "fieldset"

		template: _.template($("#settingsTemplate").html())

		events:
			"click .colorwell input"     : "showColorPicker"
			"focus .colorwell input"     : "showColorPicker"
			"change #main_fg"            : "fg"
			"change #main_bg"            : "bg"
			"change #main_caret"         : "caret"
			"change #main_selection"     : "selection"
			"change #main_invisibles"    : "invisibles"
			"change #main_lineHighlight" : "lineHighlight"

		initialize: ->
			@model.get("settings").bind "change", => @render()

		render: ->
			content = @template @model.toJSON()
			@el.innerHTML = content
			@

		showColorPicker: (e) =>
			window.colorPicker.model = new ColorModel { color: e.currentTarget.value }
			window.colorPicker.options.anchor = e.currentTarget
			window.colorPicker.render().reveal().bind "commit", (color) =>
				$(e.currentTarget).val(color).change()

		fg: (e)            =>	@model.get("settings").set "foreground": e.currentTarget.value
		bg: (e)            =>	@model.get("settings").set "background": e.currentTarget.value
		caret: (e)         =>	@model.get("settings").set "caret": e.currentTarget.value
		selection: (e)     =>	@model.get("settings").set "selection": e.currentTarget.value
		invisibles: (e)    =>	@model.get("settings").set "invisibles": e.currentTarget.value
		lineHighlight: (e) =>	@model.get("settings").set "lineHighlight": e.currentTarget.value

	window.ColorModel = class ColorModel extends Backbone.Model
		defaults:
			color: "#ffffff00"

		initialize: ->
			if @get("color") is "" then @set color: @defaults.color
			@parseColor()
			@bind "change", @buildColor

		parseColor: =>
			[hex, r, g, b, a] = @get("color").split /#([\w]{2})([\w]{2})([\w]{2})([\w]{2})?/gi
			@set
				red: @toInt r
				green: @toInt g
				blue: @toInt b
				alpha: if a then a else 100

		toHex: (i) =>
			output = parseInt(i, 10).toString 16
			if output.length is 1 then "0#{output}" else output

		toInt: (hex) => parseInt (if hex then hex else 0), 16

		alpha: (i) =>
			output = parseInt(i, 10)
			return "" if output is 100
			if output.toString().length is 1 then "0#{output}" else "#{output}"

		rgba: =>
			if @get("color") is "#ffffff00"
				""
			else
				"rgba(#{@get "red"},#{@get "green"},#{@get "blue"},#{parseInt(@get("alpha"), 10)/100})"

		hex:  =>
			"##{@toHex @get("red")}#{@toHex @get("green")}#{@toHex @get("blue")}#{@alpha @get("alpha")}"

		bestTextColor: =>
			threshold = 105
			bgDelta = ((@get("red") * 0.299) + (@get("green") * 0.587) + (@get("blue") * 0.114))
			if ((255 - bgDelta) * @get("alpha") / 100 < threshold) then "#000" else "#fff"

		buildColor: (item) =>
			if item.hasChanged "color"
				@parseColor()
			else
				@set
					color: @hex()
					rgba: @rgba()

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
			@$('input').val @model.get("scope")

		update: (e) => @model.set scope: e.currentTarget.value

	class SidebarView extends Backbone.View

		el: $("#sidebar")

		events:
			"click a": "select"

		select: (e) =>
			statusModel.set
				thinking: yes
				text: "Loading #{$(e.currentTarget).text()}"
			$.getJSON "#{e.currentTarget.href}&o=json", (data) =>

				window.myList = new Plist data
				window.rules.model = myList
				window.rules.render()

				window.header.model = myList
				window.header.render()
				document.title = "Theme: #{myList.get("name")}"
				history.pushState({}, "", e.currentTarget.href)

				@$(".selected").removeClass("selected")
				$(e.currentTarget).addClass("selected")
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
			@el.innerHTML = content
			@

		setThinking: (model, thinking) =>
			if thinking
				$(@el).addClass('thinking')
			else
				$(@el).removeClass('thinking')

		updateText: (model, text) => @$('.text').text(text)

###############################################################################

	class ColorPickerView extends Backbone.View

		className: "colorpicker"

		template: _.template($("#colorTemplate").html())

		events:
			"change input"        : "update"
			"click button.ok"     : "commit"
			"click button.cancel" : "hide"

		render: ->
			@model.bind "change:color", @renderColor
			@model.bind "change:red", @renderRangeControls
			@model.bind "change:green", @renderRangeControls
			@model.bind "change:blue", @renderRangeControls
			@model.bind "change:alpha", @renderRangeControls

			content = @template _.extend @model.toJSON(), {
				rgba: @model.rgba(),
				textColor: @model.bestTextColor()
			}

			@el.innerHTML = content
			@

		renderColor: =>
			@$(".preview").css({
				color: @model.bestTextColor(),
				backgroundColor: @model.rgba()
			}).val @model.get "color"

		renderRangeControls: =>
			@$("#red").val @model.get "red"
			@$("#green").val @model.get "green"
			@$("#blue").val @model.get "blue"
			@$("#alpha").val @model.get "alpha"

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

			# Move the triangular pointer if there has beenany adjustment in top position.
			hAdjust =  orgPosTop - posTop
			if hAdjust isnt 0
				pointerTopMargin = parseInt @$('.tr').css("margin-top").split("px")[0], 10
				@$('.tr').css
					marginTop: hAdjust + pointerTopMargin

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

		reveal: =>
			@setPosition()
			$(@el).removeClass('hidden hide')
			@

		hide: =>
			@model.destroy()
			$(@el).addClass('hide')
			_.delay (=> $(@el).addClass('hidden')), 300

###############################################################################

	$('tbody').hide()

	window.statusModel = new Backbone.Model(text: "Loading...", thinking: yes)

	window.myList = new Plist plist

	window.rules = new RulesView({ model: myList }).render()

	window.header = new HeaderView({ model: myList }).render()

	window.active = new ActiveView


	$(window.header.el).append(new StatusView(model: window.statusModel).render().el)

	new SidebarView

	window.colorPicker = new ColorPickerView model: new ColorModel
	$('body').append window.colorPicker.el

	$('tbody').fadeIn(100)
