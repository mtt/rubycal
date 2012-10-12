#Events will be added to each day that they occur on, but will also keep track of the position which the main Calendar object will set
#Position will be the Event's position in the stack of events for that day(i.e)
#                 1        2        3      4       5       
#                 e1       e1       e1             e2
#                          e3       e3
#------------------------------------------------------
#6       7        8        9       10      11
#e4      e4       e4       e4      e4      e4
#        e5       e5       e5      e6      e6
#------------------------------------------------------
#In this example, e1's pos would be 0 for day's 1,2, and 3.
#e5's pos would be 1 for day's 7,8, and 9.

#Cloud Nine Test
#Cloud Nine Test 2



class Calendar

  attr_reader :days
  
  SATURDAY = 6
  SUNDAY   = 0
  
  def initialize(options={})
    @weeks = []
    @number_of_weeks = 0
    @number_of_events = 0
    @events = []
    @month = options[:month]
    @year  = options[:year]
    @ouput = ''
    build_calendar(@year,@month) if @month && @year
    yield(self) if block_given?
  end
  
  #Month of calendar year and month
  def build_calendar(y,m)
    @month,@year = m.to_i,y.to_i
    first = Date.new(@year,@month,1)
    last = Date.new(@year,@month,-1)
    n = last.day 
    s = first.wday
    build_days_and_weeks(s,n)
  end
  
  #s(day of the week to start on zero(Sunday) - six(Saturday))
  #n(number of days in the month)
  def build_days_and_weeks(s,n)
    new_day = ''
    1.upto(n) do |day|
      new_day = Day.new(day,@number_of_weeks,s,@month,@year)
      if day == 1 || s == SUNDAY #first day of week
        @weeks << Week.new(new_day.date,s)
      end
      @weeks.last.add_day(new_day)
      if s == SATURDAY
        s = SUNDAY
        @weeks.last.end_date = new_day.date
        @number_of_weeks += 1
      else
        s += 1
      end
    end
    @weeks.last.end_date = new_day.date
  end
  
  def add_days_at_start_of_month(first_day)
    0.upto(first_day.day_of_week-1) {@days.first.unshift('X')}
  end
  
  def add_days_to_end_of_month(last_day)
    (last_day.day_of_week+1).upto(SATURDAY) {@days.last.push('X')}
  end
  
  def <<(event)
    @number_of_events += 1
    #You can use Caledar::Event for testing outside of rails
    @events << event
    #@events << Event.new(@number_of_events,event[:title],event[:start],event[:end])
  end
  
  def add_events(events)
    @events.concat(events)
  end
  
  def generate
    for event in @events
      for week in @weeks
        week << event if event.within?(week.start_date,week.end_date)
      end
    end
    for week in @weeks
      week.sort_events!
    end
  end
  
  def pp
    for week in @weeks
      #puts week.to_s
			puts "-" * 120
      for day in week.days
        row = %{#{day.day_of_month.to_s.rjust(2)} X }
        row += day.events.inject([]) do |acc,event|
          if event.nil?
            acc << "-" * 34
          else
            acc << "(#{event})"
          end 
          acc
        end.join(' X ')
        puts row
      end
    end
  end 
	
	def html_for_event
	  generate
	  
	  out = '<table style="width:100%" class="calendar">'
		height = 'height:20px;'
		style_one = 'background:#fff;color:#000;'
		style_two = 'background:#000;color:#fff;'
		out << %{<tr>}
		for day in Date::DAYNAMES
		  out << %{<th>#{day}</th>}
		end
		out << %{</tr>}
    for week in @weeks
		  out << %{<tr valign="top">}
			out << %{<td>&nbsp;</td>} * week.first_day_of_week
      for day in week.days
        out << %{<td>}
				out << %{<div style="#{height}">#{day.day_of_month}</div>}
				position_level = 0
        out << day.events.inject('') do |acc,event|
				  style = position_level % 2 == 0? style_one : style_two
          if event.nil?
            acc << %{<div style="#{style}" class="day">&nbsp;</div>}
          else
            acc <<  %{<div style="#{style}" class="day">#{yield(event)}</div>}
          end 
					position_level += 1
          acc
        end
				out << %{</td>}
      end
			out << %{</tr>}
    end
		out << %{</table>}
		@output = out
	end
	
	def to_s
	  @output
	end
  
  class Week
    
    attr_accessor :start_date, :end_date,:days,:first_day_of_week
    def initialize(s,dow)
      @start_date = s
			@first_day_of_week = dow
      @days = []
      @events = []
    end
    
    def <<(event)
      @events << event
      @events.last.nodoiw = event.days_within?(@start_date,@end_date)
    end
    
    def add_day(day)
      @days << day
    end
    
    def to_s
      events = @events.sort_by {|e| e.nodoiw }.reverse.map {|e| "#{e.id}x#{e.nodoiw}"}.join(' ')
      "Week(#{@start_date} - #{@end_date}:events#{events})"
    end
    
		#Could be made faster by just assigning to positions if pos is equal zero or position 
    def sort_events!
      position = 0
      @events.sort_by {|e| e.nodoiw }.reverse.each do |event|
				(0..position).each do |pos|
					if positions_for_days_are_available?(event,pos)
						assign_events_to_days(event,pos)
						break
					end
				end
        position += 1
      end
    end
		
		private
		
		  def assign_events_to_days(event,position)
			  @days.each do |day|
          day.add_event(event,position) if event.within?(day.date,day.date)
				end
      end
			
			def positions_for_days_are_available?(event,position)
			  for day in @days
				  if event.within?(day.date,day.date) && !day.position_is_available?(position)
					  return false
					end
				end
				
				return true
			end
  end
  
  class Day
    attr_reader :day_of_month,:week_of_month,:day_of_week,:year,:date
    attr_reader :events
    
    def initialize(n,w,d,m,y)
      @date = Date.new(y,m,n)
      @day_of_month = n
      @week_of_month = w
      @day_of_week = d
      @year = y
      @events = []
    end
    
    def add_event(event,position)
      @events[position] = event
    end
		
		def position_is_available?(position)
		  ! @events[position]
		end
    
    def to_s
      "Day(day#{@day_of_month}/#{@year}:dow#{@day_of_week}:wom#{@week_of_month}:events#{@events.size})"
    end
  end
  
  class Event
    attr_reader :id,:title,:start_date,:end_date
    attr_accessor :nodoiw
    
    def initialize(id,t,s,e)
      @id = id
      @title = t
      @start_date = Date.parse(s.to_s)
      @end_date = Date.parse(e.to_s)
    end
    
    def to_s
      "Event(#{@id}:#{@start_date} - #{@end_date})"
    end
    
    def within?(s,e)
      (@start_date <= e) && (@end_date >= s)
    end
    
    def days_within?(s,e)
      (s..e).inject(0) do |days,day| 
        days += 1 if within?(day,day)  
        days
      end
    end
  end
end
