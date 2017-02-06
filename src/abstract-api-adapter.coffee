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
		@allowedToPoll = true
		throw new TypeError('Abstract class')

	run: ->
		setInterval @maybePoll, @interval
		@emit 'connected'

	maybePoll: =>
		if @allowedToPoll
			@allowedToPoll = false
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
		@allowedToPoll = true
		@report report
		done?(error, response)

	extractResults: -> throw new TypeError('Abstract method')

	extractNext: -> throw new TypeError('Abstract method')

	report: (obj) =>
		report = JSON.stringify(obj)
		if @lastReport isnt report
			@lastReport = report
			@robot.logger.debug report

	###*
	* Given a set of ids make best effort to publish the text and send a new set of ids to the callback
	* @param {string} text to publish
	* @param {object} ids to use.  ids = {user, flow, thread?}
	* @param {function} function to receive (error, new ids object).  ids = {thread, comment?}
	###
	postUsing: (text, ids, callback) =>
		requestDetails = buildRequest(ids.user, ids.flow, text, ids.thread)
		requestObject = @robot.http(requestDetails.url)
		requestObject.header('Accept', 'application/json')
		for key, value of requestObject.headers
			requestObject.header(key, value)
		# Format taken from https://github.com/github/hubot/blob/master/docs/scripting.md#making-http-calls
		requestObject.post(JSON.stringify(requestObject.payload)) (error, headers, body) ->
			if not error and headers.statusCode is 200
				parseResponse(JSON.parse(body), callback)
			else
				callback(error ? headers, null)

	###*
	* Given the parsed body from the Rest API, extract new ids object and pass it along the chain.
	* You can assume, by this stage, that the HTTP request returned error is falsey and statusCode is 200.
	* @param {object} JSON parsed body from the HTTP request
	* @param {function} (error, ids) next function in the chain.  ids = {thread, comment?}
	###
	parseResponse: (response, next) -> throw new TypeError('Abstract method')

	###*
	* Given suitable details will return request details
	* @param {string} key of the identity to use
	* @param {string} id of the flow to update
	* @param {string} text to post
	* @param {string}? id of the thread to update
	* @return {object} {url, headers, payload}
	###
	buildRequest: (user, flow, text, thread) -> throw new TypeError('Abstract method')

module.exports = AbstractAPIAdapter
