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
		defaults:
			foreground: ""
			background: ""
			fontStyle: ""

		initialize: -> @bind "change", -> @get("rule").change()

###############################################################################

	window.RuleList = class RuleList extends Backbone.Collection
		model: Rule

		initialize: ->
			@bind "change", @save
			@bind "remove", @save

		save: ->
			plist.settings = @toJSON()
			$.ajax
				url: document.location.href
				type: 'POST'
				dataType: 'json'
				data: JSON.stringify plist
				contentType: 'application/json; charset=utf-8'
				success: (data) -> $(window).trigger "save"

###############################################################################

	window.RulesView = class RulesView extends Backbone.View

		el: $(".table")

		events:
			'click button.add': 'addRule'

		initialize: ->
			@model.bind 'add', (rule) =>
				@renderRule(rule)
				.$("input.name").focus()


		render: =>
			@model.each (rule, index) =>
				if index is 0
					@renderMainSettings rule
				else
					@renderRule rule
			@

		renderRule: (rule) ->
			@$('tbody').append((newRule = new RuleView { model: rule }).render().el)
			newRule

		renderMainSettings: (rule) ->
			$("body").append((new SettingsView { model: rule }).render().el)

		addRule: => @model.add new Rule

###############################################################################

	window.RuleView = class RuleView extends Backbone.View

		tagName: "tr"

		template: _.template($("#settingsItemTemplate").html())

		events:
			"change .b"       : "bold"
			"change .i"       : "italic"
			"change .u"       : "underline"
			"change .name"    : "name"
			"change .scope"   : "scope"
			"change .fg"      : "fg"
			"change .bg"      : "bg"
			"click .delete"   : "delete"
			"click .colorwell": "showColorPicker"

		initialize: ->
			@model.get("settings").bind "change", => @render()

		render: ->
			viewDefaults =
				scope: "No scope"
				name: "No name"

			content = @template _.extend viewDefaults, @model.toJSON()
			@el.innerHTML = content

			fontStyle = @model.get("settings").get "fontStyle"
			@$('.b').prop "checked", fontStyle.indexOf("bold") > -1
			@$('.i').prop "checked", fontStyle.indexOf("italic") > -1
			@$('.u').prop "checked", fontStyle.indexOf("underline") > -1
			@

		toggleFontStyle: (style, add) =>
			if add then @addFontStyle(style) else @removeFontStyle(style)

		addFontStyle: (style) =>
			fontStyle = @model.get("settings").get("fontStyle").split(" ")
			fontStyle.push style
			@model.get("settings").set fontStyle: $.trim fontStyle.join(" ")

		removeFontStyle: (style) =>
			@model.get("settings").set
				fontStyle: $.trim @model.get("settings").get("fontStyle").replace(style, '')

		delete: =>
			@model.get("list").get("settings").remove @model
			@remove()

		showColorPicker: (e) =>
			window.colorPicker.model = new ColorModel { color: e.currentTarget.value }
			window.colorPicker.options.anchor = e.currentTarget
			window.colorPicker.render().setPosition().bind "commit", (color) =>
				$(e.currentTarget).val(color).change()


		bold: (e)      => @toggleFontStyle "bold", e.currentTarget.checked
		italic: (e)    => @toggleFontStyle "italic", e.currentTarget.checked
		underline: (e) => @toggleFontStyle "underline", e.currentTarget.checked
		name: (e)      =>	@model.set "name": e.currentTarget.value
		scope: (e)     =>	@model.set "scope": e.currentTarget.value
		fg: (e)        =>	@model.get("settings").set "foreground": e.currentTarget.value
		bg: (e)        =>	@model.get("settings").set "background": e.currentTarget.value

###############################################################################

	window.SettingsView = class SettingsView extends Backbone.View

		tagName: "fieldset"

		template: _.template($("#settingsTemplate").html())

		events:
			"click .colorwell": "showColorPicker"
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
			window.colorPicker.render().setPosition().bind "commit", (color) =>
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
			$(@el).fadeIn 200
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
			elHeight  = $(@el).height()
			hOffset   = elHeight / 2
			wOffset   = $(@options.anchor).width()
			posTop    = pos.top - hOffset
			posLeft   = pos.left + wOffset

			# Adjust top position to stay on screen.
			posTop    = 10 if posTop < 10
			posTop    = winHeight - elHeight - 10 if elHeight + posTop > winHeight

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

		hide: =>
			@model.destroy()
			$(@el).fadeOut 200, -> $(@el).empty()

###############################################################################

	$('tbody').hide()

	window.myList = new Plist plist

	new RulesView({ model: myList.get("settings") }).render()

	window.colorPicker = new ColorPickerView model: new ColorModel
	$('body').append window.colorPicker.el

	$('tbody').fadeIn(100)
	$("select").change -> window.location = "/t?f=" + this.value
