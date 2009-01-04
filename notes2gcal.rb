#!/usr/bin/ruby

require 'googlecalendar/calendar'
require 'date'
require 'kconv'
require 'nkf'
require 'notes_lib'

#--------------------------------------------------------------------------#
# Require
# RubydeDomino Ver1.00
# http://www.tech-notes.dyndns.org/notes_lib/
#--------------------------------------------------------------------------#

# Changelog


# Configuration
NS = Notes::NotesSession.new
DB = NS.GetDatabase("", "mail/MAIL.nsf")
GCAL_ACCOUNT = "username@gmail.com"
GCAL_PASSWORD = "password"
GCAL_FEED = "http://www.google.com/calendar/feeds/hogehoge%40group.calendar.google.com/private/full"

GCAL_DEL = true
verbose  = true

date = Date.today
date_from = date
date_to   = date +30

server = GoogleCalendar::Service.new(GCAL_ACCOUNT, GCAL_PASSWORD)
calendar = GoogleCalendar::Calendar.new(server, GCAL_FEED)
STDOUT .print "Connect Google Calendar => #{GCAL_ACCOUNT}\n"


# delete EVENTS in the period of date from Google Calendar
if GCAL_DEL
  STDOUT .print "Delete events from Google Calendar\n"
  st = Time.mktime(date_from.year, date_from.month, date_from.day, 0, 0, 0)
  en = Time.mktime(date_to.year, date_to.month, date_to.day, 23, 59, 59)
  calendar.events(:'start-min' => st,
             :'start-max' => en,
             :'max-results' => 1000).each do |event|
    if event.allday != true or event.en != Time.mktime(date_from.year, date_from.month, date_from.day)
		event.destroy!
#		p event
	
      if verbose == true
        STDOUT .print " Delete event\n"
        STDOUT .print "  What: #{event.title.tosjis}\n"
        STDOUT .print "  When: #{event.st.to_s}\n"
        STDOUT .print "  Where: #{event.where.tosjis}\n"
      end
    end
  end
end



# upload EVENTS from Lotus Notes to Google Calendar
DBtitle = DB.Title  # Title is NotesDatabase's propaty
STDOUT .print "Connect Lotus Notes Database => #{DBtitle}\n"
view = DB.view("($Calendar)")

ns_id = []
view.each { |doc|

	ns_allday = false

	ns_subject = doc['SUBJECT'].text
	
	# add v.1.0.2
	#STDOUT .print "#{ns_subject}\n"
	if ns_subject.nil? || ns_subject.empty?
		ns_subject = " "
	end
	
	ns_subject = NKF::nkf('-Ss', ns_subject)
	ns_date_cal = Time.parse("#{doc['CalendarDateTime']}")

	if GCAL_DEL == false
		st = Time.mktime(date_from.year, date_from.month, date_from.day, 0, 0, 0)
	end

	if ns_date_cal > st then

		if doc['AppointmentType'].text == "2" then
			ns_allday = true
		end

		if ns_id.assoc("#{doc['APPTUNID'].text}")

			# 繰り返しがEvent(終日予定)の場合には1件登録すれば良い
			if ns_allday
				next
			end

			ns_id_num = ns_id.assoc("#{doc['APPTUNID'].text}")
			ns_id.delete(ns_id.assoc("#{doc['APPTUNID'].text}"))
			ns_id << [doc['APPTUNID'].text,ns_id_num[1]+1]

			ns_date_st_array = doc['CalendarDateTime'].text.split(/\s*;\s*/)
			number = ns_id_num[1] + 1
			ns_date_st = Time.parse("#{ns_date_st_array[number]}")

			# 日付を置き換える
			ns_date_tmp = Time.parse("#{doc['EndDateTime']}")
			ns_date_en = Time.parse("#{ns_date_st.year}/#{ns_date_st.month}/#{ns_date_st.day} #{ns_date_tmp.hour}:#{ns_date_tmp.min}")

		else
			ns_id_num = "0"
			ns_id << [doc['APPTUNID'].text,0]
			ns_date_st = Time.parse("#{doc['StartDateTime']}")
			ns_date_en = Time.parse("#{doc['EndDateTime']}")

		end

		# data check * add 2008/10/06
		#   * st < en のケースが合ったので修正
		#   * 強制的に終了日時を開始日時に揃える
		if ns_date_st > ns_date_en 
			STDOUT .print "NG\n"
			STDOUT .print "#{ns_date_st} .. #{ns_date_en}\n"
			ns_date_en = ns_date_st
		end

		# google calendar entry
		event = calendar.create_event
		event.title = ns_subject.toutf8
		event.st = ns_date_st
		event.en = ns_date_en
		event.where = doc['Location'].text.toutf8
		if ns_allday
			event.allday = true
		end
		event.desc = doc['APPTUNID'].text + "\n" + doc['Body'].text.toutf8

		if verbose
			STDOUT .print " Create event\n"
	#		STDOUT .print "  What: #{event.title}\n"
			STDOUT .print "  ID: #{doc['APPTUNID'].text}\n"
			STDOUT .print "  What: #{ns_subject}\n"
			STDOUT .print "  When: #{event.st.to_s}\n"
			STDOUT .print "  When: #{event.en.to_s}\n"
	#		STDOUT .print "  Where: #{event.where}\n"
		end
		event.save!

	end

}

