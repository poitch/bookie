require 'recurrence'

class Bill
    include DataMapper::Resource

    property :id, Serial

    property :repeat, String, :length => 1024

    # Should track the transaction model
    property :payee, String, :length => 1024, :required => true
    property :description, String, :length => 1024
    property :category, String, :length => 1024
    property :amount, Integer
 
    property :created_at, DateTime

    belongs_to :account

    before :save do |bill|
        # Check that the category is valid
        if !bill.category.nil?
            if 0 == Category.count(:name => bill.category)
                bill.errors.add(:category, "#{bill.category} has not been defined")
                throw :halt
            end
        end
    end

    def self.g(account, payee, amount, category, repeat)
        category = nil if category.empty?
        Bill.create(
            :repeat => Bill.parse(repeat).to_json,
            :payee => payee,
            :category => category,
            :amount => (amount.to_f * 1000.0).to_i/10,
            :account => account,
        )
    end

    def recurrence
        opts = {}
        JSON.parse(@repeat).each do |k,v|
            if Bookie::Helpers::is_numeric?(v)
                opts[k.to_sym] = v.to_i
            elsif v.is_a? Array
                opts[k.to_sym] = v
            else
                opts[k.to_sym] = v.to_sym
            end
        end
        Recurrence.new(opts)
    end

    def self.parse(recurrence)
        opts = {}
        if recurrence.start_with?('every')
            parts = recurrence.match(/^every (week|month|year) on ([A-Za-z0-9,]+)/)

            if parts[1] == 'week'
                opts[:every] = :week
            elsif parts[1] == 'month'
                opts[:every] = :month
            elsif parts[1] == 'year'
                opts[:every] = :year
            end

            # Do we have commas in parts[2] the on part
            ons = []
            parts[2].split(/,/).each do |o|
                if Bookie::Helpers::is_numeric?(o)
                    ons << o.to_i
                else
                    ons << o.to_sym
                end
            end
            if ons.size == 1
                opts[:on] = ons[0]
            else
                opts[:on] = ons
            end

            # If monthly and on is a symbol then we'll need an interval
            if opts[:every] == :month && !(ons[0].is_a? Fixnum)
                subs = recurrence.match(/^every (week|month|year) on ([A-Za-z0-9].+) weekday ([A-Za-z0-9]+)/)
                if subs
                    opts[:weekday] = subs[3].to_sym
                else
                    raise "Missing weekday for a month recurrence not on a specific date"
                end
            end

            if m = recurrence.match(/interval ([A-Za-z0-9]+)/)
                if Bookie::Helpers::is_numeric?(m[1])
                    opts[:interval] = m[1].to_i
                else
                    opts[:interval] = m[1].to_sym
                end
            end

            puts "opts = #{opts}"

            # Create the object first to make sure it's all valid
            r = Recurrence.new(opts)
            r.options
        else
            raise "Cannot parse #{recurrence}"
        end
    end

    def to_h
        h = self.attributes
        h[:amount] = h[:amount].to_f / 100.0
        h
    end
end
