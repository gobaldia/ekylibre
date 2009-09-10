class AccountancyController < ApplicationController
  include ActionView::Helpers::FormOptionsHelper
  
  dyta(:journals, :conditions=>{:company_id=>['@current_company.id']}, :default_order=>:code) do |t|
    t.column :name
    t.column :code
    t.column :name, :through=>:currency
    t.column :closed_on
    t.action :journal_close, :if => 'RECORD.closable?(Date.today)'
   # t.action :entries_consult, :image=>:table
    t.action :journal_update, :image=>:update
    t.action :journal_delete, :method=>:post, :image=>:delete, :confirm=>:are_you_sure
  end
  
  dyta(:accounts, :conditions=>{:company_id=>['@current_company.id']}, :default_order=>"number ASC") do |t|
    t.column :number
    t.column :name
    t.action :account_update, :image=>:update
    t.action :account_delete, :image=>:delete, :method=>:post, :confirm=>:are_you_sure
  end
  
  dyta(:bank_accounts, :conditions=>{:company_id=>['@current_company.id']}, :default_order=>:name) do |t|
    t.column :name
    t.column :iban_label
    t.column :name, :through=>:journal
    t.column :name, :through=>:currency
    t.column :number, :through=>:account
    t.action :bank_account_update, :image=>:update
    t.action :bank_account_delete, :method=>:post, :image=>:delete, :confirm=>:are_you_sure
  end
  
  dyta(:bank_account_statements, :conditions=>{:company_id=>['@current_company.id']}, :default_order=>"started_on ASC") do |t|
    t.column :started_on
    t.column :stopped_on
    t.column :number
    t.action :bank_account_statement, :image=>:show
    t.action :bank_account_statement_update, :image=>:update
    t.action :bank_account_statement_delete, :method=>:post, :image=>:delete, :confirm=>:are_you_sure
  end
  
  #
  def self.entries_conditions_statements(options={})
    code = ""
    code += "conditions = ['entries.company_id=?', @current_company.id] \n"

    code += "unless session[:statement].blank? \n"
    code += "statement = @current_company.bank_account_statements.find(:first, :conditions=>{:id=>session[:statement]})\n"
    code += "conditions[0] += ' AND statement_id = ? '\n"
    code += "conditions << statement.id \n"
    code += "end \n"
    code += "conditions \n"
    code
  end

  dyta(:entries_statement, :model =>:entries, :conditions=>entries_conditions_statements, :default_order=>:record_id) do |t|
    t.column :number, :label=>"Numéro", :through=>:record
    t.column :created_on, :label=>"Crée le", :through=>:record, :datatype=>:date
    t.column :printed_on, :label=>"Saisie le", :through=>:record, :datatype=>:date
    t.column :name
    t.column :number, :label=>"Compte", :through=>:account
    t.column :debit
    t.column :credit
  end


 #
  def self.entries_conditions_journal_consult(options={})
    code = ""
    code += "conditions=['entries.company_id=?', @current_company.id.to_s] \n"
    code += "unless session[:journal_record][:journal_id].blank? \n" 
    code += "journal=@current_company.journals.find(:first, :conditions=>{:id=>session[:journal_record][:journal_id]})\n" 
    code += "if journal\n"
    code += "conditions[0] += 'AND r.journal_id=?'\n"
    code += "conditions << journal.id \n"
    code += "end \n"
    code+="end\n"
    
    code +="unless session[:journal_record][:financialyear_id].blank? \n"
    code += "financialyear = @current_company.financialyears.find(:first, :conditions=>{:id=>session[:journal_record][:financialyear_id]}) \n"
    code += "if financialyear \n"
    code += "conditions[0] += ' AND r.financialyear_id=?' \n"
    code += "conditions << financialyear.id \n"
    code += "end \n"
    code+="end\n"
    code += "conditions \n"
 
    code
  end


  dyta(:entries, :conditions=>entries_conditions_journal_consult, :default_order=>:record_id, :joins=>"INNER JOIN journal_records r ON r.id = entries.record_id") do |t|
    t.column :number, :label=>"Numéro", :through=>:record
    t.column :created_on, :label=>"Crée le", :through=>:record, :datatype=>:date
    t.column :printed_on, :label=>"Saisie le", :through=>:record, :datatype=>:date
    t.column :name
    t.column :number, :label=>"Compte" , :through=>:account
    t.column :debit
    t.column :credit
    t.action :entry_update, :image => :update, :if => '!RECORD.close?'  
    t.action :entry_delete, :image => :delete,  :method => :post, :confirm=>:are_you_sure, :if => '!RECORD.close?'
  end
  
  dyta(:financialyears, :conditions=>{:company_id=>['@current_company.id']}, :default_order=>:started_on) do |t|
    t.column :code
    t.column :closed
    t.column :started_on
    t.column :stopped_on
    t.action :financialyear_close, :if => '!RECORD.closed and RECORD.closable?'
   # t.action :entries_consult, :image => :table
    t.action :financialyear_update, :image => :update, :if => '!RECORD.closed'  
    t.action :financialyear_delete, :method => :post, :image =>:delete, :confirm=>:are_you_sure, :if => '!RECORD.closed'  
  end

  dyli(:account, [:number, :name], :conditions => {:company_id=>['@current_company.id']})
 
 
  # 
  def index
    @entries = @current_company.entries
  end

  # lists all the bank_accounts with the mainly characteristics. 
  def bank_accounts
  end

  # this method creates a bank_account with a form.
  def bank_account_create
    if request.post? 
      @bank_account = BankAccount.new(params[:bank_account])
      @bank_account.company_id = @current_company.id
      @bank_account.entity_id = session[:entity_id] 
      redirect_to_back if @bank_account.save
    else
      @bank_account = BankAccount.new
      session[:entity_id] = params[:entity_id]||@current_company.entity_id
      @valid_account = @current_company.accounts.empty?
      @valid_journal = @current_company.journals.empty?  
    end
    render_form
  end

  # this method updates a bank_account with a form.
  def bank_account_update
    @bank_account = BankAccount.find_by_id_and_company_id(params[:id], @current_company.id)  
    if request.post? or request.put?
      if @bank_account.update_attributes(params[:bank_account])
        redirect_to :action => "bank_accounts"
      end
    end
    render_form
  end
  
  # this method deletes a bank_account.
  def bank_account_delete
    if request.post? or request.delete?
      @bank_account = BankAccount.find_by_id_and_company_id(params[:id], @current_company.id)  
      if @bank_account.statements.size > 0
        @bank_account.update_attribute(:deleted, true)
      else
        BankAccount.destroy @bank_account
      end
    end
    redirect_to :action => "bank_accounts"
  end


  # lists all the accounts with the credit, the debit and the balance for each of them.
  def accounts
  
  end
 
  
  # this action creates an account with a form.
  def account_create
    if request.post?
      @account = Account.new(params[:account])
      @account.company_id = @current_company.id
      redirect_to_back if @account.save
    else
      @account = Account.new
    end
    render_form
  end

  # this action updates an existing account with a form.
  def account_update
    @account = Account.find_by_id_and_company_id(params[:id], @current_company.id)  
    if request.post? or request.put?
      params[:account].delete :number
      redirect_to_back if @account.update_attributes(params[:account])
    end
    @title = {:value=>@account.label}
    render_form
  end


  # this action deletes or hides an existing account.
  def account_delete
    if request.post? or request.delete?
      @account = Account.find_by_id_and_company_id(params[:id], @current_company.id)  
      unless @account.entries.size > 0 or @account.balances.size > 0
        Account.destroy(@account.id) 
      end
    end
    redirect_to_current
  end
  
  PRINTS=[[:balance, {:partial=>"balance"}],
          [:general_ledger, {:partial=>"ledger"}],
          [:journal_by_id, {:partial=>"journal"}],
          [:journal, {:partial=>"journals"}],
          [:synthesis, {:partial=>"synthesis"}]]

  # this method prepares the print of document.
  def document_prepare
    @prints = PRINTS
    if request.post?
      session[:mode] = params[:print][:mode]
      redirect_to :action=>:document_print
    end
  end
  
  #  this method prints the document
  def document_print
    for print in PRINTS
      @print = print if print[0].to_s == session[:mode]
    end
    @financialyears =  @current_company.financialyears.find(:all, :order => :stopped_on)
    if @financialyears.nil?
      flash[:message]=tc(:no_financialyear)
      redirect_to :action => :document_prepare
      return      
    end
      
    @partial = 'print_'+@print[1][:partial]
    started_on = Date.today.year.to_s+"-"+"01-01"
    stopped_on = Date.today.year.to_s+"-12-31"
    
    if request.post? 
      lines = []
      if @current_company.default_contact
        lines =  @current_company.default_contact.address.split(",").collect{ |x| x.strip}
        lines << @current_company.default_contact.phone if !@current_company.default_contact.phone.nil?
        lines << @current_company.code
      end
       
      sum = {:debit=> 0, :credit=> 0, :balance=> 0}
      
      if session[:mode] == "journal"
        entries = Journal.records(@current_company.id,  params[:printed][:from],  params[:printed][:to])

        if entries.size > 0
          entries.each do |entry|
            sum[:debit] += entry.debit
            sum[:credit] += entry.credit
          end
          sum[:balance] = sum[:debit] - sum[:credit]
        end
        
        journal_template = @current_company.document_templates.find(:first, :conditions =>{:name => "Journaux"})
        if journal_template.nil?
          flash[:message]=tc(:no_template_journal)
          redirect_to :action=>:document_print
          return
        end
        
        pdf = journal_template.print(@current_company,  params[:printed][:from],  params[:printed][:to], entries, sum)
        
        send_data pdf, :type=>:pdf
      end
      
      if session[:mode] == "journal_by_id"
        journal = Journal.find_by_id_and_company_id(params[:printed][:name], @current_company.id)
        id = @current_company.journals.find(:first, :conditions => {:name => journal.name }).id
        entries = Journal.records(@current_company.id,  params[:printed][:from],  params[:printed][:to], id)
        if entries.size > 0
          entries.each do |entry|
            sum[:debit] += entry.debit
            sum[:credit] += entry.credit
          end
          sum[:balance] = sum[:debit] - sum[:credit]
        end

        journal_template = @current_company.document_templates.find(:first, :conditions =>{:name => "Journal"})
     
         if journal_template.nil?
           flash[:message]=tc(:no_template_journal_by_id, :value=>journal.name)
           redirect_to :action=>:document_print
           return
         end
        
        pdf = journal_template.print(journal,  params[:printed][:from],  params[:printed][:to], entries, sum)
        
        send_data pdf, :type=>:pdf
        
      end
      
      if session[:mode] == "balance"
        accounts_balance = Account.balance(@current_company.id, params[:printed][:from], params[:printed][:to])
        accounts_balance.delete_if {|account| account[:credit].zero? and account[:debit].zero?}
        for account in accounts_balance
          sum[:debit] += account[:debit]
          sum[:credit] += account[:credit]
        end
        sum[:balance] = sum[:debit] - sum[:credit]
     
        balance_template = @current_company.document_templates.find(:first, :conditions =>{:name => "Balance comptabilité"})
        if balance_template.nil?
          flash[:message]=tc(:no_balance)
          redirect_to :action=>:balance
          return
        end
        
        pdf = balance_template.print(@current_company, accounts_balance,  params[:printed][:from],  params[:printed][:to], sum)
        File.open('tmp/balance.pdf', 'wb') do |f|
          f.write(pdf)
        end
      
      end

      if session[:mode] == "synthesis"
        @financialyear = Financialyear.find_by_id_and_company_id(params[:printed][:financialyear], @current_company.id)
        params[:printed][:name] = @financialyear.code
        params[:printed][:from] = @financialyear.started_on
        params[:printed][:to] = @financialyear.stopped_on
        @balance = Account.balance(@current_company.id, @financialyear.started_on, @financialyear.stopped_on)
        
        @balance.each do |account| 
          sum[:credit] += account[:credit] 
          sum[:debit] += account[:debit] 
        end
        sum[:balance] = sum[:debit] - sum[:credit]     
        
        @last_financialyear = @financialyear.previous(@current_company.id)
        
        if not @last_financialyear.nil?
          index = 0
          @previous_balance = Account.balance(@current_company.id, @last_financialyear.started_on, @last_financialyear.stopped_on)
          @previous_balance.each do |balance|
            @balance[index][:previous_debit]   = balance[:debit]
            @balance[index][:previous_credit]  = balance[:credit]
            @balance[index][:previous_balance] = balance[:balance]
            index+=1
          end
          session[:previous_financialyear] = true
        end

        session[:lines] = @lines
        session[:printed] = params[:printed]
        session[:balance] = @balance
        
        redirect_to :action => :synthesis
      end
      
      if session[:mode] == "general_ledger"
       #  ledger = Account.ledger(@current_company.id, params[:printed][:from], params[:printed][:to])
       
#         ledger_template = @current_company.document_templates.find(:first, :conditions =>{:name => "Grand livre comptabilité"})
#         pdf = ledger_template.print(@current_company, ledger,  params[:printed][:from],  params[:printed][:to], sum)
#         File.open('tmp/ledger.pdf', 'wb') do |f|
#           f.write(pdf)
#         end
           
      end
      
    end

      @title = {:value=>t("views.#{self.controller_name}.document_prepare.#{@print[0].to_s}")}
  end
  
  # this method displays the income statement and the balance sheet.
  def synthesis
    @lines = session[:lines]
    @printed = session[:printed]
    @balance = session[:balance]
    @result = 0
    @solde = 0
    if session[:previous_financialyear] == true
      @previous_solde = 0
      @previous_result = 0
    end
    @active_fixed_sum = 0
    @active_current_sum = 0
    @passive_capital_sum = 0
    @passive_stock_sum = 0
    @passive_debt_sum = 0
    @previous_active_fixed_sum = 0
    @previous_active_current_sum = 0
    @previous_passive_capital_sum = 0
    @previous_passive_stock_sum = 0
    @previous_passive_debt_sum = 0
    @cost_sum = 0
    @finished_sum =  0
    @previous_active_sum = 0
    @previous_passive_sum = 0
    @previous_cost_sum = 0
    @previous_finished_sum = 0
      
    @balance.each do |account|
      @solde += account[:balance]
      @result = account[:balance] if account[:number].to_s.match /^12/
      @active_fixed_sum += account[:balance] if account[:number].to_s.match /^(20|21|22|23|26|27)/
      @active_current_sum += account[:balance] if account[:number].to_s.match /^(3|4|5)/ and account[:balance] >= 0
      @passive_capital_sum += account[:balance] if account[:number].to_s.match /^(1[^5])/
      @passive_stock_sum += account[:balance] if account[:number].to_s.match /^15/ 
      @passive_debt_sum += account[:balance] if account[:number].to_s.match /^4/
      @cost_sum += account[:balance] if account[:number].to_s.match /^6/
      @finished_sum += account[:balance] if account[:number].to_s.match /^7/
      if session[:previous_financialyear] == true
        @previous_solde += account[:previous_balance]
        @previous_result = account[:previous_balance] if account[:number].to_s.match /^12/
        @previous_active_fixed_sum += account[:previous_balance] if account[:number].to_s.match /^(20|21|22|23|26|27)/
        @previous_active_current_sum += account[:previous_balance] if account[:number].to_s.match /^(3|4|5)/ and account[:balance] >= 0
        @previous_passive_capital_sum += account[:previous_balance] if account[:number].to_s.match /^(1[^5])/
        @previous_passive_stock_sum += account[:previous_balance] if account[:number].to_s.match /^15/ 
        @previous_passive_debt_sum += account[:previous_balance] if account[:number].to_s.match /^4/
        @previous_cost_sum += account[:previous_balance] if account[:number].to_s.match /^6/
        @previous_finished_sum += account[:previous_balance] if account[:number].to_s.match /^7/
      end
    end

    @title = {:value=>"la période du "+@printed[:from].to_s+"au "+@printed[:to].to_s}
  end

  # this method orders sale.
  #def order_sale
   # render(:xil=>"#{RAILS_ROOT}/app/views/prints/sale_order.xml",:key=>params[:id])
  #end
 
  # lists all the bank_accounts with the mainly characteristics. 
  def financialyears
  end
  
  # this action creates a financialyear with a form.
  def financialyear_create
    if request.post? 
      @financialyear = Financialyear.new(params[:financialyear])
      @financialyear.company_id = @current_company.id
      redirect_to_back if @financialyear.save
    else
      @financialyear = Financialyear.new
      f = @current_company.financialyears.find(:first, :order=>"stopped_on DESC")
      
      @financialyear.started_on = f.stopped_on+1.day unless f.nil?
      @financialyear.started_on ||= Date.today
      @financialyear.stopped_on = (@financialyear.started_on+1.year-1.day).end_of_month
      @financialyear.code = @financialyear.started_on.year.to_s
      @financialyear.code += '/'+@financialyear.stopped_on.year.to_s if @financialyear.started_on.year!=@financialyear.stopped_on.year
    end
    
    render_form
  end
  
  
  # this action updates a financialyear with a form.
  def financialyear_update
    @financialyear = Financialyear.find_by_id_and_company_id(params[:id], @current_company.id)  
    if request.post? or request.put?
      redirect_to :action => "financialyears"  if @financialyear.update_attributes(params[:financialyear])
    end
    render_form
  end
    
  # this action deletes a financialyear.
  def financialyear_delete
    if request.post? or request.delete?
      @financialyear = Financialyear.find_by_id_and_company_id(params[:id], @current_company.id)  
      Financialyear.destroy @financialyear unless @financialyear.records.size > 0 
    end
    redirect_to :action => "financialyears"
  end
  
 # this method finds the report journal with the matching id and the company_id.
 # def journals_report_find
 #   @journal = @current_company.journals(:last, :conditions => {:nature => :renew.to_s, :deleted => false}) 
 #   return @journal.name
  #end
  
  # This method allows to close the financialyear.
  def financialyear_close
    @financialyears = []

    financialyears = Financialyear.find(:all, :conditions => {:company_id => @current_company.id, :closed => false})
  
    financialyears.each do |financialyear|
      @financialyears << financialyear if financialyear.closable?
    end
    
    if @financialyears.empty? 
      flash[:message]=tc(:no_closable_financialyear)
      redirect_to :action => :financialyears
      return
    end
   
    if params[:id]  
      @financialyear = Financialyear.find_by_id_and_company_id(params[:id], @current_company.id) 
    else
      @financialyear = @financialyears.first
    end

    @renew_journal = @current_company.journals.find(:all, :conditions => {:nature => :renew.to_s, :deleted => false})
    
    if request.post?
      @financialyear= Financialyear.find_by_id_and_company_id(params[:financialyear][:id], @current_company.id)  
      
      unless params[:journal_id].blank?
        @renew_journal = Journal.find(params[:journal_id])
        @new_financialyear = @financialyear.next(@current_company.id)
        
        if @new_financialyear.nil?
          flash[:message]=tc(:next_illegal_period_financialyear)
          redirect_to :action => :financialyears
          return
        end
        
        balance_account = generate_balance_account(@current_company.id, @financialyear.started_on, @financialyear.stopped_on)
      
        if balance_account.size > 0
          @record = JournalRecord.create!(:financialyear_id => @new_financialyear.id, :company_id => @current_company.id, :journal_id => @renew_journal.id, :created_on => @new_financialyear.started_on, :printed_on => @new_financialyear.started_on)
          result=0
          account_profit_id=0
          account_loss_id=0
          account_profit_name=''
          account_loss_name=''
          balance_account.each do |account|
            if account[:number].to_s.match /^120/
              account_profit_id = account[:id]
              account_profit_name = account[:name]
              result += account[:balance]
            elsif account[:number].to_s.match /^129/
              account_loss_id = account[:id]
              account_loss_name = account[:name]
              result -= account[:balance]
            elsif account[:number].to_s.match /^(6|7)/
              result += account[:balance] 
            else
              @entry=@current_company.entries.create({:record_id => @record.id, :currency_id => @renew_journal.currency_id, :account_id => account[:id], :name => account[:name], :currency_debit => account[:debit], :currency_credit => account[:credit]})
            end
          end
          if result.to_i > 0
            @entry=@current_company.entries.create({:record_id => @record.id, :currency_id => @renew_journal.currency_id, :account_id => account_loss_id, :name => account_loss_name, :currency_debit => result, :currency_credit => 0.0}) 
          else
            @entry=@current_company.entries.create({:record_id => @record.id, :currency_id => @renew_journal.currency_id, :account_id => account_profit_id, :name => account_profit_name, :currency_debit => 0.0, :currency_credit => result.abs}) 
          end
        end
      end
      @financialyear.close(params[:financialyear][:stopped_on])
      flash[:message] = tc('messages.closed_financialyears')
      redirect_to :action => :financialyears
      
    else
      if @financialyear
        @financialyear_records = []
        d = @financialyear.started_on
        while d.end_of_month < @financialyear.stopped_on
          d=(d+1).end_of_month
          @financialyear_records << d.to_s(:attributes)
        end
      end
    end
    
  end
  
  
# this method generates a table with debit and credit for each account.
#  def generate_balance_account(company, financialyear)
  def generate_balance_account(company, from, to)
    balance = []
    debit = 0
    credit = 0
    #a=Account.balance(company, from, to)
    #raise Exception.new a.inspect
    return Account.balance(company, from, to)
    
    # @current_company.accounts.each do |account|
    #  balance << account.compute(company, financialyear)
    #end
  #  raise Exception.new balance_account.inspect
  end
  
  #
  def financialyears_records
    @financialyear_records=[]
    @financialyear = Financialyear.find(params[:financialyear_select])
    d = @financialyear.started_on
    
    while d.end_of_month < @financialyear.stopped_on
      d=(d+1).end_of_month
      @financialyear_records << d.to_s(:attributes)
    end
    render :text => options_for_select(@financialyear_records)
  end
  
  
  # this action displays all entries stored in the journal. 
  def entries_consult
    @journals = @current_company.journals.find(:all, :select=>' DISTINCT id, name, closed_on ')
    @financialyears = @current_company.financialyears.find(:all, :select=>' DISTINCT id, code')
    
    unless @journals.size > 0 or @financialyears.size > 0
      unless @journals.size > 0 
        flash[:message] = tc('messages.need_journal_to_consult_entries')
        redirect_to :action => :journal_create
        return
      end
      unless @financialyears.size > 0 
        flash[:message] = tc('messages.need_financialyear_to_consult_entries')
        redirect_to :action => :financialyear_create
        return
      end
    end
    
    session[:statement] = nil
    session[:journal_record] ||= {} 
    if params[:id]
     #  raise Exception.new params[:id].to_s
      session[:journal_record][:financialyear_id] = params[:id] 
      session[:journal_record][:journal_id] = ''
    end

    if request.post?
      journal =  Journal.find_by_id_and_company_id(params[:journal_id].to_i, @current_company.id)
      session[:journal_record][:journal_id] = (journal ? journal.id : '')
     
      financialyear = Financialyear.find_by_id_and_company_id(params[:financialyear_id].to_i, @current_company.id)
      session[:journal_record][:financialyear_id] = (financialyear ? financialyear.id : '')
    end
  
    @journal_record = JournalRecord.new(:journal_id=> session[:journal_record][:journal_id], :financialyear_id => session[:journal_record][:financialyear_id])
  end
  
  # this action has not specific view.
  def entries_consult_by_journal_id
    session[:journal_record] = {}
    session[:journal_record][:journal_id] = params[:id] 
    redirect_to :action => :entries_consult
  end
  
  # this action has not specific view.
  def params_entries
    if request.post?
      session[:entries] ||= {}
      session[:entries][:journal] = params[:journal_id]
      session[:entries][:financialyear] = params[:financialyear_id]
      session[:entries][:records_number] = params[:number]
      redirect_to :action => :entries
    end
  end
  
  # This method allows to enter the accountancy records with a form.
  def entries
    session[:entries] ||= {}
    session[:entries][:records_number] ||= 5
    error_balance_or_new_record = false
    @records=[]
    @journal = find_and_check(:journal, session[:entries][:journal]) if session[:entries][:journal]
    @financialyear = find_and_check(:financialyear, session[:entries][:financialyear]) if session[:entries][:financialyear]
    @valid = (!@journal.nil? and !@financialyear.nil?)
    @journals = @current_company.journals.find(:all, :order=>:name)
    @financialyears = @current_company.financialyears.find(:all, :conditions => {:closed => false}, :order=>:code)
    unless @financialyears.size>0
      flash[:message] = tc('messages.need_financialyear_to_record_entries')
      redirect_to :action=>:financialyear_create
      return
    end
    unless @journals.size>0
      flash[:message] = tc('messages.need_journal_to_record_entries')
      redirect_to :action=>:journal_create
      return
    end
    
    if @valid
      @record = JournalRecord.new
      if request.post?
        @record = @current_company.journal_records.find(:first,:conditions=>["journal_id = ? AND number = ? AND financialyear_id = ?", @journal.id, params[:record][:number].rjust(4,"0"), @financialyear.id])
       
        created_on = params[:record][:created_on].gsub('/','-').to_date.strftime
        printed_on = params[:record][:printed_on].gsub('/', '-').to_date.strftime

        if @record
          if @record.created_on > @record.journal.closed_on
            @record.created_on = created_on
            @record.printed_on = printed_on
          end
        end
        
        if @record.nil?
          @record = JournalRecord.create!(params[:record].merge({:financialyear_id => @financialyear.id, :journal_id => @journal.id, :company_id => @current_company.id, :created_on => created_on, :printed_on => printed_on}))
        end 
        
        @entry = @current_company.entries.build(params[:entry])
        

        if @record.save
          @entry.record_id = @record.id
          @entry.currency_id = @journal.currency_id
          if @entry.save
            @record.reload
            @entry  = Entry.new
          end
        else
          raise Exception.new('error 1')
          error_balance_or_new_record = true if @record.balanced or @record.new_record?
          # @record.reload
          @entry = Entry.new
        end
        

      elsif request.delete?
        @entry = Entry.find_by_id_and_company_id(params[:id], @current_company.id)  
        if @entry.close?
          flash[:message]=tc(:messages, :need_unclosed_entry_to_delete)
        else
          Entry.destroy(@entry)
        end
        @entry = Entry.new 
      else
        @entry = Entry.new 
      end
     
      @records = @journal.records.find(:all, :conditions => {:financialyear_id => @financialyear.id, :company_id => @current_company.id }, :order=>"number DESC", :limit=>session[:entries][:records_number].to_i)
#       
      unless error_balance_or_new_record
        @record = @journal.records.find(:first, :conditions => ["debit!=credit OR (debit=0 AND credit=0) AND financialyear_id = ?", @financialyear.id], :order=>:id) if @record.balanced or @record.new_record?
        
      end
      
      unless @record.nil?
        if (@record.balance > 0) 
          @entry.currency_credit=@record.balance.abs 
        else
          @entry.currency_debit=@record.balance.abs  
        end
      end

      unless error_balance_or_new_record
        @record = JournalRecord.new(params[:record]) if @record.nil? 
        
        if @record.new_record?
          @record.number = @records.size>0 ? @records.first.number.succ : 1
          @record.created_on = @records.size>0 ? @records.last.created_on : @financialyear.started_on
          @record.printed_on = @records.size>0 ? @records.last.printed_on : @financialyear.started_on
        end
      end
      
      render :action => "entries.rjs" if request.xhr?
    
    end
    
  end

  # this method updates an entry with a form.
  def entry_update
    @entry = Entry.find_by_id_and_company_id(params[:id], @current_company.id)  
    
    if request.post? or request.put?
      @entry.update_attributes(params[:entry]) 
      redirect_to :action => "entries" 
    end
    render_form
  end

  # this method deletes an entry with a form.
  def entry_delete
    if request.post? or request.delete?
      @entry = Entry.find_by_id_and_company_id(params[:id], @current_company.id) 
      Entry.destroy(@entry.id)
    end
  end

  # lists all the transactions established on the accounts, sorted by date.
  def journals
  end


  #this method creates a journal with a form. 
  def journal_create
    if request.post?
      @journal = Journal.new(params[:journal])
      @journal.company_id = @current_company.id
      redirect_to_back if @journal.save
    else
      @journal = Journal.new
      @journal.nature = Journal.natures[0][1]
    end
    render_form
  end

  #this method updates a journal with a form. 
  def journal_update
    @journal = Journal.find_by_id_and_company_id(params[:id], @current_company.id)  
    
    if request.post? or request.put?
      @journal.update_attributes(params[:journal]) 
      redirect_to :action => "journals" 
    end
    render_form
  end

  # this action deletes or hides an existing journal.
  def journal_delete
    if request.post? or request.delete?
      @journal = Journal.find_by_id_and_company_id(params[:id], @current_company.id)  
      if @journal.records.size > 0
        flash[:message]=tc(:messages, :need_empty_journal_to_delete)
        @journal.update_attribute(:deleted, true)
      else
        Journal.destroy(@journal)
      end
    end
    redirect_to :action => "journals"
  end


  # This method allows to close the journal.
  def journal_close
    @journal_records = []
    @journals = []
    
    journals= @current_company.journals.find(:all, :conditions=> ["closed_on < ?", Date.today.to_s]) 
    journals.each do |journal|
      @journals << journal if journal.balance?
    end
    
    if @journals.empty?
      flash[:message]=tc(:no_closable_journal)
      redirect_to :action => :journals
    end
  
    if params[:id]  
      @journal = Journal.find_by_id_and_company_id(params[:id], @current_company.id) 
      unless @journal.closable?(Date.today)
        flash[:message]=tc(:unclosable_journal)
        redirect_to :action => :journals 
      end
    else
      @journal = @current_company.journals.find(:first, :conditions=> ["closed_on < ?", Date.today.to_s]) 
    end
        
    if @journal
      d = @journal.closed_on
      while d.end_of_month < Date.today
        d=(d+1).end_of_month
        @journal_records << d.to_s(:attributes)
     end
    end
    if request.post?
      @journal = Journal.find_by_id_and_company_id(params[:journal][:id], @current_company.id)
      
      if @journal.nil?
        flash[:error] = tc(:unavailable_journal)
      end  
      
      if @journal.close(params[:journal][:closed_on])
        redirect_to_back
      end
    end
  end

  # This method allows to build the table of the periods.
  def journals_records
    @journals_records=[]
    @journal = Journal.find(params[:journal_select])
    d = @journal.closed_on
    while d.end_of_month < Date.today
      d=(d+1).end_of_month
      @journals_records << d.to_s(:attributes)
    end
    render :text => options_for_select(@journals_records) 
  end
 

  # This method allows to make lettering for the client and supplier accounts.
  def lettering
    clients_account = @current_company.parameter('accountancy.third_accounts.clients').value.to_s
    suppliers_account = @current_company.parameter('accountancy.third_accounts.suppliers').value.to_s
    
    Account.create!(:name=>"Clients", :number=>clients_account, :company_id=>@current_company.id) unless @current_company.accounts.exists?(:number=>clients_account)
    Account.create!(:name=>"Fournisseurs", :number=>suppliers_account, :company_id=>@current_company.id) unless @current_company.accounts.exists?(:number=>suppliers_account)

    @accounts_supplier = @current_company.accounts.find(:all, :conditions => ["number LIKE ?", suppliers_account+'%'])
    @accounts_client = @current_company.accounts.find(:all, :conditions => ["number LIKE ?", clients_account+'%'])
    
    @financialyears = @current_company.financialyears.find(:all)
    
    @entries =  @current_company.entries.find(:all, :conditions => ["editable = ? AND (a.number LIKE ? OR a.number LIKE ?)", false, clients_account+'%', suppliers_account+'%'], :joins => "LEFT JOIN accounts a ON a.id = entries.account_id")
 
    unless @entries.size > 0
      flash[:message] = tc('messages.need_entries_to_letter')
      return
    end

    if request.post?
      @account = @current_company.accounts.find(params[:account_client_id], params[:account_supplier_id])
      redirect_to :action => "account_letter", :id => @account.id
    end

  end

  # this method displays the array for make lettering.
  def account_letter
    @entries = @current_company.entries.find(:all, :conditions => { :account_id => params[:id]}, :joins => "INNER JOIN journal_records r ON r.id = entries.record_id INNER JOIN financialyears f ON f.id = r.financialyear_id", :order => "id ASC")

    session[:letter]='AAAA'
   
    @account = @current_company.accounts.find(params[:id])
    
    @title = {:value1 => @account.number}
  end


  # this method makes the lettering.
  def entry_letter

    if request.xhr?
    
      @entry = @current_company.entries.find(params[:id])
      
       @entries = @current_company.entries.find(:all, :conditions => { :account_id => @entry.account_id}, :joins => "INNER JOIN journal_records r ON r.id = entries.record_id INNER JOIN financialyears f ON f.id = r.financialyear_id", :order => "id ASC")
      
      @letters = []
      @entries.each do |entry|
        @letters << entry.letter unless entry.letter.blank?  
      end
      @letters.uniq!
    
      if @entry.letter != ""
         @entries_letter = @current_company.entries.find(:all, :conditions => ["letter = ? AND account_id = ?", @entry.letter.to_s, @entry.account_id], :joins => "INNER JOIN journal_records r ON r.id = entries.record_id INNER JOIN financialyears f ON f.id = r.financialyear_id")

        @entry.update_attribute("letter", '')
        
      else
     
        if not @letters.empty? 
          
          @letters.each do |letter|
            
            @entries_letter = @current_company.entries.find(:all, :conditions => ["letter = ? AND account_id = ?", letter.to_s, @entry.account_id], :joins => "INNER JOIN journal_records r ON r.id = entries.record_id INNER JOIN financialyears f ON f.id = r.financialyear_id")
            
            if @entries_letter.size > 0
              sum_debit = 0
              sum_credit = 0
              @entries_letter.each do |entry|
                sum_debit += entry.debit
                sum_credit += entry.credit
              end
              
              if sum_debit != sum_credit
                session[:letter] = letter
                break
              else
                session[:letter] = letter.succ
              end
            end
          end
        end
        @entry.update_attribute("letter", session[:letter].to_s)
      end
      
      @entries = @current_company.entries.find(:all, :conditions => { :account_id => @entry.account_id}, :joins => "INNER JOIN journal_records r ON r.id = entries.record_id INNER JOIN financialyears f ON f.id = r.financialyear_id", :order => "id ASC")
      
      render :action => "accounts_letter.rjs"
    end

  end
  
  # lists all the statements in details for a precise account.
  def statements  
    @bank_accounts = @current_company.bank_accounts
    @valid = @current_company.bank_accounts.empty?
    unless @bank_accounts.size>0
      flash[:message] = tc('messages.need_bank_account_to_record_statements')
      redirect_to :action=>:bank_account_create
      return
    end
  end

  # This method creates a statement.
  def bank_account_statement_create
    @bank_accounts = @current_company.bank_accounts  
        
    if request.post?
      @statement = BankAccountStatement.new(params[:statement])
      @statement.bank_account_id = params[:statement][:bank_account_id]
      @statement.company_id = @current_company.id
      
      if BankAccount.find_by_id_and_company_id(params[:statement][:bank_account_id], @current_company.id).account.entries.find(:all, :conditions => "statement_id is NULL").size.zero?
        flash[:message]=tc('messages.no_entries_pointable_for_bank_account')
      else
       
        if @statement.save
          redirect_to :action => "bank_account_statement_point", :id => @statement.id 
        end
      end
    else
      @statement = BankAccountStatement.new(:started_on=>Date.today-1.month-2.days, :stopped_on=>Date.today-2.days)
    end
    render_form 
  end


  # This method updates a statement.
  def bank_account_statement_update
    @bank_accounts = BankAccount.find(:all,:conditions=>"company_id = "+@current_company.id.to_s)  
    @statement = BankAccountStatement.find_by_id_and_company_id(params[:id], @current_company.id)  
    if request.post? or request.put?
      @statement.update_attributes(params[:statement]) 
      redirect_to :action => "statements_point", :id => @statement.id if @statement.save 
    end
    render_form
  end


  # This method deletes a statement.
  def bank_account_statement_delete
    if request.post? or request.delete?
      @statement = BankAccountStatement.find_by_id_and_company_id(params[:id], @current_company.id)  
     BankAccountStatement.destroy @statement
      redirect_to :action=>"statements"
    end
  end


  # This method displays the list of entries recording to the bank account for the given statement.
  def bank_account_statement_point
    session[:statement] = params[:id]  if request.get? 
    @bank_account_statement=BankAccountStatement.find(session[:statement])
    @bank_account=BankAccount.find(@bank_account_statement.bank_account_id)
    
    @entries=@current_company.entries.find(:all, :conditions =>['account_id = ? AND editable = true AND CAST(j.created_on AS DATE) BETWEEN ? AND ?', @bank_account.account_id, @bank_account_statement.started_on, @bank_account_statement.stopped_on ], :joins => "INNER JOIN journal_records j ON j.id = entries.record_id", :order => "statement_id DESC")
     
    unless @entries.size > 0
      flash[:message] = tc('messages.need_entries_to_point', :value=>@bank_account_statement.number)
      redirect_to :action=>'statements'
    end

    if request.xhr?
    
      @entry=Entry.find(params[:id]) 

      if @entry.statement_id.eql? session[:statement].to_i
        
        @entry.update_attribute("statement_id", nil)
        @bank_account_statement.credit -= @entry.debit
        @bank_account_statement.debit  -= @entry.credit
        @bank_account_statement.save
        
      elsif @entry.statement_id.nil?
        @entry.update_attribute("statement_id", session[:statement])
        @bank_account_statement.credit += @entry.debit
        @bank_account_statement.debit  += @entry.credit
        @bank_account_statement.save
        
      else
        @entry.statement.debit  -= @entry.credit
        @entry.statement.credit -= @entry.debit
        @entry.statement.save
        @entry.update_attribute("statement_id", nil)
      end
      
      render :action => "statements.rjs" 
      
    end
    @title = {:value1 => @bank_account_statement.number, :value2 => @bank_account.name }
  end

  # displays in details the statement choosen with its mainly characteristics.
  def bank_account_statement
    @bank_account_statement = BankAccountStatement.find(params[:id])
    session[:statement]=params[:id]
    @title = {:value => @bank_account_statement.number}
  end
end



