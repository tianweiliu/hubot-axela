# Description
#   task rabbit for open house related query
#
# Configuration:
# 	OPEN_HOUSE_SPREADSHEET
#   HUBOT_GOOGLE_EMAIL
#		HUBOT_GOOGLE_KEY
#
# Commands:
#		hey hubot method - Ask "hey hubot, is there anything happened to the table yesterday?"
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
		timestamp = new Date(row[3])
		for datetime in datetimes
			switch datetime.type
				when "value"
					switch datetime.grain
						when "day"
							day = new Date(datetime.value)
							nextDay = new Date(datetime.value) + new Date(86400000)
							return true if day <= timestamp <= nextDay
						else
							return true if timestamp == new Date(datetime.value)
				when "interval"
					from = new Date(datetime.from.value)
					to = new Date(datetime.to.value)
					return true if from <= timestamp <= to
		return false

	rowContains = (row, searchStr) ->
    regexString = new RegExp(searchStr,"i")
    for col of row
      if String(row[col]).match(regexString)
        return true
    return false
