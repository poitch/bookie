# encoding: utf-8
module Hirb::Helpers::Table::Filters
    def to_dollars(amount)
        if amount
            amount = amount.to_f
            if amount < 0
                sprintf('($%0.2f)',0-amount).gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
            else
                sprintf('$%0.2f',amount).gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
            end
        end
    end

    def to_type(t)
        return t if t.nil?

        if t == :cc
            return 'Credit Card'
        elsif t == :checking
            return 'Checking'
        elsif t == :saving
            return 'Saving'
        else
            return t
        end
    end

    def to_day(d)
        d.strftime('%Y-%m-%d') if !d.nil?
    end

    def to_cb(b)
        if !b.nil?
            b ? '✓' : ''
        end
    end

    def to_percent(value)
        if value
            "#{(100.0 * value).round(1)}%"
        end
    end

    def to_every(opts_str)
        opts = JSON.parse(opts_str)
        opts.flatten.join(' ')
    end

end

