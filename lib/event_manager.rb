# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone(phone_number)
  return '0000000000' if phone_number.nil?

  phone_number = phone_number.gsub(/[^0-9]/, '')
  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number.start_with?('1')
    phone_number[1..]
  else
    '0000000000'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)
hour_counts = Hash.new(0)
day_counts = Hash.new(0)
template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  timestamp = row[:regdate]

  hour = DateTime.strptime(timestamp, '%m/%d/%y %H:%M').hour
  hour_counts[hour] += 1

  day_of_week = Date.strptime(timestamp, '%m/%d/%y').wday
  day_counts[day_of_week] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

peak_hour, = hour_counts.max_by { |_hour, count| count }
peak_day, peak_count = day_counts.max_by { |_day, count| count }
# why _day/_hour, bcs for readability and to show that hour and day arg are not used

day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
peak_day_name = day_names[peak_day]

puts "Peak Day: #{peak_day_name}, Registrations: #{peak_count}"
puts "Peak Hour: #{peak_hour}, Count: #{peak_count}"
