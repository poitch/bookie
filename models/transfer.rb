class Transfer
    include DataMapper::Resource

    property :id, Serial

    belongs_to :from, :model => Transaction
    belongs_to :to, :model => Transaction

    property :amount, Integer
    property :created_at, DateTime

    def self.transfer(from, to, amount, transaction_date = nil)
        # Create 2 transactions
        from_t = from.new_transaction(to.name,
                                      amount,
                                     transaction_date)
        to_t to.new_transaction(from.name,
                                amount,
                                transaction_date)
        t = Transfer.create(
            :from => from,
            :to => to,
            :amount => amount)

        if !t.saved?
            #  We need to raise that
        end

    end
end
