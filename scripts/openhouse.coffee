# Description
#   task rabbit for open house related query
#
# Configuration:
# 	OPEN_HOUSE_SPREADSHEET
#   HUBOT_GOOGLE_EMAIL
#		HUBOT_GOOGLE_KEY
#
# Commands:
#   hey hubot (hey hubot,) <dialog> - Ask me something. I may or may not understand you.
#		hubot hey (hubot hey,) <dialog> - Ask me something. I may or may not understand you.
#
# Notes:
#   response from wit.ai will trigger event with intent as the event name and entities in JSON object as parameters
#
# Author:
#   tianwei.liu <tianwei.liu@target.com>

module.exports = (robot) ->
	robot.on "issue", (query) ->
		query.res.send "let me grab the google spreadsheet..."
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
				query.res.send "i couldn't reach google."
				console.log "failed loading spreadsheet #{err}"
			else
				readSheet query, spreadsheet

		readSheet = (query, spreadsheet) ->
			spreadsheet.receive getValues: true, (err, rows, info) ->
				if err
					query.res.send "i couldn't read the spreadsheet."
					console.log "error reading spreadsheet #{err}"
				else
					issues = []
					for row of rows
						if row > 1
							# entity filter
							continue unless containSubject rows[row], query
							continue unless containTime rows[row], query
							issues.push row
					if issues.length == 0
						query.res.send "i found no issue :)"
					else
						query.res.send "okay, i found #{issues.length} issues:"
						for i in issues
							query.res.send "#{rows[i][3]}\t#{rows[i][4]}\t#{rows[i][5]}"

		containSubject = (row, query) ->
			return true unless query.entities.subject?
			for subject in query.entities.subject
				return true if rowContains row, subject.value
			return false

		containTime = (row, query) ->
			return true unless query.entities.datetime?
			timestamp = new Date(row[3])
			for datetime in query.entities.datetime
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
