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
		throw new TypeError('Abstract class')

	run: ->
		setInterval @poll, @interval
		@emit 'connected'

	# Execute and callback a series of paged requests until we run out of pages or a filter rejects
	getUntil: (options, filter, each, done) ->
		request.get? options, (error, response, body) =>
			if error or response?.statusCode isnt 200
				@report { error: error, html: response?.statusCode }
				if response?.statusCode in [429, 503]
					# Retry if the error code indicates temporary outage
					@getUntil options, filter, each, done
				else
					@robot.logger.error response?.statusCode + '-' + options.url
					done { error, response }
			else
				responseObject = JSON.parse(body)
				results = @extractResults responseObject
				for result in results
					if filter result
						each result
					else
						done null, results
						@report { html: response?.statusCode }
						return
				if @extractNext responseObject
					options.url = @extractNext responseObject
					@getUntil options, filter, each, done
				else
					done null, results
					@report { html: response?.statusCode }

	extractResults: (obj) -> obj?._results

	extractNext: (obj) -> obj?._pagination?.next

	report: (obj) =>
		report = JSON.stringify(obj)
		if @lastReport isnt report
			@lastReport = report
			@robot.logger.debug report

module.exports = AbstractAPIAdapter
