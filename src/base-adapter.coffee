try
	{ Adapter, TextMessage } = require 'hubot'
catch
	prequire = require 'parent-require'
	{ Adapter, TextMessage } = prequire 'hubot'

class BaseAdapter extends Adapter
	constructor: ->
		super
		@pingCount = 0

	send: (envelope, strings...) ->
		@robot.logger.info 'Send'

	reply: (envelope, strings...) ->
		@robot.logger.info 'Reply'

	run: ->
		setInterval @ping, 1000
		@emit 'connected'

	ping: =>
		user = @robot.brain.userForId 1122, name: 'Ping User'
		message = new TextMessage user, 'ping ' + @pingCount, 'MSG-' + @pingCount
		@pingCount++
		@receive message

exports.use = (robot) ->
	new BaseAdapter robot
