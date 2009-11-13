# == Schema Information
#
# Table name: embankments
#
#  amount          :decimal(16, 4 default(0.0), not null
#  bank_account_id :integer       not null
#  comment         :text          
#  company_id      :integer       not null
#  created_at      :datetime      not null
#  created_on      :date          not null
#  creator_id      :integer       
#  embanker_id     :integer       
#  id              :integer       not null, primary key
#  lock_version    :integer       default(0), not null
#  locked          :boolean       not null
#  mode_id         :integer       not null
#  number          :string(255)   
#  payments_count  :integer       default(0), not null
#  updated_at      :datetime      not null
#  updater_id      :integer       
#

require 'test_helper'

class EmbankmentTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "the truth" do
    assert true
  end
end
