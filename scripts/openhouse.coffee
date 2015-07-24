# Description
#   task rabbit for open house related query
#
# Configuration:
# 	OPEN_HOUSE_SPREADSHEET
#   HUBOT_GOOGLE_EMAIL
#		HUBOT_GOOGLE_KEY
#
# Commands:
#		hey hubot <dialog> - Ask "hey hubot, is there anything happened to the table yesterday?"
#   openhouse issues	- Report all issues in the log
#		openhouse search <query> - Report issues with search query (supports regular expression)
#		openhouse time <query> - Report issues happened at a specific time (<query> has to be a time string)
#
# Notes:
#   takes event triggers from
#
# Author:
#   tianwei.liu <tianwei.liu@target.com>

#require('dotenv').load()
moment = require('moment-timezone')

module.exports = (robot) ->
	robot.on "issue", (query) ->
		readSheet query.res, {
			subject: query.entities.subject
			datetime: query.entities.datetime
		}

	robot.respond /openhouse issues/i, (res) ->
		readSheet res, null

	robot.respond /openhouse search (.*)/i, (res) ->
		readSheet res, {
			subject: [value: res.match[1]]
		}

	robot.respond /openhouse time (.*)/i, (res) ->
		try
			dateObj = new Date(res.match[1])
			searchtime = moment(dateObj)
		catch err
			res.send "i can't understand that time format"
			console.log err
			return
		console.log "search: #{searchtime.format()}"
		readSheet res, {
			datetime: [type:'value', grain:'hour', value: searchtime.format()]
		}

	readSheet = (res, filters) ->
		res.send "let me grab the google spreadsheet..."
		Spreadsheet = require('edit-google-spreadsheet')
		auth =
			client_id: process.env.HUBOT_GOOGLE_CLIENT_ID
			client_secret: process.env.HUBOT_GOOGLE_SECRET
			refresh_token: process.env.HUBOT_GOOGLE_TOKEN
		options =
			debug: true
			spreadsheetId: process.env.OPEN_HOUSE_SPREADSHEET
			worksheetId: process.env.OPEN_HOUSE_WORKSHEET
			oauth2: auth
		Spreadsheet.load options, sheetReady = (err, spreadsheet) ->
			if err
				res.send "i couldn't reach google."
				console.log "failed loading spreadsheet #{err}"
				return
			else
				spreadsheet.receive getValues: true, (err, rows, info) ->
					if err
						res.send "i couldn't read the spreadsheet."
						console.log "error reading spreadsheet #{err}"
					else
						console.log "spreadsheet received: #{JSON.stringify(rows)}"
						sheetFilter res, rows, filters

	sheetFilter = (res, rows, filters) ->
		console.log "applying filters: #{JSON.stringify(filters)}" if filters?
		issues = []
		for row of rows
			if row > 1
				# entity filter
				if filters?
					continue unless containSubject rows[row], filters.subject
					continue unless containTime rows[row], filters.datetime
				issues.push row
		if issues.length == 0
			res.send "i found no issue :)"
		else
			if issues.length == 1
				res.send "okay, i found #{issues.length} issue:"
			else
				res.send "okay, i found #{issues.length} issues:"
			for i in issues
				res.send "#{rows[i][3]}\t#{rows[i][4]}\t#{rows[i][5]}"

	containSubject = (row, subjects) ->
		return true unless subjects?
		for subject in subjects
			return true if rowContains row, subject.value
		return false

	containTime = (row, datetimes) ->
		return true unless datetimes?
		dateObj = new Date(row[3])
		timestamp = moment(dateObj)
		console.log "timestamp converted from #{row[3]} to #{timestamp.format()}"
		for datetime in datetimes
			switch datetime.type
				when "value"
					switch datetime.grain
						when "day"
							day = moment(datetime.value)
							nextDay = moment(datetime.value).add(1, 'days')
							return true if timestamp.isBetween(day, nextDay)
						else
							timeStr = datetime.value.substr(0, datetime.value.length - 6) + moment().format("Z")
							dateObj = new Date(timeStr)
							search = moment(dateObj)
							console.log "search: #{search.format()}"
							console.log "diff with search: #{timestamp.diff(search, "hours")}"
							return true if -1 <= timestamp.diff(search, "hours") <= 1
				when "interval"
					from = moment(datetime.from.value)
					to = moment(datetime.to.value)
					return true if timestamp.isBetween(from, to)
		return false

	rowContains = (row, searchStr) ->
    regexString = new RegExp(searchStr,"i")
    for col of row
      if String(row[col]).match(regexString)
        return true
    return false
