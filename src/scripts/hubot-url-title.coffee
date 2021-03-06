# Description:
#   Returns the title when a link is posted
#
# Dependencies:
#   "cheerio": "^0.19.0",
#   "underscore": "~1.3.3"
#   "request": "~2.30.0"
#   "iconv": "2.1.11"
#   "jschardet": "1.4.1"
#   "charset": "1.0.0"
#
# Configuration:
#   HUBOT_URL_TITLE_IGNORE_URLS - RegEx used to exclude Urls
#   HUBOT_URL_TITLE_IGNORE_USERS - Comma-separated list of users to ignore
#   HUBOT_URL_TITLE_ACCEPT_LANGUAGE - Language that can be interpreted by the client
#   HUBOT_URL_TITLE_MAX_LEN - Maximum length for title response, -1 for no limit (default)
#
# Commands:
#   http(s)://<site> - prints the title for site linked
#
# Author:
#   ajacksified, dentarg, impca

cheerio    = require 'cheerio'
_          = require 'underscore'
request    = require 'request'
charset    = require 'charset'
jschardet  = require 'jschardet'
Iconv      = require 'iconv'

MAX_SIZE_DOWNLOADED_FILES = 1000000

documentToProcessedTitle = (document) ->
	# Extract title from document and convert to one neat line
	fullTitle = document('head title').first().text().trim().replace(/\s+/g, " ")

	# Recalculate title length limiting each time
	maxTitleLength = process.env.HUBOT_URL_TITLE_MAX_LEN or '-1'
	maxTitleLength = parseInt(maxTitleLength)
	limitTitleLength = (maxTitleLength > -1)

	# Determine if length limiting is required and optionally trim title text
	if limitTitleLength and (fullTitle.length > maxTitleLength)
		title = fullTitle.substr(0,maxTitleLength-3) + "..."
	else
		title = fullTitle

hubotUrlTitle = (robot) ->

  ignoredusers = []
  if process.env.HUBOT_URL_TITLE_IGNORE_USERS?
    ignoredusers = process.env.HUBOT_URL_TITLE_IGNORE_USERS.split(',')

  robot.hear /(http(?:s?):\/\/(\S*))/gi, (msg) ->
    for url in msg.match
      username = msg.message.user.name
      if _.some(ignoredusers, (user) -> user == username)
        console.log 'ignoring user due to blacklist:', username
        return

      # filter out some common files from trying
      ignore = url.match(/\.(png|jpg|jpeg|gif|txt|zip|tar\.bz|js|css|pdf)/)

      ignorePattern = process.env.HUBOT_URL_TITLE_IGNORE_URLS
      if !ignore && ignorePattern
        ignore = url.match(ignorePattern)

      unless ignore
        size = 0
        options = {
          uri: url,
          encoding: null,
          headers: {},
          jar: true
        }
        if process.env.HUBOT_URL_TITLE_ACCEPT_LANGUAGE?
          options['headers']['Accept-Language'] = process.env.HUBOT_URL_TITLE_ACCEPT_LANGUAGE
        request options, (error, response, body) ->
          if error
            console.log error
          else if response.statusCode == 200
            enc = charset(response.headers, body)
            enc = enc || jschardet.detect(body).encoding.toLowerCase()
            robot.logger.debug "webpage encoding is #{enc}"
            if enc != 'utf-8'
              iconv = new Iconv.Iconv(enc, 'UTF-8//TRANSLIT//IGNORE')
              html = iconv.convert(new Buffer(body, 'binary')).toString('utf-8')
              document = cheerio.load(html)
              msg.send documentToProcessedTitle(document)
            else
              document = cheerio.load(body)
              msg.send documentToProcessedTitle(document)
        .on 'data', (chunk) ->
          size += chunk.length
          if size > MAX_SIZE_DOWNLOADED_FILES
            this.abort()
            msg.send "Resource at #{url} exceeds the maximum size."

# Export/expose only the processing function for the robot
module.exports = hubotUrlTitle
