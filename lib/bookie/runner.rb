# encoding: utf-8
require 'boson/runner'
require 'hirb'
require 'terminfo'
require 'chronic'
require 'rainbow'
require 'recurrence'

require_relative '../../models/init'
require_relative 'formatters'
require_relative 'helpers'

module Bookie
    class Runner < Boson::Runner

        desc "List accounts"
        def accounts
            accounts = []
            Account.all.each do |a|
                accounts << a.to_h
            end
            puts Hirb::Helpers::Table.render(
                accounts, 
                fields: [:id, :name, :type],
                headers: {:name => 'Name',
                          :type => 'Type'},

                filters: {:type => :to_type},
                description: false,
            )
        end

        desc "Create an account"
        def create_account(name, type, opening_balance = 0, opening_date = nil)
            puts "Creating account #{name} of type #{type}"

            if type.downcase == 'cc'
                # Make sure we have opening balance and opening date
                if opening_balance.nil? || opening_date.nil?
                    failure("Opening balance and date are required for Credit Cards")
                    return
                end
            end

            a = Account.c(name, type.downcase, opening_balance, Chronic.parse(opening_date))
            if a.saved?
                success("Created account #{a.id} with name #{a.name} of type #{a.type}")
            else
                failure("Failed to create account #{name}")
                a.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            end
        end

        desc "List transactions for an account"
        def transactions(account)
            sizes = TermInfo.screen_size # [lines, columns]
            act = Account.g(account)
            if act.nil?
                puts "account #{account} not found"
                return
            end

            transactions = []
            cycle = act.current_cycle
            # TODO we should be able to go to the previous cycle
            # TODO ordering by either post_date or transaction_date

            #order = [:post_date.desc, :transaction_date.asc]
            order = [:transaction_date.asc, :post_date.desc]
            print_transactions(cycle.transactions(:order => order), true, cycle.start_amount)
        end

        desc "Add a transaction to an account"
        def add_transaction(account,
                            payee,
                            amount,
                            transaction_date = nil,
                            description = nil,
                            category = nil,
                            post_date = nil)
            act = Account.g(account)
            if act.nil?
                failure("Account #{account} not found")
                return
            end

            t = act.new_transaction(payee,
                                    amount,
                                    Chronic.parse(transaction_date),
                                    description,
                                    category)
            if !t.saved?
                failure("Failed to create transaction")
                t.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            else
                if !post_date.nil?
                    t.reconcile(post_date)
                    success("Transaction #{t.id} created and reconciled")
                else
                    success("Transaction #{t.id} created")
                end
            end
        end

        desc "Reconcile a transaction"
        def reconcile(transaction_id, post_date = nil)
            # Do we have commas in transaction_id?
            ids = transaction_id.split(',')
            ids.each do |id|
                t = Transaction.get(id)
                if t.nil?
                    failure("Could not find transaction #{id}")
                    return
                end

                if t.reconcile(Chronic.parse(post_date))
                    success("#{t.id} #{t.payee} #{t.amount_} reconciled on #{t.post_date}")
                else
                    failure("Failed to create transaction")
                    t.errors.to_h.each do |k,v|
                        puts "\t#{k}: #{v.join(', ')}"
                    end
                end
            end
       end

        desc "Delete a transaction"
        def delete_transaction(transaction_id)
            remove_transaction(transaction_id)
        end

        desc "Remove a transaction"
        def remove_transaction(transaction_id)
            t = Transaction.get(transaction_id)
            if t.nil?
                failure("Could not find transaction #{transaction_id}")
                return
            end

            t.destroy!
            success("Transaction #{transaction_id} removed")
        end

        desc "Edit transaction"
        def update_transaction(transaction_id, key, value)
            edit_transaction(transaction_id, key, value)
        end

        desc "Edit transaction"
        def edit_transaction(transaction_id, key, value)
            t = Transaction.get(transaction_id)
            if t.nil?
                failure("Could not find transaction #{transaction_id}")
                return
            end

            prev_value = t.attributes[key.to_sym]
            value_str = value
            if key == 'amount'
                value = (value.to_f * 1000).to_i/10
            elsif key == 'transaction_date' || key == 'post_date'
                value = Chronic.parse(value)
                prev_value = prev_value.strftime('%Y-%m-%d')
                value_str = value.strftime('%Y-%m-%d')
            end

            if !t.update(key => value)
                failure("Failed to update transaction")
                t.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            else
                success("Updated #{key} of #{t.id} from #{prev_value} to #{value_str}")
            end
        end

        def search_transaction(account, payee, amount = nil)
            act = Account.g(account)
            if act.nil?
                puts "account #{account} not found"
                return
            end


            filter = {
                :account => act,
                :payee.like => "%#{payee}%",
            }
            if !amount.nil?
                filter[:amount] = (amount.to_f * 1000.0).to_i/10
            end
            print_transactions(Transaction.all(filter))
        end

        desc "Create a new category"
        def add_category(category)
            c = Category.create(
                :name => category,
                :created_at => Time.now,
            )
            if !c.saved?
                failure("Could not create category #{category}")
                c.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            else
                success("Category #{category} created")

            end
        end

        def categories
            categories = []
            Category.all(:order => [:name.asc]).each do |c|
                categories << c.to_h
            end
            puts Hirb::Helpers::Table.render(
                categories,
                fields: [:id, :name],
                headers: {:name => 'Name',
                },
                description: false,
            )
        end


        def new_cycle(account, opening_balance, opening_date)
            act = Account.g(account)
            if act.nil?
                failure("Account #{account} not found")
                return
            end

            cycle = act.new_cycle(opening_balance, Chronic.parse(opening_date))
            if cycle.saved?
                success("New cycle created #{cycle.id}")
            else
                failure("Failed to create cycle")
                cycle.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            end
        end

        def add_bill(account, payee, amount, category, recurrence)
            # Need to somehow parse the recurrence into a valid option
            act = Account.g(account)
            if act.nil?
                failure("Account #{account} not found")
                return
            end

            b = Bill.g(act, payee, amount, category, recurrence)
            if b.saved?
                success("Created bill #{b.id}")
            else
                failure("Failed to create bill")
                b.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            end

        end

        def bills(account)
            # Need to somehow parse the recurrence into a valid option
            act = Account.g(account)
            if act.nil?
                failure("Account #{account} not found")
                return
            end

            sizes = TermInfo.screen_size # [lines, columns]
            bills = []
            Bill.all(:account => act).each do |bill|
                bills << bill.to_h
            end
            puts Hirb::Helpers::Table.render(bills,
                :max_width => sizes[1],
                :fields => [:id, :payee, :category, :amount, :repeat],
                :headers => {
                    :amount => 'Amount',
                    :payee => 'Payee',
                    :category => 'Category',
                    :repeat => 'Repeat',
                },
                :filters => {
                    :amount => :to_dollars,
                    :repeat => :to_every,
                    },
                :description => false,
            )
        end

        def delete_bill(bill_id)
            remove_bill(bill_id)
        end

        def remove_bill(bill_id)
            b = Bill.get(bill_id)
            if b.nil?
                failure("Could not find bill #{bill_id}")
                return
            end

            b.destroy!
            success("Bill #{bill_id} removed")
        end

        def autobill(account)
            act = Account.g(account)
            if act.nil?
                failure("Account #{account} not found")
                return
            end
            act.autobill(2*7) # 2 weeks
        end

        def edit_bill(bill_id, key, value)
            update_bill(bill_id, key, value)
        end

        def update_bill(bill_id, key, value)
            b = Bill.get(bill_id)
            if b.nil?
                failure("Could not find bill #{bill_id}")
                return
            end

            prev_value = b.attributes[key.to_sym]
            value_str = value
            if key == 'amount'
                value = (value.to_f * 1000).to_i/10
            end

            if !b.update(key => value)
                failure("Failed to update bill")
                b.errors.to_h.each do |k,v|
                    puts "\t#{k}: #{v.join(', ')}"
                end
            else
                success("Updated #{key} of #{b.id} from #{prev_value} to #{value_str}")
            end
        end

        def transfer(from, to, amount)
            f = Account.g(from)
            if f.nil?
                failure("Account #{from} not found")
                return
            end
            t = Account.g(to)
            if t.nil?
                failure("Account #{to} not found")
                return
            end

            Transfer.transfer(from, to, amount)
        end

        private
        def print_transactions(ts, sums = false, current = 0)
            sizes = TermInfo.screen_size # [lines, columns]

            transactions = []
            balance = 0
            reconciled = 0

            ts.each do |t|
                s = t.to_h
                balance += (s[:amount] * 100).to_i
                current += (s[:amount] * 100).to_i
                s[:balance] = (balance.to_f / 100.0)
                s[:current] = (current.to_f / 100.0)
                if s[:reconciled]
                    reconciled += (s[:amount] * 100).to_i
                    s[:reconciled_balance] = (reconciled.to_f / 100.0)
                end

                transactions << s
            end
            transactions.reverse!

            columns = [:id,
                    :payee,
                    :category,
                    :amount,
                    :transaction_date,
                    :post_date,
            ]

            if sizes[1] > 170
                columns << :description
            end

            if sums
                columns << :balance
                columns << :current
                columns << :reconciled_balance
            end

            puts Hirb::Helpers::Table.render(
                transactions,
                :max_width => sizes[1],
                :fields => columns,
                :headers => {:payee => "Payee",
                          :description => "Description",
                          :category => "Category",
                          :amount => "Amount",
                          :transaction_date => "Transaction Date",
                          :post_date => "Post Date",
                          :reconciled => "Reconciled",
                          :balance => "Balance",
                          :reconciled_balance => "Reconciled",
                          :current => "Current",

                },
                :filters => {:amount => :to_dollars,
                          :transaction_date => :to_day,
                          :post_date => :to_day,
                          :reconciled => :to_cb,
                          :balance => :to_dollars,
                          :reconciled_balance => :to_dollars,
                          :current => :to_dollars,
                },
                :description => false,
            )

        end

        def success(msg)
            puts "✓".color(:green) + " #{msg}"
        end

        def failure(msg)
            puts "✗".color(:red) + " #{msg}"
        end

    end
end
