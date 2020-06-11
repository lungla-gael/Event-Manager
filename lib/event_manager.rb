require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

$hours = Hash.new(0)
$weekdays = {
  0=>["Sunday", 0],
  1=>["Monday", 0],
  2=>["Tuesday", 0],
  3=>["Wednesday", 0],
  4=>["Thursday", 0],
  5=>["Friday", 0],
  6=>["Saturday", 0]
}
def clean_date(date)
  formatter = DateTime.strptime(date,'%m/%d/%Y %H:%M')
  hour = formatter.hour
  weekday = formatter.wday
  $weekdays[weekday][-1] += 1
  $hours[hour] += 1  
end

def advertisement_tip
  $hours.filter! { |key,value| value === $hours.values.max }
  puts "the peak registration hours are #{$hours.keys}"
  count_array = []
  $weekdays.each { |key,value| count_array.push(value.last) }
  $weekdays.filter! { |key, value| value.include?(count_array.max) }
  puts "Most people registered on #{$weekdays.values.map { |value| value.first}.first}"  
end

def clean_phone_number(phone_number)
  pn_length = phone_number.split(/[-, ,(,),.]/).join.length
  if pn_length === 10
    phone_number
  elsif pn_length === 11 && phone_number.split(/[-, ,(,),.]/).join[0].to_i === 1
      phone_number.slice!(0)
      phone_number
  else
    "bad number"
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts form_letter
  end
end

puts "EventManager initialized."

contents = CSV.open '../event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "../form_letter.erb"
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  date = clean_date(row[:regdate])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

advertisement_tip