class Account
    include DataMapper::Resource

    property :id, Serial
    property :name, String, :length => 1024
    property :type, Enum[:cc, :saving, :checking, :misc], :default => :checking
    property :created_at, DateTime

    has n, :transactions
    has n, :cycles
    has n, :bills

    def self.g(account)
        if Bookie::Helpers::is_numeric?(account)
            account = Account.get(account)
        else
            account = Account.all(:name.like => "%#{account}%")
            if account.size > 1 || account.nil? || account.size == 0
                return nil
            end
            account = account.first
        end

        return account
    end

    def self.c(name, type, opening_balance, opening_date = nil)
        a = Account.create(
            :name => name,
            :type => type,
            :created_at => Time.now,
        )
        a.new_cycle(opening_balance, opening_date)
        a
    end

    def current_cycle
        Cycle.last(:account => self)
    end

    def new_cycle(opening_balance = 0, opening_date = nil)
        previous = self.current_cycle
        if !previous.nil?
            previous.end_date = opening_date
            previous.end_amount = ((opening_balance.to_f * 1000.0).to_i)/10
            previous.save
        end

        c = Cycle.create(
            :start_date => opening_date.nil? ? Time.now : opening_date,
            :start_amount => ((opening_balance.to_f * 1000.0).to_i)/10,
            :created_at => Time.now,
            :account => self
        )
    end

    def new_transaction(payee, amount, transaction_date = nil, description = nil, category = nil)
        transaction_date = transaction_date.nil? ? Time.now : transaction_date
        if category.nil?
            # Let's see if we can figure it out
            t = Transaction.last(:payee => payee, :account => self)
            category = t.category if !t.nil?
        end
        if !category.nil? && category.empty?
            category = nil
        end

        Transaction.create(
            :payee => payee,
            :description => description,
            :category => category,
            :amount => ((amount.to_f * 1000.0).to_i)/10,
            :transaction_date => transaction_date,
            :created_at => Time.now,
            :account => self,
            :cycle => current_cycle
        )
    end

    def autobill(days)
        # We need to go through all of the bills for this account
        u = Time.now + (days*24*60*60)
        Bill.all(:account => self).each do |bill|
            r = bill.recurrence
            r.events(:until => u.strftime('%Y-%m-%d')).each do |event|
                puts "#{bill.id} #{event}"
                # Do we have the transaction for this?
                transaction = Transaction.first(
                    :account => self,
                    :bill => bill,
                    :bill_cycle => event,
                )
                if transaction.nil?
                    puts "\tNeed to create auto-bill"
                    transaction = self.new_transaction(
                        bill.payee,
                        bill.amount.to_f / 100.0,
                        event,
                        bill.description,
                        bill.category
                    )
                    puts "\tCreated transaction #{transaction.id}"
                    transaction.bill = bill
                    transaction.bill_cycle = event
                    transaction.save
                    puts "\tMarked #{transaction.id} as auto-bill #{bill.id} #{event}"
                else
                    puts "\tFound auto-bill #{transaction.id}"
                end
            end
        end
    end

    def to_h 
        self.attributes
    end
end
