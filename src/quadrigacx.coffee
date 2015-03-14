# https://www.quadrigacx.com/api_info

request = require 'request'
crypto = require 'crypto'

module.exports = class Quadrigacx

	constructor: (client_id, key, secret) ->

		@url = 'https://api.quadrigacx.com'
		@version = 'v2'
		@client_id = client_id
		@key = key
		@secret_hash = crypto.createHash('md5').update(secret).digest('hex')
		@nonce = Math.ceil((new Date()).getTime() / 1000)

	_nonce: () ->

		return ++@nonce

	public_request: (path, params, cb) ->

		options = 
			url: @url + '/' + @version + '/' + path
			method: 'GET'
			timeout: 15000
			json: true

		if typeof params is 'function'
			cb = params
		else 
			try 
				index = 0
				for option, value of params
					if index++ > 0
						options['url'] += '&' + option + '=' + value
					else
						options['url'] += '/?' + option + '=' + value
			catch err
				return cb(err)

		request options, (err, response, body) ->	
			try 
				if err || (response.statusCode != 200 && response.statusCode != 400)
					return cb new Error(err ? response.statusCode)
				
				cb(null, body)
			catch err
				return cb(err)

	private_request: (path, params, cb) ->

		if typeof params is 'function'
			cb = params
			params = {}

		try 
			nonce = @_nonce()
			signature_string = nonce + @client_id + @key
			signature = crypto.createHmac("sha256", @secret_hash).update(signature_string).digest('hex')

			payload = 
				key: @key
				nonce: nonce
				signature: signature

			for key, value of params
				payload[key] = value

			options = 
				url: @url + '/' + @version + '/' + path
				method: "POST"
				body: payload
				timeout: 15000
				json: true

			request options, (err, response, body) ->
				if err or (response.statusCode != 200 && response.statusCode != 400)
					return cb new Error(err ? response.statusCode)
				
				cb(null, body)

		catch err
			return cb(err)

	api: (method, params, cb) ->

		methods = 
			public: ['ticker', 'order_book', 'transactions']
			private: ['balance', 'user_transactions', 'open_orders', 'lookup_order',
					 'cancel_order', 'buy', 'sell', 'bitcoin_deposit_address', 'bitcoin_withdrawal']

		if methods['public'].indexOf(method) isnt -1 
			return @public_request(method, params, cb)

		if methods['private'].indexOf(method) isnt -1
			return @private_request(method, params, cb)
	
		return cb(new Error('no such method: ' + method))

