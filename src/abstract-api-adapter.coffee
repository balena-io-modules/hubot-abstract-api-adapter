request = require 'request'
try
	{ Adapter } = require 'hubot'
catch
	prequire = require 'parent-require'
	{ Adapter } = prequire 'hubot'

class AbstractAPIAdapter extends Adapter
	constructor: ->
		super
		@interval = 1000
		@lastReport = null
		@clearToPoll = true
		throw new TypeError('Abstract class')

	run: ->
		setInterval @maybePoll, @interval
		@emit 'connected'

	maybePoll: =>
		if @clearToPoll
			@clearToPoll = false
			@poll()

	# Execute and callback a series of paged requests until we run out of pages or a filter rejects
	getUntil: (options, each, filter, done) ->
		request.get? options, (error, response, body) =>
			if error or response?.statusCode isnt 200
				if response?.statusCode in [429, 503]
					@report { error: error, html: response?.statusCode, url: options.url }
					# Retry if the error code indicates temporary outage
					@getUntil options, filter, each, done
				else
					@robot.logger.error response?.statusCode + '-' + options.url
					@processDone error, null, { error: error, html: response?.statusCode, url: options.url }, done
			else
				responseObject = JSON.parse(body)
				results = @extractResults responseObject
				for result in results
					if (not filter?) or filter result
						each result
					else
						@processDone null, results, { html: response?.statusCode, url: options.url }, done
						return
				if @extractNext responseObject
					options.url = @extractNext responseObject
					@getUntil options, filter, each, done
				else
					@processDone null, results, { html: response?.statusCode, url: options.url }, done

	processDone: (error, response, report, done) =>
		@clearToPoll = true
		@report report
		if done?
			done error, response

	extractResults: -> throw new TypeError('Abstract method')

	extractNext: -> throw new TypeError('Abstract method')

	report: (obj) =>
		report = JSON.stringify(obj)
		if @lastReport isnt report
			@lastReport = report
			@robot.logger.debug report

module.exports = AbstractAPIAdapter
