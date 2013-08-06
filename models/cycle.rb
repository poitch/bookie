class Cycle
    include DataMapper::Resource
    property :id, Serial

    property :start_date, DateTime
    property :start_amount, Integer
    property :end_date, DateTime
    property :end_amount, Integer
    property :created_at, DateTime

    belongs_to :account
    has n, :transactions
end
