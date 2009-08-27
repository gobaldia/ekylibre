# == Schema Information
#
# Table name: sale_order_lines
#
#  account_id        :integer       not null
#  amount            :decimal(16, 2 default(0.0), not null
#  amount_with_taxes :decimal(16, 2 default(0.0), not null
#  annotation        :text          
#  company_id        :integer       not null
#  created_at        :datetime      not null
#  creator_id        :integer       
#  entity_id         :integer       
#  id                :integer       not null, primary key
#  invoiced          :boolean       not null
#  location_id       :integer       
#  lock_version      :integer       default(0), not null
#  order_id          :integer       not null
#  position          :integer       
#  price_amount      :decimal(16, 2 
#  price_id          :integer       not null
#  product_id        :integer       not null
#  quantity          :decimal(16, 2 default(1.0), not null
#  tax_id            :integer       
#  unit_id           :integer       not null
#  updated_at        :datetime      not null
#  updater_id        :integer       
#

class SaleOrderLine < ActiveRecord::Base
  attr_readonly :company_id, :order_id

  belongs_to :account
  belongs_to :company
  belongs_to :entity
  belongs_to :location, :class_name=>StockLocation.to_s
  belongs_to :order, :class_name=>SaleOrder.to_s
  belongs_to :price
  belongs_to :product
  belongs_to :tax
  belongs_to :unit
  has_many :delivery_lines
  has_many :invoice_lines
  
  def before_validation
    check_reservoir = true
    self.account_id = self.product.product_account_id
    self.unit_id = self.product.unit_id

    if self.price_amount > 0
      price = Price.create!(:amount=>self.price_amount, :tax_id=>self.tax.id, :entity_id=>self.company.entity_id , :company_id=>self.company_id, :active=>false, :product_id=>self.product_id)
      self.price_id = price.id
      #self.amount = (self.price_amount*self.quantity).round(2)
      #self.amount_with_taxes = ((self.price_amount + self.tax.compute(self.amount))*self.quantity).round(2)
      #elsif self.price
    end
    if self.price
      self.amount = (self.price.amount*self.quantity).round(2)
      self.amount_with_taxes = (self.price.amount_with_taxes*self.quantity).round(2) 
    end
    
    if self.location.reservoir && self.location.product_id != self.product_id
      check_reservoir = false
      errors.add_to_base(tc(:stock_location_can_not_transfer_product), :location=>self.location.name, :product=>self.product.name, :contained_product=>self.location.product.name) 
    end
    check_reservoir
  end
  
  def validate
    errors.add_to_base(tc(:stock_location_can_not_transfer_product), :location=>self.location.name, :product=>self.product.name, :contained_product=>self.location.product.name) unless self.location.can_receive(self.product_id)
  end
  
  def after_save
    self.order.refresh
  end

  def undelivered_quantity
    lines =  DeliveryLine.find(:all, :conditions=>{:company_id=>self.company_id, :order_line_id=>self.id})
    if lines.nil?
      rest = self.quantity
    else
      sum = 0
      for line in lines 
        sum += line.quantity
      end
      rest = (self.quantity - sum )
    end
    rest
  end

  def product_name
    self.product ? self.product.name : tc(:no_product) 
  end

  # TO DELETE
  def is_a_subscription
    self.subscription?
  end

  def subscription?
    self.product.nature == "subscrip"
  end

  def taxes
    self.amount_with_taxes - self.amount
  end


end
