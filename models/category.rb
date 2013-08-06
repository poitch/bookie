class Category
    include DataMapper::Resource

    property :id, Serial
    property :name, String, :unique => true, :length => 1024
    property :created_at, DateTime

    def to_h
        self.attributes
    end
end
