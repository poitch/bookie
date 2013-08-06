class Transaction
    include DataMapper::Resource

    property :id, Serial
    property :payee, String, :length => 1024, :required => true
    property :description, String, :length => 1024
    property :category, String, :length => 1024
    property :amount, Integer
    property :transaction_date, DateTime
    property :post_date, DateTime
    property :reconciled, Boolean, :default => false
    property :created_at, DateTime

    belongs_to :account
    belongs_to :cycle

    # When we need to link this to a bill...
    belongs_to :bill, :model => Bill, :required => false, :index => :billI
    property :bill_cycle, DateTime, :required => false, :index => :billI

    before :save do |transaction|
        # Check that the category is valid
        if !transaction.category.nil?
            if 0 == Category.count(:name => transaction.category)
                transaction.errors.add(:category, "#{transaction.category} has not been defined")
                throw :halt
            end
        end

        true
    end

    def reconcile(post_date = nil)
        post_date = self.transaction_date if post_date.nil?
        self.post_date = post_date
        self.reconciled = true
        self.save
    end

    def amount_
        @ammount.to_f / 100.0
    end

    def to_h
        h = self.attributes
        h[:amount] = h[:amount].to_f / 100.0
        h
    end
end
