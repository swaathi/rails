require 'active_support/time_with_zone'
require 'active_support/core_ext/time/acts_like'
require 'active_support/core_ext/date_and_time/zones'

class Time
  include DateAndTime::Zones
  class << self
    attr_accessor :zone_default

    # Returns the TimeZone for the current request, if this has been set (via Time.zone=).
    # If <tt>Time.zone</tt> has not been set for the current request, returns the TimeZone specified in <tt>config.time_zone</tt>.
    def zone
      Thread.current[:time_zone] || zone_default
    end

    # Sets <tt>Time.zone</tt> to a TimeZone object for the current request/thread.
    #
    # This method accepts any of the following:
    #
    # * A Rails TimeZone object.
    # * An identifier for a Rails TimeZone object (e.g., "Eastern Time (US & Canada)", <tt>-5.hours</tt>).
    # * A TZInfo::Timezone object.
    # * An identifier for a TZInfo::Timezone object (e.g., "America/New_York").
    #
    # Here's an example of how you might set <tt>Time.zone</tt> on a per request basis and reset it when the request is done.
    # <tt>current_user.time_zone</tt> just needs to return a string identifying the user's preferred time zone:
    #
    #   class ApplicationController < ActionController::Base
    #     around_action :set_time_zone
    #
    #     def set_time_zone
    #       if logged_in?
    #         Time.use_zone(current_user.time_zone) { yield }
    #       else
    #         yield
    #       end
    #     end
    #   end
    def zone=(time_zone)
      Thread.current[:time_zone] = find_zone!(time_zone)
    end

    # Allows override of <tt>Time.zone</tt> locally inside supplied block;
    # resets <tt>Time.zone</tt> to existing value when done.
    #
    #   class ApplicationController < ActionController::Base
    #     around_action :set_time_zone
    #
    #     private
    #
    #     def set_time_zone
    #       Time.use_zone(current_user.timezone) { yield }
    #     end
    #   end
    #
    #  NOTE: This won't affect any <tt>ActiveSupport::TimeWithZone</tt>
    #  objects that have already been created, e.g. any model timestamp
    #  attributes that have been read before the block will remain in
    #  the application's default timezone.
    def use_zone(time_zone)
      new_zone = find_zone!(time_zone)
      begin
        old_zone, ::Time.zone = ::Time.zone, new_zone
        yield
      ensure
        ::Time.zone = old_zone
      end
    end

    # Returns a TimeZone instance matching the time zone provided.
    # Accepts the time zone in any format supported by <tt>Time.zone=</tt>.
    # Raises an +ArgumentError+ for invalid time zones.
    #
    #   Time.find_zone! "America/New_York" # => #<ActiveSupport::TimeZone @name="America/New_York" ...>
    #   Time.find_zone! "EST"              # => #<ActiveSupport::TimeZone @name="EST" ...>
    #   Time.find_zone! -5.hours           # => #<ActiveSupport::TimeZone @name="Bogota" ...>
    #   Time.find_zone! nil                # => nil
    #   Time.find_zone! false              # => false
    #   Time.find_zone! "NOT-A-TIMEZONE"   # => ArgumentError: Invalid Timezone: NOT-A-TIMEZONE
    def find_zone!(time_zone)
      if !time_zone || time_zone.is_a?(ActiveSupport::TimeZone)
        time_zone
      else
        # Look up the timezone based on the identifier (unless we've been
        # passed a TZInfo::Timezone)
        unless time_zone.respond_to?(:period_for_local)
          time_zone = ActiveSupport::TimeZone[time_zone] || TZInfo::Timezone.get(time_zone)
        end

        # Return if a TimeZone instance, or wrap in a TimeZone instance if a TZInfo::Timezone
        if time_zone.is_a?(ActiveSupport::TimeZone)
          time_zone
        else
          ActiveSupport::TimeZone.create(time_zone.name, nil, time_zone)
        end
      end
    rescue TZInfo::InvalidTimezoneIdentifier
      raise ArgumentError, "Invalid Timezone: #{time_zone}"
    end

    # Returns a TimeZone instance matching the time zone provided.
    # Accepts the time zone in any format supported by <tt>Time.zone=</tt>.
    # Returns +nil+ for invalid time zones.
    #
    #   Time.find_zone "America/New_York" # => #<ActiveSupport::TimeZone @name="America/New_York" ...>
    #   Time.find_zone "NOT-A-TIMEZONE"   # => nil
    def find_zone(time_zone)
      find_zone!(time_zone) rescue nil
    end

    # Returns an offset time when provided with an offset value.
    # Accepts offset values of format,
  	# (+|-)(0-1)(1-12):(0-5)(0-9)
    # Returns the same time for invalid offset values.
    #
  	# Example,
  	# t = Time.now.utc
  	# => Fri, 23 Jul 2016 07:56:38 UTC +00:00
  	# t.offset("+05:30")
  	# => Fri, 23 Jul 2016 13:26:38 UTC +00:00
    def offset(offset_value)
      if match = offset_value.match(/^(?:Z|([+-])((?:2[0-3]|[01][0-9])):([0-5][0-9]))$/)
          set, hour, minute = match.captures
        return self.send(set, hour.to_i.hour).send(set, minute.to_i.minute)
      else
        return self
      end
    end
  end
end
