request = require 'request'
try
	{ Adapter } = require 'hubot'
catch
	prequire = require 'parent-require'
	{ Adapter } = prequire 'hubot'

class AbstractAPIAdapter extends Adapter
	constructor: ->
		###*
		* Given the parsed response from the request, returns the results array
		* @param {object} Objectified body from the HTTP request
		* @return {array} Results array
		###
		if not @extractResults?
			throw new TypeError('Must implement extractResults')
		###*
		* Given the parsed response from the request, returns the next url
		* @param {object} Objectified body from the HTTP request
		* @return {string} Next page url
		###
		if not @extractNext?
			throw new TypeError('Must implement extractNext')
		###*
		* Given the parsed body from the Rest API, extract new ids object.
		* You can assume, by this stage, that the HTTP request returned error is falsey and statusCode is 200.
		* @param {object} Objectified body from the HTTP request
		* @return {object} New ids
		###
		if not @parseResponse?
			throw new TypeError('Must implement parseResponse')
		###*
		* Given suitable details will return request details
		* @param {string} key of the identity to use
		* @param {string} id of the flow to update
		* @param {string} text to post
		* @param {string}? id of the thread to update
		* @return {object} {url, headers, payload}
		###
		if not @buildRequest?
			throw new TypeError('Must implement buildRequest')
		###*
		* Triggers a poll of the API
		* Likely to use getUntil
		###
		if not @poll?
			throw new TypeError('Must implement poll')
		super
		@interval = 1000
		@lastReport = null
		@pollInProgress = true

	run: ->
		setInterval @maybePoll, @interval
		@emit 'connected'

	maybePoll: =>
		unless @pollInProgress
			@pollInProgress = true
			@poll()

	# Execute a series of paged requests until we run out of pages or a filter rejects
	getUntil: (options, each, filter = -> true) -> new Promise (resolve, reject) =>
		request.get? options, (error, response, body) =>
			if error or response?.statusCode isnt 200
				if response?.statusCode in [429, 503]
					@report { error: error, html: response?.statusCode, url: options.url }
					# Retry if the error code indicates temporary outage
					@getUntil(options, each, filter)(resolve, reject)
				else
					@robot.logger.error response?.statusCode + '-' + options.url
					@finishPoll { error: error, html: response?.statusCode, url: options.url }
					reject(error ? new Error("StatusCode: #{response.statusCode}"))
			else
				responseObject = JSON.parse(body)
				results = @extractResults responseObject
				for result in results
					if filter result
						each result
					else
						@finishPoll { html: response?.statusCode, url: options.url }
						resolve('Reached filtered object')
						return
				if @extractNext responseObject
					options.url = @extractNext responseObject
					@getUntil(options, each, filter)(resolve, reject)
				else
					@finishPoll { html: response?.statusCode, url: options.url }
					resolve('Reached end of pagination')

	finishPoll: (report) ->
		@pollInProgress = false
		report = JSON.stringify(report)
		if @lastReport isnt report
			@lastReport = report
			@robot.logger.debug report

	###*
	* Given a set of ids make best effort to publish the text and pass on the published ids
	* @param {string} text to publish
	* @param {object} ids to use.  ids = {user, flow, thread?}
	###
	postUsing: (text, ids) -> new Promise (resolve, reject) =>
		requestDetails = @buildRequest(ids.user, ids.flow, text, ids.thread)
		requestObject = @robot.http(requestDetails.url)
		requestObject.header('Accept', 'application/json')
		for key, value of requestDetails.headers
			requestObject.header(key, value)
		# Format taken from https://github.com/github/hubot/blob/master/docs/scripting.md#making-http-calls
		requestObject.post(JSON.stringify(requestObject.payload)) (error, headers, body) ->
			if not error and headers.statusCode is 200
				try
					resolve(@parseResponse(JSON.parse(body)))
				catch error
					reject(error)
			else
				reject(error ? new Error("Received #{headers.statusCode} response: #{body}"))

module.exports = AbstractAPIAdapter
